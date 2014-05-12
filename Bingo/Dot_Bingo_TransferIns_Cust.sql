ALTER PROCEDURE [dbo].[Dot_Bingo_TransferIns_Cust] 
	@custid				int, 	
	@bingoCredit		money OUTPUT,
	@transdesc			nvarchar(300)='',	
	@ip					nvarchar(15)='',
	@refno				bigint = 0	OUTPUT,	
	@sessionId			bigint = 0,
	@ErrCode			int = 0 OUTPUT,
	@ErrMsg				nvarchar(200) = '' OUTPUT
AS
/*
Creator : Jamie
Date : 2010-09-11
Task : Transfer the credit of member to Bingo
DB: DBTRANS/bodb02

Revisions:
	- 20110513@Henry: change bettype to new range
	- 20111026@Sophia: Update balance credit/debit for member
	- 20120412@Sophia: Revise credit/debit balance  
	- 20131108@Elodie: Splitting bodb02 into CustDB (call CustInfo, Exchange by link database)	
	- 20140510@Victor: hot fix, amend the SP to include @translogCredit (for Keno product)
Param's Explanation:

• @bingoCredit:
    + The credit is transfered to bingo and it is always positive 
    + It is both INPUT & OUTPUT param. In case @bingoCredit > @betCredit, then the SP will output @betCredit via @bingoCredit

• @ErrCode:
	= 0: Transaction recorded successfully.
	> 0: Specific Error.
	
• @ErrMsg: Error description.
• @refno: 0-->new log-in session; 
		<>0: refno of a logged-in session(already logged-in and transfer more money to play)

*/

SET NOCOUNT ON

DECLARE	@username		varchar(30),
		@roleid			tinyint,
		@recommend		int, 
		@mrecommend		int, 
		@srecommend		int, 
		@actualrate		float, 
		@winlost		money, 
		@actual_stake	money, 
		@cashBalance	money,
		@betCredit		money,
		@credit			money,
		@currency		tinyint, 
		@currencyName	nvarchar(5), 
		@transdate		datetime, 
		@winlostdate	datetime,
		@translogCredit money

SELECT  @ErrCode = 0, @ErrMsg = '' 

IF @bingoCredit <= 0
BEGIN
	SELECT @ErrMsg = 'Sorry, amount is invalid.', @ErrCode = 101	
	RETURN		
END

SELECT	@roleid = isnull(ci.roleid,0),
		@credit = isnull(ci.credit,0),
		@username = username,
		@recommend = ci.recommend,
		@mrecommend = ci.mrecommend, 
		@srecommend = ci.srecommend,
		@currency = ci.currency, 
		@currencyName = e.currency, 
		@actualrate = e.actualrate
FROM	CustDB.dbo.custinfo ci WITH (NOLOCK) 
		INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) on ci.currency = e.exchangeid
WHERE   ci.custid = @custid 

IF @roleid <> 1
BEGIN
	SELECT @ErrMsg = 'Invalid Role ID.', @ErrCode = 102		
	RETURN
END
if @refno <> 0
begin
--Check if transfer after log-in has the correct refno and sessionid
	if not exists (select 1 from bettrans with (nolock)
				where custid = @custid and bettype = 23201 and ruben = 0 and refno=@refno and betid=@sessionId)
	BEGIN
		SELECT @ErrMsg = 'Invalid refno, this not a valid transfer after log-in!', @ErrCode = 103	
		RETURN
	END
end
else
--check to not allow to create multiple running transfer Transactions
begin
	select @refno = refno from bettrans with (nolock)
				where custid = @custid and bettype = 23201 and ruben = 0
	if @refno <> 0
	BEGIN
		SELECT @ErrMsg = 'There exists an running transfer!', @ErrCode = 106	
		RETURN
	END
end

SELECT	@transdesc = 'Bingo Transfer' + CASE WHEN @transdesc <> '' THEN ' - ' + @transdesc ELSE '' END

SELECT	@winlost =  0, @actual_stake = @bingoCredit 

-----Check enough balance to transfer to bingo----------------------------------------------------
---  betCredit > 0 and  betCredit < bingoCredit --> bingoCredit = betCredit 

SELECT @cashBalance = isnull(sum(winlost-actual_stake+playercomm),0)
FROM bettrans WITH (NOLOCK) WHERE custid = @custid

select @translogCredit = isnull(sum(isnull(actual_stake,0)) ,0)
from translog with (nolock) 
where custid=@custid and statusID=0	


SELECT @betCredit = @cashBalance + @credit - @translogCredit

IF @betCredit < = 0 
BEGIN 
	SELECT @ErrMsg = 'Sorry, you do not have enough money to transfer.', @ErrCode = 104				
	RETURN
END 
ELSE IF @betCredit < @bingoCredit
BEGIN    
    SELECT @actual_stake = @betCredit, @bingoCredit = @betCredit    
END

------------------Insert trans into DB---------------------------------------------------------------
IF @RefNo = 0
BEGIN	
	EXEC dbo.Acc_SelRefNo @RefNo = @RefNo OUTPUT
	SELECT @RefNo = @RefNo + 100000000000	
END

SELECT @transdate = CURRENT_TIMESTAMP, @winlostdate = CONVERT(nvarchar(10), CURRENT_TIMESTAMP, 120)

declare @TransID bigint

---Update debit balance 	
EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @actual_stake 
	
BEGIN
	INSERT INTO bettrans 
		(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, awinlost, winlostdate, 
		 creator, recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount,
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,  
		 currency, actualrate, currencyName, ruben, status,statusID,ip,betid)
	VALUES 
		(@CustID, @username, @RefNo, @transdate, 0, 23201, @transdesc, @winlost, @actual_stake, @actual_stake, 0, @winlostdate, 
		 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, 
		 0, 0, 0, 0,
		 @Currency, @actualrate, @currencyName, 0, 'running',0,@ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 105	
		--rollback balance
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @actual_stake 
		RETURN
	END
		
	SELECT @TransID = @@IDENTITY
END 

---------------------------------------------------------------------------------------------------

DECLARE @LogData nvarchar(300)

SELECT @LogData = 'Bingo Transfer custid = ' + convert(nvarchar(20), @custid) + ', bettype = 23201'  + ', bingoCredit = ' + convert(nvarchar(20), @bingoCredit) 
					 + ', transid:'+ convert(nvarchar(30),@transid) + ', refNo:' + convert(nvarchar(20),@RefNo) +', currency =' + convert(nvarchar(10),@currency) + ', IP=' +@ip 

BEGIN TRY
	EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData
END TRY
BEGIN CATCH
	-- if write log error: not return error code
END CATCH

