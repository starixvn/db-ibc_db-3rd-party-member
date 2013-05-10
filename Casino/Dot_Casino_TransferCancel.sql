ALTER PROCEDURE [dbo].[Dot_Casino_TransferCancel] 
	@custid				int, 	
	@ip					nvarchar(15)='',
	@refno				bigint,	
	@casinoCredit		money OUTPUT,
	@transdesc			nvarchar(300)='',				
	@ErrCode			int = 0 OUTPUT,
	@ErrMsg				nvarchar(200) = '' OUTPUT
AS
/*
Creator : Phuong Doan
Date : 2009-03-10
Task : Cancel orphan transfer ticket
DB: DBTRANS.bodb02

History:
    - 20100310@Thien: remove CustBetCreditUpdResync
    - 20100508@Henry: insert data to column statusID
	- 20100908@Vivi: add try catch for wirte userlog
	- 20110513@Henry: change bettype to new range
	- 20111028@Sophia: Update balance 
Param's Explanation:

• @ErrCode:
	= 0: Transaction recorded successfully.
	> 0: Specific Error.
	
• @ErrMsg: Error description.
• @refno: orphan ticket's refno
• @casinoCredit: orphan credit amount

*/

SET NOCOUNT ON

DECLARE	@username		varchar(30),
		@recommend		int, 
		@mrecommend		int, 
		@srecommend		int, 
		@actualrate		float,
		@currency		tinyint, 
		@currencyName	nvarchar(5), 
		@transdate		datetime, 
		@winlostdate	datetime

SELECT @transdate = CURRENT_TIMESTAMP, @winlostdate = CONVERT(nvarchar(10), CURRENT_TIMESTAMP, 120)

SELECT  @ErrCode = 0, @ErrMsg = '' , @casinoCredit = 0

SELECT	@transdesc = 'Casino Cancel Transfer' + CASE WHEN @transdesc <> '' THEN ' - ' + @transdesc ELSE '' END

--check if there's a running transfer ticket
SELECT	@casinoCredit = actual_stake, 
	@actualrate = actualrate, 
	@currency = currency, 
	@currencyName = currencyName,
	@recommend = recommend,
	@mrecommend = mrecommend,
	@srecommend = srecommend,
	@username = username
from bettrans(nolock) where refno=@refno and custid=@custid

if @casinoCredit = 0
begin
	SELECT @ErrMsg = 'Invalid Refno.', @ErrCode = 101		
	RETURN
end
--update the running ticket to completed
update bettrans set status ='completed',statusID=131,ruben = 1 where refno=@refno and custid=@custid 

IF @@ERROR <> 0
BEGIN			
	SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 102	
	RETURN
END

--Insert a new transfer transaction to balance the previous one
INSERT INTO bettrans 
	(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, actual_stake, awinlost, winlostdate, 
	 creator, recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount,
	 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,  
	 currency, actualrate, currencyName, ruben, status,statusID,ip)
VALUES 
	(@CustID, @username, @refno, @transdate, 0, 23001, @transdesc, @casinoCredit, 0, 0, @winlostdate, 
	 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, 
	 0, 0, 0, 0,
	 @Currency, @actualrate, @currencyName, 1, 'completed',131,@ip)

IF @@ERROR <> 0
BEGIN			
	update bettrans set status ='running',statusID=0,ruben = 0 where refno=@refno and custid=@custid 
	SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 103	
	RETURN
END

--update balance 
EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @casinoCredit

	
---------------------------------------------------------------------------------------------------

DECLARE @LogData nvarchar(300)

SELECT @LogData = 'Casino Cancel Transfer custid = ' + convert(nvarchar(20), @custid) + ', bettype = 23001'  
					+ ', casinoCredit = ' + convert(nvarchar(20), @casinoCredit) 
					+ ', refNo:' + convert(nvarchar(20),@RefNo) + ', IP=' +@ip 

BEGIN TRY
	EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData
END TRY
BEGIN CATCH
	-- if write log error: not return error code
END CATCH

GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Casino_TransferCancel] TO [vnteam]
GO
GRANT  EXECUTE  ON [dbo].[Dot_Casino_TransferCancel]  TO [Dot_Casino]
GO
GRANT  EXECUTE  ON [dbo].[Dot_Casino_TransferCancel]  TO [Dot_Member]
GO