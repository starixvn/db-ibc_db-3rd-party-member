 set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[TP_Admin_StakeLevel_GetCustStakeLevel]
    @CustID			int = NULL,
	@ErrCode		varchar(5)	= '' OUTPUT,	--Return ErrCode
	@ErrMsg			nvarchar(500)= '' OUTPUT	--Return Exception Message
AS
/*
Purpose:	Get Cust StakeLevel
Used By:	Agent Site call SP directly
Used By:	TP_User_Customer_AutoInsertAccount, TP_User_Customer_AutoInsertAccountFromExisting
Add By:		Karen,2012/2/9
			purpose,change where
*/
SET NOCOUNT ON

DECLARE @Self_StakeLevelList varchar(100)
DECLARE @Super_StakeLevelList varchar(100)
DECLARE @RoleID int
DECLARE @SCustID int
DECLARE @ExchangeID int
DECLARE @SAgentID int
DECLARE @MAgentID int
DECLARE @AgentID int
DECLARE @GameTypeID int
DECLARE @GameTypeName_En nvarchar(50) 
DECLARE @GameTypeName_Ct nvarchar(50) 
DECLARE @GameTypeName_Cs nvarchar(50) 
DECLARE @GameTypeName_Jp nvarchar(50) 
DECLARE @GameTypeName_It nvarchar(50) 
DECLARE @GameTypeName_Th nvarchar(50) 
DECLARE @GameTypeName_Ko nvarchar(50) 
DECLARE @IBCBetTypeID int
DECLARE @CasinoID int

IF rtrim(@CustID) = ''			SET @CustID = NULL
IF rtrim(@GameTypeID) = ''		SET @GameTypeID = NULL


DECLARE @temp_custgametype TABLE	(	
									GameTypeID int , 
									IBCBetTypeID int,
									StakeLevelName varchar(100)
									)
										
BEGIN TRY

	--Get Customer's data
	IF @CustID is null
	BEGIN
		SET @ErrCode = 'E0002'
		SET @ErrMsg = 'CustID is null'
		RETURN
	END

	SELECT	@RoleID = RoleID, @SAgentID=SAgentID, @MAgentID=MAgentID, @AgentID=AgentID, @ExchangeID = ExchangeID,
			@CasinoID = CasinoID
	FROM	Customer with(nolock)
	WHERE	CustID = @CustID
	IF @@ROWCOUNT = 0
	BEGIN
		--Return Data
		SELECT @ErrCode = 'E0001'
		SET @ErrMsg = 'No data in Customer for CustID=' + CONVERT(varchar(20),@CustID)
		RETURN
	END

	DECLARE CUR_GameType CURSOR FOR
		SELECT	GameTypeID,GameTypeName, GameTypeName_Ct, GameTypeName_Cs, GameTypeName_Jp,
				GameTypeName_It, GameTypeName_Th, GameTypeName_Ko, IBCBetTypeID
		FROM	GameType 
		
	OPEN CUR_GameType
	FETCH NEXT FROM CUR_GameType Into @GameTypeID, @GameTypeName_En, @GameTypeName_Ct, @GameTypeName_Cs, 
					@GameTypeName_Jp, @GameTypeName_It, @GameTypeName_Th, @GameTypeName_Ko, @IBCBetTypeID
	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
	
		SET @Self_StakeLevelList = ''

		SELECT	@Self_StakeLevelList = StakeLevelList
		FROM	dbo.CustGameType CGT with (NOLOCK)
		WHERE	CGT.CustID = @CustID
				AND CGT.GameTypeID = @GameTypeID
				
		--Return List
		INSERT INTO @temp_custgametype(GameTypeID, IBCBetTypeID, StakeLevelName)
		SELECT	@GameTypeID as GameTypeID,@IBCBetTypeID IBCBetTypeID,B.MinLabel+'-'+B.MaxLabel StakeLevelName
		FROM(
			SELECT	StakeLevelID,MinLabel,MaxLabel,MinStake 
			FROM	dbo.StakeLevel WITH (NOLOCK) 
			WHERE	 CHARINDEX('"' + convert(varchar(20),StakeLevelID) + '"','"' + replace(@Self_StakeLevelList,',','","') + '"',0) > 0  
			) 
			B 
		ORDER BY B.MinStake
		
		FETCH NEXT FROM CUR_GameType Into @GameTypeID, @GameTypeName_En, @GameTypeName_Ct, @GameTypeName_Cs, 
						@GameTypeName_Jp, @GameTypeName_It, @GameTypeName_Th, @GameTypeName_Ko, @IBCBetTypeID
	END

	DEALLOCATE CUR_GameType	
		
	SELECT * from @temp_custgametype
		
END TRY

BEGIN CATCH
	SELECT @ErrCode = 'E0099'
	SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)
END CATCH

