
ALTER PROCEDURE [dbo].[Dot_Bingo_DailySettle] 
	@custid				int,  	
	@transtime			datetime,
	@betcredit			money,
---------------Bingo
	@BI_Turnover			money = 0,
	@BI_Winlost				money = 0,
	@BI_swinlost			money = 0,
	@BI_mwinlost			money = 0,
	@BI_awinlost			money = 0,
	@BI_scomm				money = 0,
	@BI_mcomm				money = 0,
	@BI_acomm				money = 0,
	@BI_playercomm			money = 0,
	@BI_pendingAmount		money = 0,
	@BI_sposition			smallmoney = 0,
	@BI_mposition			smallmoney = 0,
	@BI_aposition			smallmoney = 0,

	@refno				bigint OUTPUT,	
	@sessionId			bigint = 0,
	@newSessionId		bigint = 0,
	@transdesc			nvarchar(300)='',	
	@ip					nvarchar(15)='',
	@ErrCode			int = 0 OUTPUT,
	@ErrMsg				nvarchar(200) = '' OUTPUT
AS
/*
Creator : Jamie
Date : 2010-09-11
Task : Insert bingo Bet tickets at business cross day
DB: DBTRANS.bodb02

Revision:
	- 20110513@Henry: change bettype to new range
	- 20111029@Sophia: Update balance 
	- 20120412@Sophia: Revise balance 
	- 20120523@Lukas: from 2012-06-01 insert dummy balance transaction into bettrans2 instead of bettrans
	- 20120927@Elodie: No need to add dummy transaction into bettrans and backup table (bettrans2)
	- 20130704@Kathy: Update matchid for Bingo (73) 
	
Param's Explanation: 
• Full structure of Dummy accounts:
		--ACC Super		3rdSuperUUS		3rdSuperEURO    other currencies...
		--ACC Master	BIUS$			BIEURO
		--ACC Agent		BIUS$01			BIEURO01
		--ACC Member	BIBetUS$		BIBetEURO

• @bingoTurnover: always positive 
• @bingoWinlost: bingoWinlost = bingoTurnover + member's winlost 
• @ErrCode:
	= 0: Transaction recorded successfully.
	101 ~ 199: Specific Error for the phase of transfer from bingo to IBC.
	>200: Specific Error for the phase of transfer from IBC to bingo.
• @ErrMsg: Error description.
• @transtime: time of current session ending
• @betcredit: current betcredit in bingo
• @sessionId: current session id
• @newSessionId: new id for new session
*/

SET NOCOUNT ON

SELECT  @ErrCode = 0, @ErrMsg = '' 

IF @BI_Turnover < 0 OR @BI_Winlost < 0 
BEGIN
	SELECT @ErrMsg = 'Sorry, amount is invalid.', @ErrCode = 101	
	RETURN		
END

DECLARE	@roleid				tinyint,
		@username			varchar(30),
		@recommend			int, 
		@mrecommend			int, 
		@srecommend			int, 
		@actualrate			float, 
		@BI_mem_status			nvarchar(10),
		@BI_mem_statusID			int,
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
--check if srecommend < 100 and scomm <> mcomm and swinlost <>0
--member of direct master can not have supercomm<>scomm or swinlost <>0
if @srecommend<100 and (@BI_scomm <> @BI_mcomm or @BI_swinlost <>0 )
begin
	SELECT @ErrMsg = 'Invalid super/master comm or super winloss for member of direct master!', @ErrCode = 103		
	RETURN
end
--check not allow to update when there is no RUNNING transfer transaction
if NOT exists (select 1 from bettrans with (nolock)
            where custid = @custid and bettype = 23201 and ruben = 0 and refno=@refno 
            )
BEGIN
    SELECT @ErrMsg = 'There is NO running bingo transfer transaction (match with the session/refno)!', @ErrCode = 104		
	RETURN
END


SELECT @BI_mem_status = CASE WHEN @BI_Winlost > @BI_Turnover THEN 'WON'
						  WHEN @BI_Winlost < @BI_Turnover THEN 'LOSE'
						  ELSE 'DRAW' END 

SELECT @BI_mem_statusID = CASE WHEN @BI_Winlost > @BI_Turnover THEN 112
						  WHEN @BI_Winlost < @BI_Turnover THEN 113
						  ELSE 111 END   
-- 20120927@Elodie: No need to add dummy transaction into bettrans and backup table (bettrans2)
/*
SELECT	@dummy_custid = c.custid,
		@dummy_username = c.username,
		@dummy_recommend = c.recommend,
		@dummy_mrecommend = c.mrecommend,
		@dummy_srecommend = c.srecommend
FROM	custinfo c WITH (NOLOCK) 
WHERE	c.username = 'BIBet' + @currencyName AND c.roleid = 1 

IF isnull(@dummy_custid, 0) = 0
BEGIN
	SELECT @ErrMsg = 'Invalid Dummy account or Account is not existed!', @ErrCode = 106		
	RETURN
END
*/
------------------Insert trans into DB---------------------------------------------------------------
SELECT	@transdesc = 'Bingo Betting' + CASE WHEN @transdesc <> '' THEN ' - ' + @transdesc ELSE '' END

SELECT @transdate = @transtime , @winlostdate = CONVERT(nvarchar(10), @transtime, 120)

---INSERT bingo BET TICKET 
IF (@BI_Turnover > 0 or @BI_Winlost > 0)
BEGIN
---update debit balance 
	SELECT @balance = @BI_Winlost - @BI_Turnover + @BI_playercomm
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
	(@CustID, @username, @refno, @transdate, 73, 73, @transdesc, @BI_Winlost, @BI_Turnover, @BI_Turnover,
	 @BI_awinlost, @BI_mwinlost, @BI_swinlost, @BI_playercomm, @BI_acomm, @BI_mcomm, @BI_scomm, @winlostdate, 
	 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, @BI_aposition, @BI_mposition, @BI_sposition, @BI_aposition +@BI_mposition + @BI_sposition, 
	 @Currency, @actualrate, @currencyName, 1, @BI_mem_status,@BI_mem_statusID, @ip,@sessionId)

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

---INSERT BINGO PENDING BET TICKET 
IF @BI_pendingAmount > 0
BEGIN
	---update debit balance 
	EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @BI_pendingAmount
	
	INSERT INTO bettrans 
		(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, actual_stake, stake,
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, currency, actualrate, currencyName, 
		 ruben, status,statusID,ip,betid)
	VALUES 
		(@CustID, @username, @refno, @transdate, 0, 23202, @transdesc, 0, @BI_pendingAmount, @BI_pendingAmount,
		 0, 0, 0, 0, 0, 0, 0, @winlostdate, 
		 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 0, 'running',0, @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
		DELETE FROM bettrans WHERE custid = @custid and refNo = @refno AND bettype = 73 and matchid IN (0, 73)
		--rollback balance
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @BI_pendingAmount
		RETURN
	END	
END
---- 20120927@Elodie: No need to add dummy transaction into bettrans and backup table (bettrans2)
/*
IF (@BI_Turnover > 0 or @BI_Winlost > 0)
BEGIN
	IF @winlostdate < '2012-06-01'
	BEGIN
		-------INSERT bingo DUMMY TICKET
		INSERT INTO bettrans 
			(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
			 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
			 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
			 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,
			 currency, actualrate, currencyName, ruben, status,statusID,ip,betid)
		VALUES 
			(@dummy_custID, @dummy_username, @refno, @transdate, 0, 73, @transdesc, @BI_Turnover, @BI_Winlost,@BI_Winlost,
			 -@BI_awinlost, -@BI_mwinlost, -@BI_swinlost, -@BI_playercomm, -@BI_acomm, -@BI_mcomm, -@BI_scomm, @winlostdate, @dummy_custID, 
			 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
			 @Currency, @actualrate, @currencyName, 1, 'DONE',121, @ip,@sessionId)

		IF @@ERROR <> 0
		BEGIN			
			SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
			DELETE FROM bettrans WHERE refNo = @refno AND bettype in (73,23202) and matchid = 0
			RETURN
		END
	END
	-------INSERT bingo DUMMY TICKET INTO bettrans2
	INSERT INTO bettrans2
		(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,
		 currency, actualrate, currencyName, ruben, status,statusID,ip,betid)
	VALUES 
		(@dummy_custID, @dummy_username, @refno, @transdate, 0, 73, @transdesc, @BI_Turnover, @BI_Winlost,@BI_Winlost,
		 -@BI_awinlost, -@BI_mwinlost, -@BI_swinlost, -@BI_playercomm, -@BI_acomm, -@BI_mcomm, -@BI_scomm, @winlostdate, @dummy_custID, 
		 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 1, 'DONE',121, @ip,@sessionId)
	
END
*/
---------------UPDATE MEMBER TRANS 
SELECT  @balance = sum(winlost - actual_stake)
FROM	bettrans WITH (NOLOCK)
WHERE	refno = @refno and bettype = 23201 

--update debit balance
IF @balance > 0
	EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance

UPDATE bettrans SET status = 'Completed',statusID=131, ruben = 1, winlost = actual_stake WHERE refno = @refno and bettype = 23201 

IF @@ERROR <> 0
BEGIN			
	SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 108	
	--delete all trans of current session
	DELETE FROM bettrans WHERE refNo = @refno AND bettype in (73,23202) and matchid IN (0, 73)
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

------------UPDATE MEMBER PENDING BINGO TRANS OF PREVIOUS SESSION
SELECT  @balance = sum( winlost - actual_stake)
FROM	bettrans WITH (NOLOCK)  
WHERE	custid = @custid and bettype = 23202 and ruben = 0 and refno <> @refno

--update debit balance
IF @balance > 0
	EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance

UPDATE bettrans SET status = 'Completed',statusID=131, ruben = 1, winlost = actual_stake 
WHERE custid = @custid and bettype = 23202 and ruben = 0 and refno <> @refno


IF @@ERROR <> 0
BEGIN			
	SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 108	
	--revert transfer trans
	UPDATE bettrans SET status = 'running',statusID=0, ruben = 0, winlost = 0 
	WHERE refno = @refno and bettype = 23201 and ruben = 1  
	--delete all trans of current session
	DELETE FROM bettrans WHERE refNo = @refno AND bettype in (73,23202) and matchid IN (0, 73)
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

---------------------------------------------------------------------------------------------------

DECLARE @LogData nvarchar(300)

SELECT @LogData = 'Bingo Betting custid = ' + convert(nvarchar(20), @custid) + ', bettype = 73'  + ', bingoTurnover = ' + convert(nvarchar(20), @BI_Turnover) 
					 + ', bingoWinlost = ' + convert(nvarchar(20), @BI_Winlost)  
					 + case when @BI_pendingAmount > 0 then ', bingoPendingAmount = '+ convert(nvarchar(30),@BI_pendingAmount) else '' end
					 + ', refNo = ' + convert(nvarchar(20),@refno)  +', currency = ' + convert(nvarchar(10),@currency) 
					 + ', bingoPlayercomm = ' + convert(nvarchar(10),@BI_playercomm) + ', IP = '+ @ip 

BEGIN TRY
	EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData
END TRY
BEGIN CATCH
	-- if write log error: not return error code
END CATCH


---------------------TRANSFER BACK THE LEFT CREDIT-------------------------
select @refno=0

EXEC Dot_Bingo_TransferIns
	@custid=@custid, 	
	@bingoCredit=@betcredit,
	@transdesc='transfer back to bingo at cross day while player online in Bingo',	
	@ip	= @ip,
	@refno = @refno OUTPUT,	
	@sessionId = @newSessionId,
	@ErrCode  = @ErrCode OUTPUT,
	@ErrMsg = @ErrMsg OUTPUT
if @ErrCode <> 0
	select @ErrCode = @ErrCode + 100

GO
GRANT EXECUTE ON [dbo].[Dot_Bingo_DailySettle] TO [Dot_Member]
GO
GRANT EXECUTE ON [dbo].[Dot_Bingo_DailySettle] TO [Dot_Casino]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Bingo_DailySettle]  TO [VNTeam]
GO