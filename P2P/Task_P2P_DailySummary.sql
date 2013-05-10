ALTER PROCEDURE [dbo].[Task_Task_P2P_DailySummary] 	
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
		@currency		tinyint, 
		@currencyName	nvarchar(5), 
		@actualrate		float, 
		@transdate		datetime, 
		@winlostdate	datetime,
		@dummy_custid	int,
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
		@IBCgrosscomm		money,
		@ErrMsg				nvarchar(300),
		@ErrCode			int		
		
SET @winlostdate=CONVERT(VARCHAR(10), GETDATE(),120)
SET @transdate=CONVERT(VARCHAR(10), GETDATE(),120)
		
DECLARE @Currency_Temp TABLE(Currency int,CurrencyName nvarchar(50),actualrate float)

INSERT INTO @Currency_Temp(Currency,CurrencyName,actualrate)
SELECT Exchangeid,Currency,actualrate FROM exchange WITH (nolock)

DECLARE tmp CURSOR FOR SELECT * FROM @Currency_Temp
OPEN tmp
FETCH NEXT FROM tmp INTO @currency, @CurrencyName, @actualrate
WHILE @@FETCH_STATUS = 0
BEGIN

	EXEC dbo.P2P_DailySummary
	@CurrencyName=@CurrencyName,
	@actualrate=@actualrate,
	@currency=@currency	

FETCH NEXT FROM tmp INTO @currency, @CurrencyName, @actualrate
END
CLOSE tmp
DEALLOCATE tmp

GO
GRANT EXECUTE ON [dbo].[Task_P2P_DailySummary] TO [Dot_Member]
GO
GRANT EXECUTE ON [dbo].[Task_P2P_DailySummary] TO [Dot_P2P]
GO
GRANT VIEW DEFINITION ON [dbo].[Task_Task_P2P_DailySummary] TO [VNTeam]
GO