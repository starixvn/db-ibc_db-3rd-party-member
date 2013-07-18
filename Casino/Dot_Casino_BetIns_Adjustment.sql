ALTER PROCEDURE [dbo].[Dot_Casino_BetIns_Adjustment] 
	@custid				int,  	
------------------------Casino
	@CS_Turnover			money = 0,
	@CS_Winlost				money = 0,
	@CS_swinlost			money = 0,
	@CS_mwinlost			money = 0,
	@CS_awinlost			money = 0,
	@CS_scomm				money = 0,
	@CS_mcomm				money = 0,
	@CS_acomm				money = 0,
	@CS_playercomm			money = 0,
	@CS_pendingAmount		money = 0,
	@CS_sposition			smallmoney = 0,
	@CS_mposition			smallmoney = 0,
	@CS_aposition			smallmoney = 0,
------------------------P2P
	@P2P_Turnover			money = 0,
	@P2P_Winlost			money = 0,
	@P2P_scomm				money = 0,
	@P2P_mcomm				money = 0,
	@P2P_acomm				money = 0,
	@P2P_pendingAmount		money = 0,
	
	@refno				bigint,	
	@sessionId			bigint = 0,
	@transdesc			nvarchar(300)='',	
	@ip					nvarchar(15)='',
	@ErrCode			int = 0 OUTPUT,
	@ErrMsg				nvarchar(200) = '' OUTPUT
AS
/*
Creator : Phuong Dao
Date : 2009-02-10
Task : Insert Casino Bet tickets
DB: DBTRANS.bodb02

History:
    -20090212@Thien: Revise
	-20090214@PhuongDao: Replace Input param @custid to @username
	-20090214@Thien:
	    +check not allow to update when there is no RUNNING transfer transaction
	    +Check the existing of dummy account..
    -20090219@PhuongDoan:
		+Add pendingAmount      
		+Replace @username by @custid
		+Add @sessionId into betid field
		+Use @refno instead of @transid
	-20090224
		+Separate casino and p2p transaction
	-20090305@PhuongDoan: enable multiple transfer
	-20100507@Henry: insert/update data to column statusID of bettrans
	-20110513@Henry: change bettype to new range
	-20110628@Sophia: Update balance credit/debit
	-20120406@Sophia: Exclude P2P in the calculation of Casino  
	-20120412@sophia: Revise credit/debit balance for member
	-20120522@Lukas: from 2012-06-01 insert dummy balance transaction into bettrans2 instead of bettrans
	-20120927@Elodie: No need to add dummy transaction into bettrans and backup table (bettrans2)
	- 20130705@Kathy: Update matchid for RnG Casino (71)
	
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
		
----20120406@Sophia: Exclude P2P in the calculation of Casino  
--		@p2p_mem_status		nvarchar(10),
--		@p2p_mem_statusID	int,
		@currency			tinyint, 
		@currencyName		nvarchar(5), 
		@transdate			datetime, 
		@winlostdate		datetime,
-- 20120927@Elodie: No need to add dummy transaction into bettrans and backup table (bettrans2)
		--@dummy_username		nvarchar(15),
		--@dummy_custid		int,
		--@dummy_recommend	int,
		--@dummy_mrecommend	int,
		--@dummy_srecommend	int,
		@balance			money,
		@balance_ABS		money		

SELECT  @ErrCode = 0, @ErrMsg = '' 
/*
IF @cs_Turnover < 0 OR @cs_Winlost < 0 ----or @p2p_Turnover < 0 OR @p2p_Winlost < 0
BEGIN
	SELECT @ErrMsg = 'Sorry, amount is invalid.', @ErrCode = 101	
	RETURN		
END
*/
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
if @srecommend<100 and (@cs_scomm <> @cs_mcomm or @cs_swinlost <>0) ----or @p2p_scomm <> @p2p_mcomm) ----20120406@Sophia: Exclude P2P in the calculation of Casino  
begin
	SELECT @ErrMsg = 'Invalid super/master comm or super winloss for member of direct master!', @ErrCode = 103		
	RETURN
end
/*
--20090214@Thien: check not allow to update when there is no RUNNING transfer transaction
if NOT exists (select 1 from bettrans with (nolock)
            where matchid=0 and custid = @custid and bettype = 112 and ruben = 0 and refno=@refno 
            )
BEGIN
    SELECT @ErrMsg = 'There is NO running Casino transfer transaction (match with the session/refno)!', @ErrCode = 104		
	RETURN
END
*/

SELECT @cs_mem_status = CASE WHEN @cs_Winlost > @cs_Turnover THEN 'WON'
						  WHEN @cs_Winlost < @cs_Turnover THEN 'LOSE'
						  ELSE 'DRAW' END 

SELECT @cs_mem_statusID = CASE WHEN @cs_Winlost > @cs_Turnover THEN 112
						  WHEN @cs_Winlost < @cs_Turnover THEN 113
						  ELSE 111 END 
						  
						  
----20120406@Sophia: Exclude P2P in the calculation of Casino  
/*		  
SELECT @p2p_mem_status = CASE WHEN @p2p_Winlost > @p2p_Turnover THEN 'WON'
						  WHEN @p2p_Winlost < @p2p_Turnover THEN 'LOSE'
						  ELSE 'DRAW' END 

SELECT @p2p_mem_statusID = CASE WHEN @p2p_Winlost > @p2p_Turnover THEN 112
						  WHEN @p2p_Winlost < @p2p_Turnover THEN 113
						  ELSE 111 END 

*/
--20120927@Elodie: No need to add dummy transaction into bettrans and backup table (bettrans2)
/*
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
*/
------------------Insert trans into DB---------------------------------------------------------------
SELECT	@transdesc = 'Casino Betting' + CASE WHEN @transdesc <> '' THEN ' - ' + @transdesc ELSE '' END

SELECT @transdate = CURRENT_TIMESTAMP , @winlostdate = CONVERT(nvarchar(10), CURRENT_TIMESTAMP, 120)

--IF (@CS_Turnover > 0 or @CS_Winlost > 0)
--BEGIN

---INSERT CASINO BET TICKET 
---update debit balance 
	SELECT @balance = @cs_Winlost - @cs_Turnover + @cs_playercomm
	IF 	@balance < 0 
	BEGIN 
		SELECT @balance_ABS = ABS(@balance)
		EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance_ABS
	END 

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
		--rollback balance
		IF 	@balance < 0 
		BEGIN 
			SELECT @balance_ABS = ABS(@balance)
			EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance_ABS
		END  	
		RETURN
	END	
	
	---update credit balance 
	IF  @balance > 0 
	BEGIN 
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
	END
	
--END

----20120406@Sophia: Exclude P2P in the calculation of Casino  
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
		(@CustID, @username, @refno, @transdate, 0, 72, @transdesc, @p2p_Winlost, @p2p_Turnover, @p2p_Turnover,
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
	---update debit balance 
	EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @cs_pendingAmount
	
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
		DELETE FROM bettrans WHERE custid = @custid and refNo = @refno AND bettype in (71) and matchid in (0, 71)
		--rollback balance
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @cs_pendingAmount
		RETURN
	END	
END

----20120406@Sophia: Exclude P2P in the calculation of Casino  
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
		(@CustID, @username, @refno, @transdate, 0, 23101, @transdesc, 0, @p2p_pendingAmount,@p2p_pendingAmount, 
		 0, 0, 0, 0, 0, 0, 0, @winlostdate, 
		 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 0, 'running',0, @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
		DELETE FROM bettrans WHERE custid = @custid and refNo = @refno AND bettype in (71,72,23002) and matchid = 0
		RETURN
	END	
END
*/
--20120927@Elodie: No need to add dummy transaction into bettrans and backup table (bettrans2)
/*IF @winlostdate < '2012-06-01'
BEGIN
	--IF (@CS_Turnover > 0 or @CS_Winlost > 0)
	--BEGIN
		--INSERT CASINO DUMMY TICKET
		INSERT INTO bettrans 
			(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
			 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
			 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
			 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,
			 currency, actualrate, currencyName, ruben, status,statusID,ip,betid)
		VALUES 
			(@dummy_custID, @dummy_username, @refno, @transdate, 0, 71, @transdesc, @cs_Turnover, @cs_Winlost,@cs_Winlost,
			 -@cs_awinlost, -@cs_mwinlost, -@cs_swinlost, -@cs_playercomm, -@cs_acomm, -@cs_mcomm, -@cs_scomm, @winlostdate, @dummy_custID, 
			 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
			 @Currency, @actualrate, @currencyName, 1, 'DONE',121, @ip,@sessionId)

		IF @@ERROR <> 0
		BEGIN			
			SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
			DELETE FROM bettrans WHERE refNo = @refno AND bettype in (71,23002) and matchid = 0
			RETURN
		END
	--END
END
--IF (@CS_Turnover > 0 or @CS_Winlost > 0)
--BEGIN
	--INSERT CASINO DUMMY TICKET
	INSERT INTO bettrans2 
		(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,
		 currency, actualrate, currencyName, ruben, status,statusID,ip,betid)
	VALUES 
		(@dummy_custID, @dummy_username, @refno, @transdate, 0, 71, @transdesc, @cs_Turnover, @cs_Winlost,@cs_Winlost,
		 -@cs_awinlost, -@cs_mwinlost, -@cs_swinlost, -@cs_playercomm, -@cs_acomm, -@cs_mcomm, -@cs_scomm, @winlostdate, @dummy_custID, 
		 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 1, 'DONE',121, @ip,@sessionId)
*/
	
--END

----20120406@Sophia: Exclude P2P in the calculation of Casino  
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
		(@dummy_custID, @dummy_username, @refno, @transdate, 0, 72, @transdesc, @p2p_Turnover,@p2p_Winlost, @p2p_Winlost,
		 0, 0, 0, 0, -@p2p_acomm, -@p2p_mcomm, -@p2p_scomm, @winlostdate, @dummy_custID, 
		 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 1, 'DONE',121, @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
		--delete all trans of current session
		DELETE FROM bettrans WHERE refNo = @refno AND bettype in (71,72,23002,23101) and matchid = 0
		RETURN
	END
END
*/

--UPDATE MEMBER TRANS 
SELECT  @balance = sum(winlost - actual_stake)
FROM	bettrans WITH (NOLOCK)
WHERE	custid=@custid and refno = @refno and bettype = 23001 and matchid = 0

--update debit balance
IF @balance > 0
	EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance
	
UPDATE bettrans WITH (ROWLOCK, UPDLOCK)
    SET status = 'Completed',statusID=131, ruben = 1, winlost = actual_stake
WHERE custid=@custid and refno = @refno and bettype = 23001 and matchid = 0


IF @@ERROR <> 0
BEGIN			
	SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 108	
	--delete all trans of current session
	DELETE FROM bettrans WHERE refNo = @refno AND bettype in (71,23002) and matchid in (0, 71)
	--rollback
	IF @balance > 0
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
	RETURN
END

--update credit balance
IF @balance < 0
BEGIN
	SET @balance = ABS(@balance)
	EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
END

--UPDATE MEMBER PENDING CASINO TRANS OF PREVIOUS SESSION
SELECT  @balance = sum(winlost - actual_stake)
FROM	bettrans WITH (NOLOCK)
WHERE	custid = @custid and bettype = 23002 and ruben = 0 and refno <> @refno and matchid = 0

--update debit balance
IF @balance > 0
	EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance
	
UPDATE bettrans WITH (ROWLOCK, UPDLOCK) SET status = 'Completed',statusID=131, ruben = 1, winlost = actual_stake 
WHERE custid = @custid and bettype = 23002 and ruben = 0 and refno <> @refno and matchid = 0

IF @@ERROR <> 0
BEGIN			
	SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 108	
	--revert transfer trans
	UPDATE bettrans WITH (ROWLOCK, UPDLOCK) SET status = 'running',statusID=0, ruben = 0, winlost = 0 
	WHERE refno = @refno and bettype = 23001 and ruben = 1 and matchid = 0 
	--delete all trans of current session
	DELETE FROM bettrans WHERE refNo = @refno AND bettype in (71,23002) and matchid in (0, 71)
	--rollback
	IF @balance > 0
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
	RETURN
END

--update credit balance
IF @balance < 0
BEGIN
	SET @balance = ABS(@balance)
	EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
END
	
----20120406@Sophia: Exclude P2P in the calculation of Casino  
/*
--UPDATE MEMBER PENDING P2P TRANS OF PREVIOUS SESSION
SELECT  @bf_p2p_pending = sum(winlost - actual_stake )
FROM	bettrans WITH (NOLOCK)
WHERE	custid = @custid and bettype = 23101 and ruben = 0 and refno <> @refno and matchid = 0

UPDATE bettrans WITH (ROWLOCK, UPDLOCK) SET status = 'Completed',statusID=131, ruben = 1, winlost = actual_stake 
WHERE custid = @custid and bettype = 23101 and ruben = 0 and refno <> @refno and matchid = 0

SELECT  @at_p2p_pending = sum(winlost - actual_stake )
FROM	bettrans WITH (NOLOCK)
WHERE	custid = @custid and bettype = 23101 and ruben = 1 and refno <> @refno and matchid = 0

IF @@ERROR <> 0
BEGIN			
	SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 108	
	--revert transfer trans
	UPDATE bettrans WITH (ROWLOCK, UPDLOCK) SET status = 'running',statusID=0, ruben = 0, winlost = 0 
	WHERE refno = @refno and bettype = 23001 and ruben = 1 and matchid = 0
	--revert casino pending trans
	UPDATE bettrans WITH (ROWLOCK, UPDLOCK) SET status = 'running',statusID=0, ruben = 0, winlost = 0 
    WHERE custid = @custid and bettype = 23101 and ruben = 0 and refno <> @refno and matchid = 0
	--delete all trans of current session
	DELETE FROM bettrans WHERE refNo = @refno AND bettype in (71,72,23002,23101) and matchid = 0
	RETURN
END
*/

---------------------------------------------------------------------------------------------------

DECLARE @LogData nvarchar(300)

SELECT @LogData = 'Casino Betting custid = ' + convert(nvarchar(20), @custid) + ', bettype = 71'  + ', casinoTurnover = ' + convert(nvarchar(20), @cs_Turnover) 
					 + ', casinoWinlost = ' + convert(nvarchar(20), @cs_Winlost) ----+ ', P2PTurnover = ' + convert(nvarchar(20), @p2p_Turnover)  ----20120406@Sophia: Exclude P2P in the calculation of Casino  
					 + case when @cs_pendingAmount > 0 then ', casinoPendingAmount = '+ convert(nvarchar(30),@cs_pendingAmount) else '' end
					 ----+ case when @p2p_pendingAmount > 0 then ', P2PPendingAmount = '+ convert(nvarchar(30),@p2p_pendingAmount) else '' end ----20120406@Sophia: Exclude P2P in the calculation of Casino  
					 + ', refNo = ' + convert(nvarchar(20),@refno)  +', currency = ' + convert(nvarchar(10),@currency) 
					 + ', CasinoPlayercomm = ' + convert(nvarchar(10),@cs_playercomm) + ', IP = '+ @ip 

EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData



GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Casino_BetIns_Adjustment] TO [vnteam]