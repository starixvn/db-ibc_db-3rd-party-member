set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[TP_User_Customer_AutoInsertAccount]
	@CustID			int = null ,
	@CasinoNo		varchar(10) = null,		--Input TABLE''s field
	@ExchangeID		int = null,
	@SCustID		int = null,		--Input TABLE''s field
	@MCustID		int = null,		--Input TABLE''s field
	@ACustID		int = null,		--Input TABLE''s field
	@RoleID			tinyint = null,
	@SignupIP		varchar(15) = null,
	@SignupBy		int = null,
	@SignupFrom		tinyint = null,
	@ModifyUserName nvarchar(50) = null,
	@UserName		nvarchar(50) = null,
	@ErrCode		varchar(5)		= Null OUTPUT,	--Return ErrCode
	@ErrMsg			nvarchar(500)	= Null OUTPUT		--Return Exception Message
AS
/*
Purpose:	Insert Cust Profile and Setting
Used By:	Agent Integration,Customer.cs
Used By:
Add By:		Karen,2011/11/22
			Insert CustSetting/CustFinance/CustGameType
*/
SET NOCOUNT ON

DECLARE @Now			DateTime
DECLARE @CanUseChat		bit
DECLARE @IsEnablePT		bit	
DECLARE @IsInternal		bit
DECLARE @UplineCustID	int
DECLARE @GameTypeID		int
DECLARE @GameGroupID		int
DECLARE @GameEnablePlay int
DECLARE @UplineStakeLevelList varchar(100)
DECLARE @MemberNewStakeLevelList varchar(10)
DECLARE @CasinoID		int

SET @Now = GetDate()

BEGIN TRY

	--Check data
	IF @CustID is null
	BEGIN
		SET @ErrCode = 'E0001'
		SET @ErrMsg = 'CustID is null'
		RETURN
	END
	
	IF @CasinoNo is null
	BEGIN
		SET @ErrCode = 'E0002'
		SET @ErrMsg = 'CasinoNo is null'
		RETURN
	END
	
	SELECT	@CasinoID = CasinoID
	FROM	Casino with(nolock)
	WHERE	CasinoNo = @CasinoNo
	IF @@ROWCOUNT = 0
	BEGIN
		--Return Data
		SELECT @ErrCode = 'E0003'
		SET @ErrMsg = 'No data in Casino for CasinoNo=' + CONVERT(varchar(20),@CasinoNo)
		RETURN
	END	
		
	IF @ExchangeID is null
	BEGIN
		SET @ErrCode = 'E0004'
		SET @ErrMsg = 'ExchageID is null'
		RETURN
	END	

	IF @SignupBy is null
	BEGIN
		SET @ErrCode = 'E0005'
		SET @ErrMsg = 'SignupBy is null'
		RETURN
	END

	IF @SignupFrom is null
	BEGIN
		SET @ErrCode = 'E0006'
		SET @ErrMsg = 'SignupFrom is null'
		RETURN
	END
	
	IF @RoleID is null
	BEGIN
		SET @ErrCode = 'E0007'
		SET @ErrMsg = 'RoleID is null'
		RETURN
	END
		
	IF @RoleID = 1 OR @RoleID = 2 OR @RoleID = 3
	BEGIN
		IF @SCustID is null
		BEGIN
			SET @ErrCode = 'E0008'
			SET @ErrMsg = 'SCustID is null'
			RETURN
		END
	END	
	
	IF @RoleID = 1 OR @RoleID = 2
	BEGIN
		IF @MCustID is null
		BEGIN
			SET @ErrCode = 'E0009'
			SET @ErrMsg = 'MCustID is null'
			RETURN
		END
	END	
	
	IF @RoleID = 1 
	BEGIN
		IF @ACustID is null
		BEGIN
			SET @ErrCode = 'E0010'
			SET @ErrMsg = 'ACustID is null'
			RETURN
		END
	END	
			
	SET @CanUseChat = 0
	SET @IsEnablePT = 0
	
	IF @ExchangeID = 20 
		SET @IsInternal = 1 
	ELSE 
		SET @IsInternal = 0 
	
	--check if exist
	/*SELECT CustID FROM Customer with (NOLOCK) WHERE IBCCustID = @IBCCustID
	IF @@ROWCOUNT > 0
	BEGIN
		--Return Data
		SELECT @ErrCode = 'E0001'
		SET @ErrMsg = 'IBCCustID already exist in Customer'
		RETURN
	END*/

	--if not super,get upline's setting data 
	IF (@RoleID = 3)
	BEGIN
		SELECT	@IsInternal = IsInternal 
		FROM	dbo.CustSetting with (NOLOCK) WHERE CustSettingID = @SCustID
		SET @UplineCustID = @SCustID
	END
	ELSE IF (@RoleID = 2)
	BEGIN
		SELECT	@IsInternal = IsInternal 
		FROM	dbo.CustSetting with (NOLOCK) WHERE CustSettingID = @MCustID
		SET @UplineCustID = @MCustID
	END
	ELSE IF (@RoleID = 1)
	BEGIN
		SELECT	@IsInternal = IsInternal 
		FROM	dbo.CustSetting with (NOLOCK) WHERE CustSettingID = @ACustID
		SET @UplineCustID = @ACustID
	END

	--Insert CustSetting data
	INSERT INTO CustSetting(CustSettingID, CanUseChat,IsEnablePT,IsInternal)
		VALUES (@CustID, @CanUseChat, @IsEnablePT, @IsInternal)

	--Insert CustFinance
	INSERT INTO CustFinance(CustFinanceID) VALUES (@CustID)

	IF @SignupFrom = 2
		SET @ModifyUserName = 'Agent[' + @ModifyUserName + ']'
	ELSE
		SET @ModifyUserName = 'House[' + @ModifyUserName + ']'
	
	--Insert ActionLog
	INSERT INTO ActionLog (CasinoID, FromID, FromRoleID, FromUserName, ToID, ToUserName, ActionTime, TableName,
				KeyID, OldData, NewData, ExtraInfo, FromIP)
		 VALUES(@CasinoID, @SignupBy, @SignupFrom, @ModifyUserName, @CustID, @UserName, @Now, 'CustSetting',
				@CustID, null, null, 'New account created (By Auto Enable)', @SignupIP)

	--Get upline's Betting Limit and Insert Into CustGameType	
	IF @RoleID = 1
	BEGIN	
	
		IF OBJECT_ID('tempdb..#temp_GameType') IS NOT NULL DROP TABLE #temp_GameType
		SELECT	GameTypeID 
		INTO	#temp_GameType 
		FROM	GameType
		
		WHILE (1=1)
		BEGIN
			SELECT TOP 1 @GameTypeID = GameTypeID FROM #temp_GameType with(nolock)
			IF (@@ROWCOUNT = 0) BREAK
	
			SET @UplineStakeLevelList = ''
			SET @MemberNewStakeLevelList = ''
	
			SELECT	@UplineStakeLevelList = StakeLevelList, @GameGroupID = GameGroupID, @GameEnablePlay = GameEnablePlay
			FROM	CustGameType (NOLOCK) 
			WHERE	CustID = @UplineCustID
					AND GameTypeID = @GameTypeID
	
			SELECT	top 1 @MemberNewStakeLevelList = CONVERT(VARCHAR(10),StakeLevelID) 
			FROM	StakeLevel with(nolock)
			WHERE	CHARINDEX('''' + convert(varchar(5),StakeLevelID) + '''','''' + replace(@UplineStakeLevelList,',',''',''') + '''') > 0
					AND MinStake <> 0
					AND MaxStake <> 0
			ORDER BY MinStake, MaxStake	
		
			INSERT INTO CustGameType(GameGroupID,GameTypeID,CustID,StakeLevelList,GameEnablePlay)
				VALUES(@GameGroupID, @GameTypeID, @CustID, @MemberNewStakeLevelList, @GameEnablePlay)
							
			Delete From #temp_GameType WHERE GameTypeID = @GameTypeID

		END
		IF OBJECT_ID('tempdb..#temp_GameType') IS NOT NULL DROP TABLE #temp_GameType

	END
	ELSE
	BEGIN
		INSERT INTO CustGameType(GameGroupID,GameTypeID,CustID,StakeLevelList,GameEnablePlay)
			SELECT	CGKA.GameGroupID, CGKA.GameTypeID, @CustID, CGKA.StakeLevelList ,CGKA.GameEnablePlay
			FROM	(SELECT CustID, GameGroupID, GameTypeID, StakeLevelList,GameEnablePlay 
						FROM CustGameType (NOLOCK) WHERE CustID = @UplineCustID) CGKA
	END	

	INSERT INTO ActionLog  (CasinoID, FromID, FromRoleID, FromUserName, ToID, ToRoleID, ToUserName, ActionTime, TableName,
			KeyID, NewData, ExtraInfo, FromIP)
			SELECT	@CasinoID, @SignupBy, @SignupFrom, @ModifyUserName, CustID, 2, @UserName, @Now, 'CustGameType',
					CGT.GameTypeID,dbo.GetStakeLevelList(StakeLevelList),GameTypeName + ' - Betting Limit(By Auto Enable)',@SignupIP
			FROM	CustGameType (nolock) CGT, GameType (nolock) GT
			WHERE	CGT.GameTypeID = GT.GameTypeID
					AND CustID = @CustID

	--If all process successfully, then update IsEnablePT = true
	IF (@ErrCode is null and @ErrMsg is null) or (ISNULL(@ErrCode,'') <> '' AND ISNULL(@ErrMsg,'')<>'')
	BEGIN
		UPDATE	CustSetting with(rowlock)
		SET		IsEnablePT = 1 
		WHERE	CustSettingID = @CustID
	END

	EXEC TP_Admin_StakeLevel_GetCustStakeLevel @CustID

END TRY

BEGIN CATCH

	SELECT @ErrCode = 'E0099'
	SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)

END CATCH

