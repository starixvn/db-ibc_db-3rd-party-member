USE [CasinoAdmin]
GO
/****** Object:  StoredProcedure [dbo].[TP_User_Customer_Sel]    Script Date: 5/19/2014 3:23:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TP_User_Customer_Sel]
	@CustID		int = null,		--Input TABLE's field
	@IBCCustID	int = null,
	@UserName	nvarchar(30) = null,
	@ErrCode	varchar(5)	= '' OUTPUT,	--Return ErrCode
	@ErrMsg		nvarchar(500)= '' OUTPUT	--Return Exception Message
AS

SET NOCOUNT ON

IF rtrim(@CustID) = ''			SET @CustID = NULL
IF rtrim(@IBCCustID) = ''		SET @IBCCustID = NULL
IF rtrim(@UserName) = ''		SET @UserName = NULL

BEGIN TRY

	--Get data 
	IF @CustID is not null

		SELECT	CustID, UserName, UserPwd, UserName2, SAgentID, MAgentID, AgentID, CasinoID, LangID, RoleId, ExchangeID, MaxBalance, Balance, ActualBalance, OutstandingBalance, LoginFailTimes, IBCCustID, IsClosed, IsFrozen, EnableCasino, IsInternal, Status, CreateTime 
		FROM	Customer with (NOLOCK) 
		WHERE	CustID = @CustID

	ELSE IF @IBCCustID is not null

		SELECT	CustID, UserName, UserPwd, UserName2, SAgentID, MAgentID, AgentID, CasinoID, LangID, RoleId, ExchangeID, MaxBalance, Balance, ActualBalance, OutstandingBalance, LoginFailTimes, IBCCustID, IsClosed, IsFrozen, EnableCasino, IsInternal, Status, CreateTime 
		FROM	Customer with (NOLOCK) 
		WHERE	IBCCustID = @IBCCustID

	ELSE IF @UserName is not null

		SELECT	CustID, UserName, UserPwd, UserName2, SAgentID, MAgentID, AgentID, CasinoID, LangID, RoleId, ExchangeID, MaxBalance, Balance, ActualBalance, OutstandingBalance, LoginFailTimes, IBCCustID, IsClosed, IsFrozen, EnableCasino, IsInternal, Status, CreateTime 
		FROM	Customer with (NOLOCK) 
		WHERE	UserName = @UserName

END TRY

BEGIN CATCH
	SELECT @ErrCode = 'E0004'
	SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)
END CATCH


