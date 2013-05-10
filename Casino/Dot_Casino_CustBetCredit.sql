 USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Casino_CustBetCredit]    Script Date: 05/20/2011 00:15:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Dot_Casino_CustBetCredit]
	@custid int
AS
/*
Creator :
Date :
Task : Get member's bet credit for Casino site using
DB: DB02.bodb02

History:
    - 20110520@Amy: Re-arrange bettype
*/
BEGIN
	SET NOCOUNT ON;
	
	Declare @BetCredit money
	Declare @Credit money
	Declare @Balance money
	Declare @OuSTxn money
	Declare @CashBalance money
	Declare @CasinoOutStanding money

	SELECT @Credit = IsNull(Credit,0)
	FROM dbo.custinfo with (nolock)
	WHERE custid = @custid AND roleid = 1

	IF @@ROWCOUNT > 0
	BEGIN
		SELECT 
			@Balance = IsNull(SUM(winlost - actual_stake + playercomm),0),
			@OuSTxn = IsNull(SUM(CASE ruben WHEN 0 THEN actual_stake ELSE 0 END),0)
		FROM dbo.bettrans with (nolock, INDEX=IX_custid)
		WHERE custid = @custid

		SET @BetCredit = @Credit + @Balance
		SET @CashBalance =  @Balance + @OuSTxn

		SELECT 
			@CasinoOutStanding = IsNull(SUM(actual_stake),0)
		FROM dbo.bettrans with (nolock, INDEX=IX_custid)
		WHERE custid = @custid
		AND ruben = 0
		AND bettype = 23002

		SELECT @BetCredit BetCredit, @Credit GivenCredit, @CashBalance CashBalance, @CasinoOutStanding OutStanding
	END
	ELSE
		SELECT 0 BetCredit, 0 GivenCredit, 0 CashBalance, 0 OutStanding
END

GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Casino_CustBetCredit] TO [vnteam]