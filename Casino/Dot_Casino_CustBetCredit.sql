ALTER PROCEDURE [dbo].[Dot_Casino_CustBetCredit_Cust]
	@custid int
AS
/*
Creator :
Date :
Task : Get member's bet credit for Casino site using
DB: DBTXN/bodb02

History:
    - 20110520@Amy: Re-arrange bettype
    - 20121106@Viet: revise SP
    - 20131108@Elodie: Splitting bodb02 into CustDB (call CustInfo by link database)
    - 20140510@Victor: Amend the SP to include @translogCredit (for Keno product)	
*/
BEGIN
	SET NOCOUNT ON;
	
	Declare @BetCredit money
	Declare @Credit money
	Declare @Balance money
	Declare @OuSTxn money
	Declare @CashBalance money
	Declare @CasinoOutStanding money
	Declare @translogCredit money

	SELECT @Credit = IsNull(Credit,0)
	FROM CustDB.dbo.custinfo with (nolock)
	WHERE custid = @custid
	
	IF @@ROWCOUNT > 0
	BEGIN
	
		select @translogCredit = isnull(sum(isnull(actual_stake,0)) ,0)
		from translog with (nolock) 
		where custid=@custid and statusID=0	

		SELECT 
			@Balance = IsNull(SUM(winlost - actual_stake + playercomm),0),
			@OuSTxn = IsNull(SUM(CASE ruben WHEN 0 THEN actual_stake ELSE 0 END),0),
			@CasinoOutStanding = IsNull(SUM(CASE WHEN ruben = 0 AND bettype = 23002 THEN actual_stake ELSE 0 END),0)
		FROM dbo.bettrans with (nolock)
		WHERE custid = @custid

		SET @BetCredit = @Credit + @Balance - @translogCredit
		SET @CashBalance =  @Balance + @OuSTxn

		--SELECT 
		--	@CasinoOutStanding = IsNull(SUM(actual_stake),0)
		--FROM dbo.bettrans with (nolock)
		--WHERE custid = @custid
		--AND ruben = 0
		--AND bettype = 23002

		SELECT @BetCredit BetCredit, @Credit GivenCredit, @CashBalance CashBalance, @CasinoOutStanding OutStanding
	END
	ELSE
		SELECT 0 BetCredit, 0 GivenCredit, 0 CashBalance, 0 OutStanding
END

GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Casino_CustBetCredit] TO [vnteam]