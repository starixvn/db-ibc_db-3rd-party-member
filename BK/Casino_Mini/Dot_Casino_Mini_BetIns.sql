ALTER PROCEDURE [dbo].[Dot_Casino_Mini_BetIns]
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
	@refno [bigint],
	@sessionId [bigint] = 0,
	@transdesc [nvarchar](300) = '',
	@ip [nvarchar](15) = '',
	@ErrCode [int] = 0 OUTPUT,
	@ErrMsg [nvarchar](200) = '' OUTPUT
WITH EXECUTE AS CALLER
AS
/*
Creator : Thien Pham
Date : 2010-03-07
Task : Insert Casino Mini Game Bet tickets
DB: DBTRANS.bodb02

History:
    -20100307@Thien: 
    -20111026@Sophia: Update credit/debit balance for member
    -20120412@Sophia: Revise credit/debit balance for member
	-20130705@Kathy: Update matchid for Bingo (73)	
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
		@balance_ABS		money

SELECT  @ErrCode = 0, @ErrMsg = '' 

IF @cs_Turnover < 0 OR @cs_Winlost < 0
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
if @srecommend < 100 and (@cs_scomm <> @cs_mcomm or @cs_swinlost <>0)
begin
	SELECT @ErrMsg = 'Invalid super/master comm or super winloss for member of direct master!', @ErrCode = 103		
	RETURN
end
--20090214@Thien: check not allow to update when there is no RUNNING transfer transaction
if NOT exists (select 1 from bettrans with (nolock)
            where matchid=0 and custid = @custid and bettype = 117 and ruben = 0 and refno=@refno 
            )
BEGIN
    SELECT @ErrMsg = 'There is NO running Casino Mini Games transfer transaction (match with the session/refno)!', @ErrCode = 104		
	RETURN
END


SELECT @cs_mem_status = CASE WHEN @cs_Winlost > @cs_Turnover THEN 'WON'
						  WHEN @cs_Winlost < @cs_Turnover THEN 'LOSE'
						  ELSE 'DRAW' END 


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
SELECT	@transdesc = 'Casino Mini Games Betting' + CASE WHEN @transdesc <> '' THEN ' - ' + @transdesc ELSE '' END

SELECT @transdate = CURRENT_TIMESTAMP , @winlostdate = CONVERT(nvarchar(10), CURRENT_TIMESTAMP, 120)

---INSERT CASINO MINI GAMES BET TICKET 
IF (@CS_Turnover > 0 or @CS_Winlost > 0)
BEGIN
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
	 ruben, status, ip, betid)
	VALUES 
	(@CustID, @username, @refno, @transdate, 73, 73, @transdesc, @cs_Winlost, @cs_Turnover, @cs_Turnover,
	 @cs_awinlost, @cs_mwinlost, @cs_swinlost, @cs_playercomm, @cs_acomm, @cs_mcomm, @cs_scomm, @winlostdate, 
	 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, @CS_aposition, @CS_mposition, @CS_sposition, @CS_aposition +@CS_mposition + @CS_sposition, 
	 @Currency, @actualrate, @currencyName, 1, @cs_mem_status, @ip, @sessionId)

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
	
END

---INSERT CASINO MINI GAMES PENDING BET TICKET 
IF @cs_pendingAmount > 0
BEGIN
	---update debit balance 
	EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @cs_pendingAmount
	
	INSERT INTO bettrans 
		(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, actual_stake, stake,
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, currency, actualrate, currencyName, 
		 ruben, status, ip, betid)
	VALUES 
		(@CustID, @username, @refno, @transdate, 0, 118, @transdesc, 0, @cs_pendingAmount, @cs_pendingAmount,
		 0, 0, 0, 0, 0, 0, 0, @winlostdate, 
		 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 0, 'running', @ip, @sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
		DELETE FROM bettrans WHERE custid = @custid and refNo = @refno AND bettype in (73) and matchid IN (0, 73)
		--rollback balance
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @cs_pendingAmount
		RETURN
	END	
END


IF (@CS_Turnover > 0 or @CS_Winlost > 0)
BEGIN
	--INSERT CASINO MINI GAMES DUMMY TICKET
	INSERT INTO bettrans 
		(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,
		 currency, actualrate, currencyName, ruben, status, ip, betid)
	VALUES 
		(@dummy_custID, @dummy_username, @refno, @transdate, 73, 73, @transdesc, @cs_Turnover, @cs_Winlost,@cs_Winlost,
		 -@cs_awinlost, -@cs_mwinlost, -@cs_swinlost, -@cs_playercomm, -@cs_acomm, -@cs_mcomm, -@cs_scomm, @winlostdate, @dummy_custID, 
		 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 1, 'DONE', @ip, @sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
		DELETE FROM bettrans WHERE refNo = @refno AND bettype in (73,118) and matchid IN (0, 73)
		RETURN
	END
END

-----UPDATE MEMBER TRANS 
SELECT  @balance = sum(winlost - actual_stake)
FROM	bettrans WITH (NOLOCK)
WHERE	custid=@custid and refno = @refno and bettype = 117 and matchid = 0 

--update debit balance
IF @balance > 0 
BEGIN 
	EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance
END 
	
UPDATE	bettrans WITH (ROWLOCK, UPDLOCK)
SET		status = 'Completed', ruben = 1, winlost = actual_stake
WHERE	custid=@custid and refno = @refno and bettype = 117 and matchid = 0

IF @@ERROR <> 0
BEGIN			
	SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 108	
	--delete all trans of current session
	DELETE FROM bettrans WHERE refNo = @refno AND bettype in (73,118) and matchid IN (0, 73)
	-- rollback balance
	IF 	@balance > 0 
		BEGIN 
			EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
		END 
	RETURN
END

---update credit balance 
IF  @balance < 0 
BEGIN 
	SELECT @balance = ABS(@balance)
	EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
END
	

----UPDATE MEMBER PENDING CASINO MINI GAMES TRANS OF PREVIOUS SESSION
SELECT  @balance = sum(winlost-actual_stake)
FROM	bettrans WITH (NOLOCK)
WHERE	custid = @custid and bettype = 118 and ruben = 0 and refno <> @refno and matchid = 0

--update debit balance
IF @balance > 0 
BEGIN 
	EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance
END 

UPDATE bettrans WITH (ROWLOCK, UPDLOCK) SET status = 'Completed', ruben = 1, winlost = actual_stake 
WHERE custid = @custid and bettype = 118 and ruben = 0 and refno <> @refno and matchid = 0

IF @@ERROR <> 0
BEGIN			
	SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 108	
	--revert transfer trans
	UPDATE bettrans WITH (ROWLOCK, UPDLOCK) SET status = 'running', ruben = 0, winlost = 0 
	WHERE refno = @refno and bettype = 117 and ruben = 1 and matchid = 0 
	--delete all trans of current session
	DELETE FROM bettrans WHERE refNo = @refno AND bettype in (73,118) and matchid IN (0, 73)
	-- rollback balance
	IF @balance > 0 
	BEGIN 
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
	END 
	RETURN
END
---update credit balance 
IF  @balance < 0 
BEGIN 
	SELECT @balance = ABS(@balance)
	EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
END


---------------------------------------------------------------------------------------------------

DECLARE @LogData nvarchar(300)
SELECT @LogData = 'Casino Mini Games Betting custid = ' + convert(nvarchar(20), @custid) + ', bettype = 73'  + ', casinoTurnover = ' + convert(nvarchar(20), @cs_Turnover) 
					 + ', casinoWinlost = ' + convert(nvarchar(20), @cs_Winlost)
					 + case when @cs_pendingAmount > 0 then ', casinoPendingAmount = '+ convert(nvarchar(30),@cs_pendingAmount) else '' end
					 + ', refNo = ' + convert(nvarchar(20),@refno)  +', currency = ' + convert(nvarchar(10),@currency) 
					 + ', CasinoPlayercomm = ' + convert(nvarchar(10),@cs_playercomm) + ', IP = '+ @ip 

EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData



GO
GRANT EXECUTE ON [dbo].[Dot_Casino_Mini_BetIns] TO [Dot_Casino]
GO
GRANT EXECUTE ON [dbo].[Dot_Casino_Mini_BetIns] TO [Dot_Member]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Casino_Mini_BetIns] TO [vnteam]