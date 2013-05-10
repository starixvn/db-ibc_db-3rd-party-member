USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_P2P_BetIns]    Script Date: 10/10/2012 03:57:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Dot_P2P_BetIns    Script Date: 4/18/2012 3:50:57 PM ******/
/****** Object:  Stored Procedure dbo.Dot_P2P_BetIns    Script Date: 4/3/2012 5:18:18 PM ******/
/****** Object:  Stored Procedure dbo.Dot_P2P_BetIns    Script Date: 2/9/2012 3:49:07 PM ******/


ALTER PROCEDURE [dbo].[Dot_P2P_BetIns]
	@CustID				INT,  		
	@SessionId			NVARCHAR(50),
	@Turnover			MONEY = 0,
	@Winlost			MONEY = 0,
	@IBC_comm			SMALLMONEY = 0, 
	@Player_comm		MONEY = 0,
	@PendingAmount		MONEY=0,
	@TotalRake			SMALLMONEY = 0,
	@Transdesc			NVARCHAR(300)='',	
	@IP					NVARCHAR(15)='',
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(200) = '' OUTPUT
AS
/*
Creator : Amy
Date : 2011-02-16
Task : Insert P2P Bet tickets
DB: DBTrans.bodb02

Revisions:
	-20111026@Sophia: Update credit/debit balance for member
	-20110409@Tim :fix calculation of @IBC_comm
	-20110412@Tim :remove calculation of @IBC_comm. b/c no need. the value pass in is ok
	-20120412@Sophia: Revise credit/debit balance for member
Param's Explanation:

• Full structure of Dummy accounts:
		--ACC Super		3rdSuperUUS		3rdSuperEURO    other currencies...
		--ACC Master	BIUS$			BIEURO
		--ACC Agent		BIUS$01			BIEURO01
		--ACC Member	BIBetUS$		BIBetEURO

• @CustID: member cust id
• @SessionId: Member session ID
• @Turnover: Total turnover which member played in session
• @Winlost: Member winlost amount in session
• @IBC_comm: total commission amount which IBC received in session 
• @player_comm: Commission amount which Member received in session
• @Transdesc: transaction description
• @PendingAmount: Amount which member's playing unsettled game.
• @ErrCode
	= 0: Transaction recorded successfully.
	> 0: Specific Error.
	max is: 108
• @ErrMsg: Error description.

*/

SET NOCOUNT ON

DECLARE @scomm MONEY, @mcomm MONEY, @acomm MONEY
DECLARE @refno BIGINT
DECLARE @DB_IBCcomm SMALLMONEY, @DB_playercomm MONEY, @DB_Winlost MONEY, @DB_Turnover MONEY, @DB_TotalRake SMALLMONEY

DECLARE	@roleid				TINYINT,
		@username			VARCHAR(30),
		@recommend			INT, 
		@mrecommend			INT, 
		@srecommend			INT, 
		@actualrate			FLOAT, 
		@Mem_status			NVARCHAR(10),
		@Mem_statusID		INT,
		@currency			TINYINT, 
		@currencyName		NVARCHAR(5), 
		@transdate			DATETIME,
		@winlostdate		DATETIME,
		@balance			money,
		@balance_ABS		money,
		@TransID			bigint

SELECT  @ErrCode = 0, @ErrMsg = '' 

IF @Turnover < 0 OR @Winlost < 0 
BEGIN
	SELECT @ErrMsg = 'Sorry, amount is invalid.', @ErrCode = 101	
	RETURN
END

SELECT	@username= ci.username,
		@roleid = ISNULL(ci.roleid,0), 
		@recommend = ci.recommend,
		@mrecommend = ci.mrecommend, 
		@srecommend = ci.srecommend,
		@currency = ci.currency, 
		@currencyName = e.currency, 
		@actualrate = e.actualrate
FROM	custInfo ci WITH (NOLOCK) 
		INNER JOIN exchange e WITH (NOLOCK) ON ci.currency = e.exchangeid
WHERE   ci.custid = @custid 

IF @roleid <> 1
BEGIN
	SELECT @ErrMsg = 'Invalid Role ID.', @ErrCode = 102	
	RETURN
END

--check not allow to update when there is no RUNNING transfer transaction
SELECT @refno = refno
FROM bettrans WITH (NOLOCK)
WHERE custId=@custID AND betcheck=@sessionId AND bettype = 23101 AND ruben=0

IF @refno IS NULL
BEGIN
	SELECT @ErrMsg = 'There is NO running P2P transfer transaction (match with the session/refno)', @ErrCode = 104	
	RETURN
END

IF EXISTS (SELECT TOP 1 refno FROM bettransm WITH(NOLOCK) WHERE refno=@refno AND statusID=0)
BEGIN
	SELECT @ErrMsg = 'There is RUNNING game details', @ErrCode = 111
	RETURN
END

-- Sum total amount from game details
SELECT @scomm=SUM(ISNULL(scomm,0)),
		@mcomm=SUM(ISNULL(acomm,0)),
		@acomm=SUM(ISNULL(comm,0)),
		@DB_playercomm=SUM(ISNULL(playercomm,0)),
		@DB_TotalRake=SUM(ISNULL(oddsspread,0)),
		@DB_IBCcomm=SUM(ISNULL(odds,0)),
		@DB_Turnover=SUM(ISNULL(stake,0)),
		@DB_Winlost=SUM(ISNULL(winlost,0))
FROM bettransm WITH (NOLOCK)
WHERE custId=@custID AND matchid =1000 AND refno=@refno

-- 2012-03-26 Tim:Rake that ibc gets need to calculate from ibc site. p2p don't have that value
-- 2012-04-09 Tim: p2p pass in @IBC_com = total rake licensee. thus need to do below calculation
-- 2012-04-12 Tim: remove ibc_comm calculation
/*
SELECT @IBC_comm = CASE WHEN @srecommend < 100 
							THEN @IBC_comm - @DB_playercomm - @acomm
						ELSE @IBC_comm - @DB_playercomm - @acomm - @mcomm
						END
*/
--check if srecommend < 100 and scomm <> mcomm 
IF @srecommend<100 AND (@scomm <> @mcomm)
BEGIN
	SELECT @ErrMsg = 'Invalid super/master comm or super winloss for member of direct master!', @ErrCode = 103
	RETURN
END

--Compare input values and DB values
--marked Tim 2012-6-8 temp
/*IF (@DB_IBCcomm <> @IBC_comm OR @DB_playercomm <> @Player_comm OR @DB_Winlost <> @Winlost OR @DB_Turnover <> @Turnover OR @TotalRake <> @DB_TotalRake)
BEGIN
	SELECT @ErrMsg = 'Winlost/commission amount does not match.', @ErrCode = 1054
	RETURN
END
*/
SELECT @Mem_status = CASE WHEN @Winlost > @Turnover THEN 'WON'
						  WHEN @Winlost < @Turnover THEN 'LOSE'
						  ELSE 'DRAW' END 

SELECT @Mem_statusID = CASE WHEN @Winlost > @Turnover THEN 112
						  WHEN @Winlost < @Turnover THEN 113
						  ELSE 111 END 

------------------Insert trans into DB---------------------------------------------------------------
SELECT	@transdesc = 'P2P Betting' + CASE WHEN @transdesc <> '' THEN ' - ' + @transdesc ELSE '' END

SELECT @transdate = CURRENT_TIMESTAMP , @winlostdate = CONVERT(NVARCHAR(10), CURRENT_TIMESTAMP, 120)

-----------INSERT P2P BET TICKET 
IF (@Turnover > 0 OR @Winlost > 0)
BEGIN

--update debit balance
	SELECT @balance = @winlost - @turnover + @Player_comm
	IF 	@balance < 0 
	BEGIN 
		SELECT @balance_ABS = ABS(@balance)
		EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance_ABS
	END 
	
	INSERT INTO bettrans
		(custId, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake,
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, odds, oddsspread, winlostdate, creator,
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount,
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, currency, actualrate, CurrencyName,
		 ruben, status,statusID,ip,betcheck)
	VALUES
		(@CustID, @username, @refno, @transdate, 1000, 1000, @transdesc, @Winlost, @Turnover, @Turnover,
		 0, 0, 0, @Player_comm, @acomm, @mcomm, @scomm,@IBC_comm, @TotalRake, @winlostdate, @CustID, 
		 @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0,
		 0, 0, 0, 0, @Currency, @actualrate, @currencyName,
		 1, @Mem_status,@Mem_statusID, @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 106
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


--------- UPDATE WINLOSTDATE FOR GAME DETAIL
	UPDATE bettransm WITH (ROWLOCK,UPDLOCK)
	SET winlostdate=@winlostdate
	WHERE refno=@refno AND matchid=1000

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107
		--revert P2P bet ticket
		DELETE FROM bettrans 
		WHERE refno = @refno AND bettype = 1000 AND matchid = 1000
		
		RETURN
	END

END

----------INSERT P2P PENDING BET TICKET 
IF @PendingAmount > 0
BEGIN
	--update debit balance
	EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @PendingAmount
	
	INSERT INTO bettrans 
		(custId, username, refno, transdate, matchid, bettype, transdesc, winlost, actual_stake, stake,
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, currency, actualrate, CurrencyName, 
		 ruben, status,statusID,ip,betcheck)
	VALUES 
		(@CustID, @username, @refno, @transdate, 0, 23102, @transdesc, 0, @PendingAmount, @PendingAmount,
		 0, 0, 0, 0, 0, 0, 0, @winlostdate, @CustID, 
		 @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, 
		 0, 0, 0, 0, @Currency, @actualrate, @currencyName, 
		 0, 'running',0, @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 108
		--revert P2P bet ticket
		DELETE FROM bettrans 
		WHERE refno = @refno AND bettype =1000 AND matchid = 1000
		
		--revert update winlostdate bettransm
		UPDATE bettransm WITH (ROWLOCK,UPDLOCK)
		SET winlostdate = NULL
		WHERE refno = @refno AND matchid=1000
		
		-- revert balance
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @PendingAmount
		RETURN
	END
	SELECT @TransID = @@IDENTITY		
END

-----------------UPDATE MEMBER TRANS 
SELECT  @balance = sum(winlost-actual_stake)
FROM	bettrans WITH (NOLOCK)
WHERE	custId=@custid AND refno = @refno AND bettype = 23101 AND matchid = 0

--update debit balance
IF @balance > 0
	BEGIN
		EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance
	END 
	
UPDATE bettrans WITH (ROWLOCK, UPDLOCK)
SET status = 'Completed', statusID=131, ruben = 1, winlost = actual_stake
WHERE custId=@custid AND refno = @refno AND bettype = 23101 AND matchid = 0

IF @@ERROR <> 0
BEGIN
	SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 109
	
	--revert P2P bet ticket & pending tickets
	DELETE FROM bettrans 
	WHERE refno = @refno AND bettype IN(1000, 23102)
	
	--revert update winlostdate bettransm
	UPDATE bettransm WITH (ROWLOCK,UPDLOCK)
	SET winlostdate = NULL
	WHERE refno = @refno AND matchid=1000
	
	--revert balance
	IF @balance > 0
	BEGIN
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
	END 	
	RETURN
END

--update credit balance
IF @balance < 0
BEGIN
	SELECT @balance = ABS(@balance)
	EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
END


-----------------UPDATE MEMBER PENDING P2P TRANS OF PREVIOUS SESSION
SELECT  @balance = sum(winlost -actual_stake)
FROM  bettrans WITH (NOLOCK)
WHERE custId = @custid AND bettype = 23102 AND ruben = 0 AND refno <> @refno AND matchid = 0

--update debit balance
IF @balance > 0
	BEGIN
		EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance
	END 
	
UPDATE bettrans WITH (ROWLOCK, UPDLOCK) 
SET status = 'Completed',statusID=131, ruben = 1, winlost = actual_stake 
WHERE custId = @custid AND bettype = 23102 AND ruben = 0 AND refno <> @refno AND matchid = 0



IF @@ERROR <> 0
BEGIN
	SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 110
	
	--revert P2P bet ticket & pending tickets
	DELETE FROM bettrans 
	WHERE refno = @refno AND bettype IN(1000, 23102)
	
	--revert update winlostdate bettransm
	UPDATE bettransm WITH (ROWLOCK,UPDLOCK)
	SET winlostdate = NULL
	WHERE refno = @refno AND matchid=1000
	
	--revert update transfer trans
	UPDATE bettrans WITH (ROWLOCK, UPDLOCK) 
	SET status = 'running',statusID=0, ruben = 0, winlost = 0 
	WHERE refno = @refno AND bettype = 23101 AND ruben = 1 AND matchid = 0
	
	--revert balance
	IF @balance > 0
	BEGIN
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
	END 	
	
RETURN
END

--update credit balance
IF @balance < 0
BEGIN
	SELECT @balance = ABS(@balance)
	EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
END
	
---------------------------------------------------------------------------------------------------
DECLARE @LogData NVARCHAR(300)

SELECT @LogData = 'P2P Betting : SessionId = ' + CONVERT(NVARCHAR(50),@SessionId) 
					+ ', bettype = 1000' 
					+ ', Turnover = ' + CONVERT(NVARCHAR(20), @Turnover) 
					+ ', Winlost = ' + CONVERT(NVARCHAR(20), @Winlost)
					+ ', TotalRake = ' + CONVERT(NVARCHAR(20), @TotalRake)
					+ CASE WHEN @PendingAmount > 0 THEN ', PendingAmount = '+ CONVERT(NVARCHAR(30),@PendingAmount) ELSE '' END	
					+ ', Playercomm = ' + CONVERT(NVARCHAR(10),@Player_comm) 
					+ ', IBCComm = ' + CONVERT(NVARCHAR(10),@IBC_comm) 
					+ ', currency = ' + CONVERT(NVARCHAR(10),@currency) 
					+ ', IP = '+ @ip 

BEGIN TRY
	EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData
END TRY
BEGIN CATCH
	-- if write log error: not return error code
END CATCH