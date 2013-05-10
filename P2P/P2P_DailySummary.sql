ALTER PROCEDURE [dbo].[P2P_DailySummary] 	
	@currency		tinyint,
	@CurrencyName	nvarchar(5),
	@actualrate		float,
	@ErrCode		int=0 output,
	@ErrMsg			nvarchar(300)='' output

AS
/*
Creator : Amy
Date : 2011-02-10
Task : Insert dummy transaction calculated base on bet ticket at the end of the day
DB: DB02.bodb02

Revisions:

Param's Explanation:

*/

SET NOCOUNT ON

DECLARE	@username		varchar(30),				
		@transdate		datetime, 
		@winlostdate	datetime,
		@dummy_custid	int,
		@dummyCommInc_custid	int,
		@dummyCommExp_custid	int,
		@dummyCommGross_custid	int,
		@dummy_username		nvarchar(15),		
		@dummy_recommend	int,
		@dummy_mrecommend	int,
		@dummy_srecommend	int,
		@actual_stake		money,
		@scomm				money,
		@winlost			money,
		@playercomm			money,
		@mcomm				money,
		@acomm				money,
		@IBCgrosscomm		money		
		
SET @winlostdate=CONVERT(VARCHAR(10), GETDATE(),120)
SET @transdate=CONVERT(VARCHAR(10), GETDATE(),120)
		
SET @dummy_custid = NULL
SELECT	@dummy_custid = c.custid,
	@dummy_username = c.username,
	@dummy_recommend = c.recommend,
	@dummy_mrecommend = c.mrecommend,
	@dummy_srecommend = c.srecommend
FROM	custinfo c WITH (NOLOCK) 
WHERE	c.username = 'P2PBet' + @currencyName AND c.roleid = 1 

IF isnull(@dummy_custid, 0) = 0
BEGIN
	SELECT @ErrMsg = 'Invalid Dummy account or Account is not existed!', @ErrCode = 106		
	RETURN
END

--
IF EXISTS (SELECT 1 FROM bettrans WITH(nolock) 
				WHERE custid=@dummy_custid AND currency=@currency AND bettype=1000 AND 
					ruben=1 AND winlostdate=@winlostdate)
BEGIN
	SELECT @ErrMsg = 'This currency dummy transaction was existed!', @ErrCode = 106		
	RETURN
END
-- check there is any P2P bet ticket of this currency
IF NOT EXISTS (SELECT 1 FROM bettrans WITH(nolock) 
				WHERE currency=@currency AND bettype=1000 AND 
					ruben=1 AND winlostdate=@winlostdate)
BEGIN
	RETURN 
END

-- sum all transaction by currency and bettype
SELECT @actual_stake=SUM(ISNULL(actual_stake,0)),
	@winlost=SUM(ISNULL(winlost,0)),
	@playercomm=SUM(ISNULL(playercomm,0)),
	@acomm=SUM(ISNULL(comm,0)),
	@mcomm=SUM(ISNULL(acomm,0)),
	@scomm=SUM(ISNULL(scomm,0)),
	@IBCgrosscomm=SUM(ISNULL(oddsspread,0))
FROM bettrans WITH (nolock)
WHERE bettype=1000 AND 	
	ruben=1 AND 
	currency=@currency AND
	winlostdate=@winlostdate

-- Insert into bettrans SUM record for Dummy bet ticket
INSERT INTO bettrans 
	(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
	 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
	 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
	 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,
	 currency, actualrate, currencyName, ruben, status,statusID,ip,betcheck)
VALUES 
	(@dummy_custID, @dummy_username, 0, @transdate, 0, 1000, '', @actual_stake, @winlost,@winlost,
	 0,0,0, -@playercomm, -@acomm, -@mcomm, -@scomm, @winlostdate, @dummy_custID, 
	 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 
	 0, 0, 0, 0, @Currency, @actualrate, @currencyName, 1, 'DONE',121, '',0)


-- Insert into bettrans SUM record for Dummy CommIncP2P
SET @dummy_custid = NULL
SELECT	@dummyCommInc_custid = c.custid,
	@dummy_username = c.username,
	@dummy_recommend = c.recommend,
	@dummy_mrecommend = c.mrecommend,
	@dummy_srecommend = c.srecommend
FROM	custinfo c WITH (NOLOCK) 
WHERE	c.username = 'CommIncP2P' + @currencyName AND c.roleid = 1 

IF isnull(@dummyCommInc_custid, 0) = 0
BEGIN
	SELECT @ErrMsg = 'Invalid Dummy account is not existed!', @ErrCode = 106		
	RETURN
END
-------------------------------------------------------
INSERT INTO bettrans 
	(custid, username, refno, transdate, matchid, bettype, transdesc, winlost,  stake, actual_stake, 
	 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
	 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
	 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,
	 currency, actualrate, currencyName, ruben, status,statusID,ip,betcheck)
VALUES 
	(@dummyCommInc_custid, @dummy_username, 0, @transdate, 0, 1000, '', @scomm, @IBCgrosscomm,@IBCgrosscomm,
	 0,0,0, 0, 0, 0,0, @winlostdate, @dummyCommInc_custid, 
	 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 
	 0, 0, 0, 0, @Currency, @actualrate, @currencyName, 1, 'DONE',121, '',0)
	 
-- Insert into bettrans SUM record for Dummy CommExpP2P
SET @dummy_custid = NULL
SELECT	@dummyCommExp_custid = c.custid,
	@dummy_username = c.username,
	@dummy_recommend = c.recommend,
	@dummy_mrecommend = c.mrecommend,
	@dummy_srecommend = c.srecommend
FROM	custinfo c WITH (NOLOCK) 
WHERE	c.username = 'CommExpP2P' + @currencyName AND c.roleid = 1 

IF isnull(@dummyCommExp_custid, 0) = 0
BEGIN
	SELECT @ErrMsg = 'Invalid Dummy account is not existed!', @ErrCode = 106		
	RETURN
END
-------------------------------------------------------
INSERT INTO bettrans 
	(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
	 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
	 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
	 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,
	 currency, actualrate, currencyName, ruben, status,statusID,ip,betcheck)
VALUES 
	(@dummyCommExp_custid, @dummy_username, 0, @transdate, 0, 1000, '', 0, @scomm,@scomm,
	 0,0,0, 0, 0, 0,0, @winlostdate, @dummyCommExp_custid, 
	 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 
	 0, 0, 0, 0, @Currency, @actualrate, @currencyName, 1, 'DONE',121, '',0)
	 
-- Insert into bettrans SUM record for Dummy CommGrossP2P
SET @dummy_custid = NULL
SELECT	@dummyCommGross_custid = c.custid,
	@dummy_username = c.username,
	@dummy_recommend = c.recommend,
	@dummy_mrecommend = c.mrecommend,
	@dummy_srecommend = c.srecommend
FROM	custinfo c WITH (NOLOCK) 
WHERE	c.username = 'CommGrossP2P' + @currencyName AND c.roleid = 1 

IF isnull(@dummyCommGross_custid, 0) = 0
BEGIN
	SELECT @ErrMsg = 'Invalid Dummy account is not existed!', @ErrCode = 106		
	RETURN
END
-------------------------------------------------------
INSERT INTO bettrans 
	(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
	 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
	 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
	 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,
	 currency, actualrate, currencyName, ruben, status,statusID,ip,betcheck)
VALUES 
	(@dummyCommGross_custid, @dummy_username, 0, @transdate, 0, 1000, '', @IBCgrosscomm, 0,0,
	 0,0,0, 0, 0, 0,0, @winlostdate, @dummyCommGross_custid, 
	 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 
	 0, 0, 0, 0, @Currency, @actualrate, @currencyName, 1, 'DONE',121, '',0)
	 

IF @@ERROR <> 0
BEGIN			
	SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107	
	RETURN
END
GO
GRANT EXECUTE ON [dbo].[P2P_DailySummary] TO [Dot_Member]
GO
GRANT EXECUTE ON [dbo].[P2P_DailySummary] TO [Dot_P2P]
GO
GRANT VIEW DEFINITION ON [dbo].[P2P_DailySummary] TO [VNTeam]
GO