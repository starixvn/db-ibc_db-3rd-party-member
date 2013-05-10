 set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[TP_User_Customer_AutoInsertAccountFromExisting]
    @CustID            int = null,        		--Input TABLE''s field
    @OldCustID         int = null,        		--Input TABLE''s field
    @CasinoNo          varchar(10) = null,		--Input TABLE''s field
    @SignupIP          varchar(15) = null,  	--Input TABLE''s field
    @SignupBy          int = null,        		--Input TABLE''s field
    @SignupFrom        tinyint = null,      	--Input TABLE''s field
    @ModifyUserName    nvarchar(50) = null,     --Input TABLE''s field
    @ToUserName        nvarchar(50) = null,     --Input TABLE''s field
    @ErrCode           varchar(5)       = Null OUTPUT,    --Return ErrCode
    @ErrMsg            nvarchar(500)    = Null OUTPUT        --Return Exception Message
AS
/*
Purpose:    Insert Cust Profile and Setting
Used By:    Agent Integration,Customer.cs
Used By:
Add By:		Karen,2012/1/17
            Insert CustSetting/CustFinance
*/
SET NOCOUNT ON

DECLARE @Now            DateTime
DECLARE @CasinoID		int
SET @Now = GetDate()

BEGIN TRY

	IF @CustID is null
	BEGIN
		SET @ErrCode = 'E0001'
		SET @ErrMsg = 'CustID is null'
		RETURN
	END

	IF @OldCustID is null
	BEGIN
		SET @ErrCode = 'E0002'
		SET @ErrMsg = 'OldCustID is null'
		RETURN
	END
	
	IF @CasinoNo is null
	BEGIN
		SET @ErrCode = 'E0003'
		SET @ErrMsg = 'CasinoNo is null'
		RETURN
	END
	
	SELECT	@CasinoID = CasinoID
	FROM	Casino with(nolock)
	WHERE	CasinoNo = @CasinoNo
	IF @@ROWCOUNT = 0
	BEGIN
		--Return Data
		SELECT @ErrCode = 'E0004'
		SET @ErrMsg = 'No data in Casino for CasinoNo=' + CONVERT(varchar(20),@CasinoNo)
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
	
	IF @ModifyUserName is null
	BEGIN
		SET @ErrCode = 'E0007'
		SET @ErrMsg = 'ModifyUserName is null'
		RETURN
	END
	
	IF @ToUserName is null
	BEGIN
		SET @ErrCode = 'E0008'
		SET @ErrMsg = 'ToUserName is null'
		RETURN
	END
	
    --Insert CustSetting data
    INSERT INTO CustSetting(CustSettingID,IsEnablePT,CanUseChat,SpeedSetting,MusicID,IsMusic,ConnectTimeout,IsDealerVoice,
					IsStreaming,Volume,BGMusicType,IsInternal,CasinoID,SiteID)
        SELECT @CustID, IsEnablePT,CanUseChat,SpeedSetting,MusicID,IsMusic,ConnectTimeout,IsDealerVoice,
					IsStreaming,Volume,BGMusicType,IsInternal,CasinoID,SiteID
		FROM CustSetting WITH (NOLOCK) WHERE CustSettingID = @OldCustID

    --Insert CustFinance
    INSERT INTO CustFinance(CustFinanceID) VALUES (@CustID)

    --Insert ActionLog
    INSERT INTO ActionLog (CasinoID,FromID,FromRoleID,FromUserName,ToID,ToRoleID,ToUserName,ActionTime,
					TableName,KeyID,OldData,NewData,ExtraInfo,FromIP)
         VALUES(@CasinoID, @SignupBy, @SignupFrom, @ModifyUserName, @CustID,2,@ToUserName, @Now, 'Customer',
                @CustID, @OldCustID, null, 'New account copied from old data', @SignupIP)

    --Delete CustGameType first
    DELETE FROM CustGameType WITH (ROWLOCK) WHERE CustID = @CustID

    --Copy old and Insert Into CustGameType    
	INSERT INTO CustGameType(GameGroupID,GameTypeID,CustID,StakeLevelList,GameEnablePlay,GameRequestBy,
					IsGameRequestLock,GameModifyBy)
		SELECT GameGroupID, GameTypeID, @CustID, StakeLevelList,GameEnablePlay,GameRequestBy,IsGameRequestLock,
				GameModifyBy
		FROM CustGameType (NOLOCK)
		WHERE CustID = @OldCustID

    INSERT INTO ActionLog  (CasinoID,FromID,FromRoleID,FromUserName,ToID,ToRoleID,ToUserName,ActionTime,
					TableName,KeyID,OldData,NewData,ExtraInfo,FromIP)
            SELECT    @CasinoID, @SignupBy, @SignupFrom, @ModifyUserName, CustID,2, @ToUserName, @Now, 'CustGameType',
                    CGT.GameTypeID,null,dbo.GetStakeLevelList(StakeLevelList),GameTypeName + ' - Betting Limit(copied from OldData)',@SignupIP
            FROM    CustGameType (nolock) CGT, GameType (nolock) GT
            WHERE    CGT.GameTypeID = GT.GameTypeID
                    AND CustID = @CustID

	EXEC TP_Admin_StakeLevel_GetCustStakeLevel @CustID

END TRY

BEGIN CATCH

    SELECT @ErrCode = 'E0004'
    SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)

END CATCH

