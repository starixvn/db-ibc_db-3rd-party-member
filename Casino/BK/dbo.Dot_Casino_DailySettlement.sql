ALTER PROCEDURE [dbo].[Dot_Casino_DailySettlement]
	@custid [int],
	@CS_Turnover [money] = 0,
	@CS_Winlost [money] = 0,
	@CS_swinlost [money] = 0,
	@CS_mwinlost [money] = 0,
	@CS_awinlost [money] = 0,
	@CS_scomm [money] = 0,
	@CS_mcomm [money] = 0,
	@CS_acomm [money] = 0,
	@CS_playercomm [money] = 0,
	@CS_pendingAmount [money] = 0,
	@CS_sposition [smallmoney] = 0,
	@CS_mposition [smallmoney] = 0,
	@CS_aposition [smallmoney] = 0,
	@P2P_Turnover [money] = 0,
	@P2P_Winlost [money] = 0,
	@P2P_scomm [money] = 0,
	@P2P_mcomm [money] = 0,
	@P2P_acomm [money] = 0,
	@P2P_pendingAmount [money] = 0,
	@refno [bigint],
	@sessionId [bigint] = 0,
	@transdesc [nvarchar](300) = '',
	@ip [nvarchar](15) = '',
	@ErrCode [int] = 0 OUTPUT,
	@ErrMsg [nvarchar](200) = '' OUTPUT
WITH EXECUTE AS CALLER
AS
/*
Creator : Amy
Date : 2011-06-10
Task : Use for Daily Settlement
DB: DBTRANS.bodb02


History:
	- 20111029@Sophia: Update balance  
	- 20120406@Sophia: Exclude P2P in the calculation of Casino  
Param's Explanation:

• Full structure of Dummy accounts:
		--ACC Super		3rdSuperUUS		3rdSuperEURO    other currencies...
		--ACC Master	CasUS$			CasEURO
		--ACC Agent		CasUS$01		CasEURO01
		--ACC Member	CasBetUS$		CasBetEURO

• @casinoTurnover: always positive 
• @casinoWinlost: casinoWinlost = casinoTurnover + member's winlost 
• @ErrCode:
	= 0: Transaction recorded successfully.
	> 0: Specific Error.
	
• @ErrMsg: Error description.

Note: 
	- This SP is not check running transfer transaction
	- The pending ticket of previsous session will be updated as Completed in case Admin forfeit Member Unfinish Game
*/

SET NOCOUNT ON

DECLARE	@roleid				tinyint,
		@username			varchar(30),
		@recommend			int, 
		@mrecommend			int, 
		@srecommend			int, 
		@actualrate			float, 
		@cs_mem_status		nvarchar(10),
		@cs_mem_statusID	int,
---- 20120406@Sophia: Exclude P2P in the calculation of Casino  
--		@p2p_mem_status		nvarchar(10),
--		@p2p_mem_statusID	int,
		@currency			tinyint, 
		@currencyName		nvarchar(5), 
		@transdate			datetime, 
		@winlostdate		datetime,
		@dummy_username		nvarchar(15),
		@dummy_custid		int,
		@dummy_recommend	int,
		@dummy_mrecommend	int,
		@dummy_srecommend	int,
		@balance			money,
		@cs_balance			money,
--- 20120406@Sophia: Exclude P2P in the calculation of Casino  
--		@p2p_balance		money,
		@at_cs_pending		money,
		@bf_cs_pending		money,
--- 20120406@Sophia: Exclude P2P in the calculation of Casino  
--		@at_p2p_pending		money,
--		@bf_p2p_pending		money,
		@at_transfer		money,
		@bf_transfer		money
--- 20130705@Kathy: Update matchid for RnG Casino		

SELECT  @ErrCode = 0, @ErrMsg = '' 

IF @cs_Turnover < 0 OR @cs_Winlost < 0 ----or @p2p_Turnover < 0 OR @p2p_Winlost < 0 --- 20120406@Sophia: Exclude P2P in the calculation of Casino  
BEGIN
	SELECT @ErrMsg = 'Sorry, amount is invalid.', @ErrCode = 101	
	RETURN		
END

SELECT	@username= ci.username,
		@roleid = isnull(ci.roleid,0), 
		@recommend = ci.recommend,
		@mrecommend = ci.mrecommend, 
		@srecommend = ci.srecommend,
		@currency = ci.currency, 
		@currencyName = e.currency, 
		@actualrate = e.actualrate

FROM	custinfo ci WITH (NOLOCK) 
		INNER JOIN exchange e WITH (NOLOCK) on ci.currency = e.exchangeid
WHERE   ci.custid = @custid 

IF @roleid <> 1
BEGIN
	SELECT @ErrMsg = 'Invalid Role ID.', @ErrCode = 102		
	RETURN
END
--20090219@PhuongDoan: check if srecommend < 100 and scomm <> mcomm and swinlost <>0
--member of direct master can not have supercomm<>scomm or swinlost <>0
if @srecommend<100 and (@cs_scomm <> @cs_mcomm or @cs_swinlost <>0) ----or @p2p_scomm <> @p2p_mcomm) --- 20120406@Sophia: Exclude P2P in the calculation of Casino  
begin
	SELECT @ErrMsg = 'Invalid super/master comm or super winloss for member of direct master!', @ErrCode = 103		
	RETURN
end

SELECT @cs_mem_status = CASE WHEN @cs_Winlost > @cs_Turnover THEN 'WON'
						  WHEN @cs_Winlost < @cs_Turnover THEN 'LOSE'
						  ELSE 'DRAW' END 
						  
SELECT @cs_mem_statusID = CASE WHEN @cs_Winlost > @cs_Turnover THEN 112
						  WHEN @cs_Winlost < @cs_Turnover THEN 113
						  ELSE 111 END 
--- 20120406@Sophia: Exclude P2P in the calculation of Casino  
/*
SELECT @p2p_mem_status = CASE WHEN @p2p_Winlost > @p2p_Turnover THEN 'WON'
						  WHEN @p2p_Winlost < @p2p_Turnover THEN 'LOSE'
						  ELSE 'DRAW' END 
						  
SELECT @p2p_mem_statusID = CASE WHEN @p2p_Winlost > @p2p_Turnover THEN 112
						  WHEN @p2p_Winlost < @p2p_Turnover THEN 113
						  ELSE 111 END 						  
*/

SELECT	@dummy_custid = c.custid,
		@dummy_username = c.username,
		@dummy_recommend = c.recommend,
		@dummy_mrecommend = c.mrecommend,
		@dummy_srecommend = c.srecommend
FROM	custinfo c WITH (NOLOCK) 
WHERE	c.username = 'CasBet' + @currencyName AND c.roleid = 1 

IF isnull(@dummy_custid, 0) = 0
BEGIN
	SELECT @ErrMsg = 'Invalid Dummy account or Account is not existed!', @ErrCode = 106		
	RETURN
END

------------------Insert trans into DB---------------------------------------------------------------
SELECT	@transdesc = 'Casino Betting' + CASE WHEN @transdesc <> '' THEN ' - ' + @transdesc ELSE '' END

SELECT @transdate = CURRENT_TIMESTAMP , @winlostdate = CONVERT(nvarchar(10), CURRENT_TIMESTAMP, 120)

IF (@CS_Turnover > 0 or @CS_Winlost > 0)
BEGIN
---INSERT CASINO BET TICKET 
	INSERT INTO bettrans 
	(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
	 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
	 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
	 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, currency, actualrate, currencyName, 
	 ruben, status,statusID,ip,betid)
	VALUES 
	(@CustID, @username, @refno, @transdate, 71, 71, @transdesc, @cs_Winlost, @cs_Turnover, @cs_Turnover,
	 @cs_awinlost, @cs_mwinlost, @cs_swinlost, @cs_playercomm, @cs_acomm, @cs_mcomm, @cs_scomm, @winlostdate, 
	 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, @CS_aposition, @CS_mposition, @CS_sposition, @CS_aposition +@CS_mposition + @CS_sposition, 
	 @Currency, @actualrate, @currencyName, 1, @cs_mem_status,@cs_mem_statusID, @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
		RETURN
	END	
END

--- 20120406@Sophia: Exclude P2P in the calculation of Casino  
/*
IF (@P2P_Turnover > 0 or @P2P_Winlost > 0)
BEGIN
	---INSERT P2P BET TICKET 
	INSERT INTO bettrans 
		(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, currency, actualrate, currencyName, 
		 ruben, status,statusID,ip,betid)
	VALUES 
		(@CustID, @username, @refno, @transdate, 0, 1000, @transdesc, @p2p_Winlost, @p2p_Turnover, @p2p_Turnover,
		 0, 0, 0, 0, @p2p_acomm, @p2p_mcomm, @p2p_scomm, @winlostdate, 
		 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 1, @p2p_mem_status,@p2p_mem_statusID, @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
		DELETE FROM bettrans WHERE refNo = @refno AND bettype = 71 and matchid = 0
		RETURN
	END	
END
*/

---INSERT CASINO PENDING BET TICKET 
IF @cs_pendingAmount > 0
BEGIN
	INSERT INTO bettrans 
		(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, actual_stake, stake,
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, currency, actualrate, currencyName, 
		 ruben, status,statusID,ip,betid)
	VALUES 
		(@CustID, @username, @refno, @transdate, 0, 23002, @transdesc, 0, @cs_pendingAmount, @cs_pendingAmount,
		 0, 0, 0, 0, 0, 0, 0, @winlostdate, 
		 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 0, 'running',0, @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
		DELETE FROM bettrans WHERE custid = @custid and refNo = @refno AND bettype in (71) and matchid IN (0, 71)
		RETURN
	END	
END

--- 20120406@Sophia: Exclude P2P in the calculation of Casino  
/*
---INSERT P2P PENDING BET TICKET 
IF @p2p_pendingAmount > 0
BEGIN
	INSERT INTO bettrans 
		(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, actual_stake,stake, 
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, currency, actualrate, currencyName, 
		 ruben, status,statusID,ip,betid)
	VALUES 
		(@CustID, @username, @refno, @transdate, 0, 23102, @transdesc, 0, @p2p_pendingAmount,@p2p_pendingAmount, 
		 0, 0, 0, 0, 0, 0, 0, @winlostdate, 
		 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 0, 'running',0, @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
		DELETE FROM bettrans WHERE custid = @custid and refNo = @refno AND bettype in (71,1000,23002) and matchid = 0
		RETURN
	END	
END
*/

IF (@CS_Turnover > 0 or @CS_Winlost > 0)
BEGIN
	--INSERT CASINO DUMMY TICKET
	INSERT INTO bettrans 
		(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,
		 currency, actualrate, currencyName, ruben, status,statusID,ip,betid)
	VALUES 
		(@dummy_custID, @dummy_username, @refno, @transdate, 71, 71, @transdesc, @cs_Turnover, @cs_Winlost,@cs_Winlost,
		 -@cs_awinlost, -@cs_mwinlost, -@cs_swinlost, -@cs_playercomm, -@cs_acomm, -@cs_mcomm, -@cs_scomm, @winlostdate, @dummy_custID, 
		 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 1, 'DONE',121, @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
		DELETE FROM bettrans WHERE refNo = @refno AND bettype in (71,23002) and matchid IN (0, 71)
		RETURN
	END
END

--- 20120406@Sophia: Exclude P2P in the calculation of Casino  
/*
IF (@P2P_Turnover > 0 or @P2P_Winlost > 0)
BEGIN
	--INSERT P2P DUMMY TICKET
	INSERT INTO bettrans 
		(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,
		 currency, actualrate, currencyName, ruben, status,statusID,ip,betid)
	VALUES 
		(@dummy_custID, @dummy_username, @refno, @transdate, 0, 1000, @transdesc, @p2p_Turnover,@p2p_Winlost, @p2p_Winlost,
		 0, 0, 0, 0, -@p2p_acomm, -@p2p_mcomm, -@p2p_scomm, @winlostdate, @dummy_custID, 
		 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 1, 'DONE',121, @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
		--delete all trans of current session
		DELETE FROM bettrans WHERE refNo = @refno AND bettype in (71,1000,23002,23102) and matchid = 0
		RETURN
	END
END
*/

--UPDATE MEMBER TRANS 
SELECT  @bf_transfer = sum(winlost - actual_stake )
FROM	bettrans WITH (NOLOCK)
WHERE	custid=@custid and refno = @refno and bettype = 23001 and matchid = 0

UPDATE bettrans WITH (ROWLOCK, UPDLOCK)
    SET status = 'Completed',statusID=131, ruben = 1, winlost = actual_stake
WHERE custid=@custid and refno = @refno and bettype = 23001 and matchid = 0

SELECT  @at_transfer = sum(winlost - actual_stake )
FROM	bettrans WITH (NOLOCK)
WHERE	custid=@custid and refno = @refno and bettype = 23001 and matchid = 0

IF @@ERROR <> 0
BEGIN			
	SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 108	
	--delete all trans of current session
	DELETE FROM bettrans WHERE refNo = @refno AND bettype in (71,23002) and matchid IN (0, 71)
	RETURN
END


--UPDATE MEMBER PENDING CASINO TRANS OF PREVIOUS SESSION
IF EXISTS (SELECT TOP 1 * FROM bettrans with(nolock) where custid=@custid and bettype=23002 and ruben = 0 and refno = @refno and matchid = 0)
BEGIN
	SELECT  @bf_cs_pending = sum(winlost - actual_stake )
	FROM	bettrans WITH (NOLOCK)
	WHERE	custid = @custid and bettype = 23002 and ruben = 0 and refno = @refno and matchid = 0

	UPDATE	bettrans WITH (ROWLOCK, UPDLOCK) 
	SET		status = 'Completed',statusID=131, ruben = 1, winlost = actual_stake 
	WHERE	custid = @custid and bettype = 23002 and ruben = 0 and refno = @refno and matchid = 0
	
	SELECT  @at_cs_pending = sum(winlost - actual_stake )
	FROM	bettrans WITH (NOLOCK)
	WHERE	custid = @custid and bettype = 23002 and ruben = 1 and refno = @refno and matchid = 0
	
	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 108	
		--revert transfer trans
		UPDATE bettrans WITH (ROWLOCK, UPDLOCK) SET status = 'running',statusID=0, ruben = 0, winlost = 0 
		WHERE refno = @refno and bettype = 23001 and ruben = 1 and matchid = 0 
		--delete all trans of current session
		DELETE FROM bettrans WHERE refNo = @refno AND bettype in (71,23002) and matchid IN (0, 71)
		RETURN
	END
END


--- 20120406@Sophia: Exclude P2P in the calculation of Casino  
/*
--UPDATE MEMBER PENDING P2P TRANS OF PREVIOUS SESSION
IF EXISTS (SELECT TOP 1 * FROM bettrans with(nolock) where custid=@custid and bettype=23102 and ruben = 0 and refno = @refno and matchid = 0)
BEGIN
	SELECT  @bf_p2p_pending = sum(winlost - actual_stake )
	FROM	bettrans WITH (NOLOCK)
	WHERE	custid = @custid and bettype = 23102 and ruben = 0 and refno = @refno and matchid = 0

	UPDATE bettrans WITH (ROWLOCK, UPDLOCK) SET status = 'Completed',statusID=131, ruben = 1, winlost = actual_stake 
	WHERE custid = @custid and bettype = 23102 and ruben = 0 and refno = @refno and matchid = 0
	
	SELECT  @at_p2p_pending = sum(winlost - actual_stake )
	FROM	bettrans WITH (NOLOCK)
	WHERE	custid = @custid and bettype = 23102 and ruben = 1 and refno = @refno and matchid = 0
	
	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 108	
		--revert transfer trans
		UPDATE bettrans WITH (ROWLOCK, UPDLOCK) SET status = 'running',statusID=0, ruben = 0, winlost = 0 
		WHERE refno = @refno and bettype = 23001 and ruben = 1 and matchid = 0
		--revert casino pending trans
		UPDATE bettrans WITH (ROWLOCK, UPDLOCK) SET status = 'running',statusID=0, ruben = 0, winlost = 0 
		WHERE custid = @custid and bettype = 23102 and ruben = 0 and refno <> @refno and matchid = 0
		--delete all trans of current session
		DELETE FROM bettrans WHERE refNo = @refno AND bettype in (71,1000,23002,23102) and matchid = 0
		RETURN
	END
END
*/


---------------------BALANCE------------------------------------------------------------------
 
SELECT @cs_balance = ISNULL(@cs_Winlost,0) - ISNULL(@cs_Turnover,0) + ISNULL(@cs_playercomm,0)
					- ISNULL(@cs_pendingAmount,0)
					+ ISNULL(@at_cs_pending,0) - ISNULL(@bf_cs_pending,0)

--- 20120406@Sophia: Exclude P2P in the calculation of Casino  
/*
SELECT @p2p_balance =  ISNULL(@P2P_Winlost,0) - ISNULL(@P2P_Turnover,0) + 0 
					- ISNULL(@p2p_pendingAmount,0)
					+ ISNULL(@at_p2p_pending,0) - ISNULL(@bf_p2p_pending,0)
*/
SELECT @Balance = @cs_balance +  ISNULL(@at_transfer,0) - ISNULL(@bf_transfer,0)


IF @balance > 0 
BEGIN
	EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
END 
ELSE
IF @balance < 0  
BEGIN
	SELECT @balance = ABS(@balance)
	EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance
END 
---------------------------------------------------------------------------------------------------

DECLARE @LogData nvarchar(300)

SELECT @LogData = 'Casino Betting custid = ' + convert(nvarchar(20), @custid) + ', bettype = 71'  + ', casinoTurnover = ' + convert(nvarchar(20), @cs_Turnover) 
					 + ', casinoWinlost = ' + convert(nvarchar(20), @cs_Winlost) ----+ ', P2PTurnover = ' + convert(nvarchar(20), @p2p_Turnover) --- 20120406@Sophia: Exclude P2P in the calculation of Casino   
					 + case when @cs_pendingAmount > 0 then ', casinoPendingAmount = '+ convert(nvarchar(30),@cs_pendingAmount) else '' end
					 --- + case when @p2p_pendingAmount > 0 then ', P2PPendingAmount = '+ convert(nvarchar(30),@p2p_pendingAmount) else '' end --- 20120406@Sophia: Exclude P2P in the calculation of Casino  
					 + ', refNo = ' + convert(nvarchar(20),@refno)  +', currency = ' + convert(nvarchar(10),@currency) 
					 + ', CasinoPlayercomm = ' + convert(nvarchar(10),@cs_playercomm) + ', IP = '+ @ip 
BEGIN TRY
	EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData
END TRY
BEGIN CATCH
	-- if write log error: not return error code
END CATCH




GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Casino_DailySettlement] TO [vnteam]
GO
GRANT  EXECUTE  ON [dbo].[Dot_Casino_DailySettlement]  TO [Dot_Member]
GO
GRANT  EXECUTE  ON [dbo].[Dot_Casino_DailySettlement]  TO [Dot_Casino]
GO