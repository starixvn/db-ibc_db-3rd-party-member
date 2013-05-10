USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_P2P_TransferIns]    Script Date: 10/10/2012 04:01:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Dot_P2P_TransferIns    Script Date: 4/18/2012 3:50:57 PM ******/
/****** Object:  Stored Procedure dbo.Dot_P2P_TransferIns    Script Date: 4/3/2012 5:18:19 PM ******/
/****** Object:  Stored Procedure dbo.Dot_P2P_TransferIns    Script Date: 2/9/2012 3:49:08 PM ******/
ALTER PROCEDURE [dbo].[Dot_P2P_TransferIns] 
	@CustID				INT, 	
	@P2PCredit			MONEY OUTPUT,
	@CurrencyCode		VARCHAR(3)='' OUTPUT,
	@SessionID			NVARCHAR(50) = '',
	@Transdesc			NVARCHAR(300)='',	
	@IP					NVARCHAR(15)='',		
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(200) = '' OUTPUT,
	@TransID			BIGINT OUTPUT
AS
/*
Creator : Amy
Date : 2011-02-10
Task : Transfer the credit of member to P2P
DB: DBTrans.bodb02

Revisions:
	-20111026@Sophia:  Update credit/debit balance
					   Note to modify later: This sp have condition: @betCredit < @P2PCredit then raise error. 
											 Different from [Dot_Casino_TransferIns] with  set @casinoCredit = @betCredit and then continue transfering.
	-20120406@Tim: add @preTransfer to get previous transfers if exists, then use @preTransfer + @P2PCredit to get the amount transfered in P2P
	-20120412@Sophia: Revise credit/debit balance for member	
	-20120821@Tim: allow @betCredit = 0 to do transfer (requiemernt from Jet)
						 
	
	
Param's Explanation:

• @CustID: member custid
• @P2PCredit
    + The credit is transfered to P2P and it is always positive 
    + It is both INPUT & OUTPUT param. In case @P2PCredit > @betCredit, then the SP will output @betCredit via @P2PCredit
• @transdesc: transaction description
• @CurrencyCode: iso code of member's currency
• @sessionId: Member Session ID

• @ErrCode:
	= 0: Transaction recorded successfully.
	> 0: Specific Error.	
	= 104: Transfer credit amount is greater than bet credit.	
• @ErrMsg: Error description.
*/

SET NOCOUNT ON

DECLARE	@username		VARCHAR(30),
		@roleid			TINYINT,
		@recommend		INT, 
		@mrecommend		INT, 
		@srecommend		INT, 
		@actualrate		FLOAT, 
		@winlost		MONEY, 
		@actual_stake	MONEY, 
		@cashBalance	MONEY,
		@P2POutstanding MONEY,
		@betCredit		MONEY,
		@credit			MONEY,
		@currency		TINYINT, 
		@currencyName	NVARCHAR(5), 
		@transdate		DATETIME, 
		@winlostdate	DATETIME,
		@refno			BIGINT,
		@maxtransferamt MONEY,
		@mintransferamt MONEY,
		@todaywinlost MONEY,
		@transferableamt MONEY

DECLARE @BD_SessionID NVARCHAR(50), 
		@IsLogin BIT, 
		@LoginTime DATETIME, 
		@LogoutTime DATETIME,
		@IsAutoDailyReset BIT

DECLARE @balance	   money		

DECLARE @preTransfer	money --Tim: 2012-4-6 total of previous transfers
SELECT @preTransfer = 0

SELECT  @IsLogin=1,	@LoginTime = CURRENT_TIMESTAMP

SELECT  @ErrCode = 0, @ErrMsg = '' 

IF @P2PCredit < 0
BEGIN
	SELECT @ErrMsg = 'Sorry, amount is invalid.', @ErrCode = 101	
	RETURN
END

SELECT	@roleid = ISNULL(ci.roleid,0),
		@credit = ISNULL(ci.credit,0),
		@username = username,
		@recommend = ci.recommend,
		@mrecommend = ci.mrecommend, 
		@srecommend = ci.srecommend,
		@currency = ci.currency, 
		@currencyName = e.currency, 
		@actualrate = e.actualrate,
		@CurrencyCode = e.code,
		@maxtransferamt = ISNULL(MaxTransferP2P,0),	
		@IsAutoDailyReset = ISNULL(IsAutoResetP2P,0),
		@mintransferamt = dp.MinCredit 	
FROM	custInfo ci WITH (NOLOCK) 
		INNER JOIN exchange e WITH (NOLOCK) ON ci.currency = e.exchangeid
		INNER JOIN P2PDefaultSetting dp WITH (NOLOCK) ON dp.currency = ci.currency
WHERE   ci.custid = @custid 

IF @roleid <> 1
BEGIN
	SELECT @ErrMsg = 'Invalid Role ID.', @ErrCode = 102	
	RETURN
END

IF (@P2PCredit > @maxtransferamt OR @P2PCredit < @mintransferamt)
BEGIN
	SELECT @ErrMsg = 'Out of range transfer credit', @ErrCode = 103
	RETURN
END

SELECT @refno=refno,@BD_SessionID=betcheck FROM bettrans WITH (NOLOCK)
				WHERE custId = @custid AND bettype = 23101 AND ruben = 0

IF @BD_SessionID = @SessionID -- transfer more money to play game
BEGIN	

	SET @IsLogin=0	
	-- Update running transfer as Completed and WinLost = Actual_stake		
	SELECT  @balance = sum(winlost - actual_stake), 
			@preTransfer = sum(actual_stake)
	FROM	bettrans WITH (NOLOCK)
	WHERE custId=@custid AND betcheck = @sessionId AND bettype = 23101 AND ruben=0 AND matchid = 0	
	
	---update debit balance
	IF @balance > 0
	BEGIN
		EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance
	END

	UPDATE bettrans WITH (ROWLOCK, UPDLOCK)
    SET status = 'Completed',statusID=131, ruben = 1, winlost = actual_stake
	WHERE custId=@custid AND betcheck = @sessionId AND bettype = 23101 AND ruben=0 AND matchid = 0	
		
	---update credit balance
	IF @balance < 0
	BEGIN
		SELECT @balance = ABS(@balance)
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
	END	
	
END
ELSE IF @BD_SessionID IS NOT NULL AND @BD_SessionID <> @SessionID -- transfer at the first login
--check to not allow to create multiple running transfer Transactions
BEGIN	
	SELECT @ErrMsg = 'Running transfer exists!', @ErrCode = 104	
	RETURN	
END

SELECT	@transdesc = 'P2P Transfer' + CASE WHEN @transdesc <> '' THEN ' - ' + @transdesc ELSE '' END

SELECT	@winlost =  0, @actual_stake = @P2PCredit + @preTransfer

-----Check enough balance to transfer to P2P----------------------------------------------------
---  betCredit > 0 and  betCredit < @P2PCredit --> @P2PCredit = betCredit 

SELECT @cashBalance = ISNULL(SUM(winlost-actual_stake+playercomm),0)
FROM bettrans WITH (NOLOCK) 
WHERE custId = @custid

SELECT @betCredit = @cashBalance + @credit 

IF @betCredit < 0 OR @betCredit < @P2PCredit
BEGIN 
	SELECT @ErrMsg = 'Sorry, you do not have enough money to transfer.', @ErrCode = 105				
	RETURN
END 

------------------Insert trans into DB---------------------------------------------------------------
IF @RefNo IS NULL
BEGIN	
	EXEC dbo.Acc_SelRefNo @RefNo = @RefNo OUTPUT
	SELECT @RefNo = @RefNo + 100000000000	
END

SELECT @transdate = CURRENT_TIMESTAMP, @winlostdate = CONVERT(NVARCHAR(10), CURRENT_TIMESTAMP, 120)


BEGIN
	---update balance
	EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @actual_stake 
	
	INSERT INTO bettrans 
		(custId, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, awinlost, winlostdate, 
		 creator, recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount,
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,  
		 currency, actualrate, CurrencyName, ruben, status,statusID,ip,betcheck)
	VALUES 
		(@CustID, @username, @RefNo, @transdate, 0, 23101, @transdesc, @winlost, @actual_stake, @actual_stake, 0, @winlostdate, 
		 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, 
		 0, 0, 0, 0,
		 @Currency, @actualrate, @currencyName, 0, 'running',0,@ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 106	
		---revert balance
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @actual_stake 
		RETURN
	END	
	
	
	SELECT @TransID = @@IDENTITY
END 

---------------------------------------------------------------------------------------------------
DECLARE @LogData NVARCHAR(300)

SELECT @LogData = 'P2P Transfer custid = ' + CONVERT(NVARCHAR(20), @custid) 
			+ ', bettype = 23101'  
			+ ', P2PCredit = ' + CONVERT(NVARCHAR(20), @P2PCredit)
			+ ', @actual_stake = ' + CONVERT(NVARCHAR(20), @actual_stake)
			+ ', SessionID:'+ CONVERT(NVARCHAR(30),@SessionID) 
			+ ', refNo:' + CONVERT(NVARCHAR(20),@RefNo) 
			+ ', currency =' + CONVERT(NVARCHAR(10),@currency) 
			+ ', IP=' +@ip 
			+ ', Transid=' + cast(isnull( @TransID,0) as nvarchar(20)) 
BEGIN TRY
	EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData
END TRY
BEGIN CATCH
	-- if write log error: not return error code
END CATCH