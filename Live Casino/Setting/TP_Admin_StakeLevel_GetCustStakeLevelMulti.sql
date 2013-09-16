USE [LiveCasinoAdmin]
GO
/****** Object:  StoredProcedure [dbo].[TP_Admin_StakeLevel_GetCustStakeLevelMulti]    Script Date: 06/25/2013 22:24:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TP_Admin_StakeLevel_GetCustStakeLevelMulti]
    @CustID			int = NULL,
	@ErrCode		varchar(5)	= '' OUTPUT,	--Return ErrCode
	@ErrMsg			nvarchar(500)= '' OUTPUT	--Return Exception Message
AS
/*
Purpose:	Get Cust StakeLevel
Used By:	Agent Site call SP directly
Used By:
Add By:		Karen,2011/11/22
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
IF rtrim(@GameTypeID) = ''			SET @GameTypeID = NULL


DECLARE @temp_custgametype TABLE	(	
										GameTypeID int , 
										StakeLevelID int ,
										GameTypeName_En nvarchar(50), 
										GameTypeName_Ct nvarchar(50),
										GameTypeName_Cs nvarchar(50), 
										GameTypeName_Jp nvarchar(50), 
										GameTypeName_It nvarchar(50), 
										GameTypeName_Th nvarchar(50), 
										GameTypeName_Ko nvarchar(50), 
										IBCBetTypeID int,
										StakeLevelName varchar(100),
										IsChecked bit
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
	FROM	LVCustomer with(nolock)
	WHERE	CustID = @CustID
	IF @@ROWCOUNT = 0
	BEGIN
		--Return Data
		SELECT @ErrCode = 'E0001'
		SET @ErrMsg = 'No data in Customer for CustID=' + CONVERT(varchar(20),@CustID)
		RETURN
	END

	IF @RoleID = 1
		SET @SCustID = @AgentID
	ELSE IF @RoleID = 2
		SET @SCustID = @MAgentID
	ELSE IF @RoleID = 3
		SET @SCustID = @SAgentID
	ELSE IF @RoleID = 4
		SET @SCustID = @CustID

	DECLARE CUR_GameType CURSOR FAST_FORWARD FOR
		SELECT	GameTypeID,GameTypeName, GameTypeName_Ct, GameTypeName_Cs, GameTypeName_Jp,
				GameTypeName_It, GameTypeName_Th, GameTypeName_Ko, IBCBetTypeID
		FROM	GameType 
		
	OPEN CUR_GameType
	FETCH NEXT FROM CUR_GameType Into @GameTypeID, @GameTypeName_En, @GameTypeName_Ct, @GameTypeName_Cs, 
					@GameTypeName_Jp, @GameTypeName_It, @GameTypeName_Th, @GameTypeName_Ko, @IBCBetTypeID
	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
	
		SET @Self_StakeLevelList = ''
		SET @Super_StakeLevelList = ''

		SELECT	@Self_StakeLevelList = StakeLevelList
		FROM	dbo.CustGameType CGT with (NOLOCK)
		WHERE	CGT.CustID = @CustID
				AND CGT.GameTypeID = @GameTypeID

		--Get Upline StakeLevelList
		SELECT	@Super_StakeLevelList = StakeLevelList
		FROM	dbo.CustGameType CGT with (NOLOCK)
				INNER JOIN dbo.LVCustomer C with (NOLOCK) ON CGT.CustID = C.CustID
		WHERE	C.CustID = @SCustID
				AND (CGT.GameTypeID = @GameTypeID)

		--print 'SUPER:' +@Super_StakeLevelList
		--print 'scustid:' + str(@SCustID)
		--print 'roleid:' + str(@roleID)

		--Return List
		IF (@RoleID = 1 OR @RoleID = 2 OR @RoleID = 3)
		BEGIN
			INSERT INTO @temp_custgametype(GameTypeID, GameTypeName_En, GameTypeName_Ct, GameTypeName_Cs, GameTypeName_Jp,
									GameTypeName_It, GameTypeName_Th, GameTypeName_Ko, IBCBetTypeID, StakeLevelID,StakeLevelName,IsChecked)
			SELECT	@GameTypeID as GameTypeID,@GameTypeName_En GameTypeName_En, @GameTypeName_Ct GameTypeName_Ct, @GameTypeName_Cs GameTypeName_Cs, 
					@GameTypeName_Jp GameTypeName_Jp, @GameTypeName_It GameTypeName_It, @GameTypeName_Th GameTypeName_Th, @GameTypeName_Ko GameTypeName_Ko, 
					@IBCBetTypeID IBCBetTypeID,A.StakeLevelID,A.MinLabel+'-'+A.MaxLabel StakeLevelName,CONVERT(BIT,(CASE WHEN B.StakeLevelID IS NULL THEN 0 ELSE 1 END)) IsChecked
			FROM
				(
				SELECT	StakeLevelID,MinLabel,MaxLabel,MinStake,MaxStake 
				FROM	dbo.StakeLevel WITH (NOLOCK) 
				WHERE	CHARINDEX('"' + convert(varchar(20),StakeLevelID) + '"','"' + replace(@Super_StakeLevelList,',','","') + '"',0) > 0  
				) 
				A LEFT OUTER JOIN
				(
				SELECT	StakeLevelID,MinLabel,MaxLabel,MinStake 
				FROM	dbo.StakeLevel WITH (NOLOCK) 
				WHERE	 CHARINDEX('"' + convert(varchar(20),StakeLevelID) + '"','"' + replace(@Self_StakeLevelList,',','","') + '"',0) > 0  
				) 
				B ON A.StakeLevelID = B.StakeLevelID
			ORDER BY A.MinStake,A.MaxStake
		END
		ELSE
		BEGIN
		
			INSERT INTO @temp_custgametype(GameTypeID, GameTypeName_En, GameTypeName_Ct, GameTypeName_Cs, GameTypeName_Jp,
									GameTypeName_It, GameTypeName_Th, GameTypeName_Ko, IBCBetTypeID, StakeLevelID,StakeLevelName,IsChecked)
			SELECT @GameTypeID as GameTypeID,@GameTypeName_En GameTypeName_En, @GameTypeName_Ct GameTypeName_Ct, @GameTypeName_Cs GameTypeName_Cs, 
					@GameTypeName_Jp GameTypeName_Jp, @GameTypeName_It GameTypeName_It, @GameTypeName_Th GameTypeName_Th, @GameTypeName_Ko GameTypeName_Ko, 
					@IBCBetTypeID IBCBetTypeID,A.StakeLevelID,A.MinLabel+'-'+A.MaxLabel StakeLevelName,CONVERT(BIT,(CASE WHEN B.StakeLevelID IS NULL THEN 0 ELSE 1 END)) IsChecked
			FROM
				(
				SELECT	StakeLevelID,MinLabel,MaxLabel,MinStake,MaxStake 
				FROM	dbo.StakeLevel WITH (NOLOCK) 
				WHERE	StakeLevelID IN (SELECT StakeLevelID 
										FROM	(SELECT GameTemplateID 
												FROM	dbo.GameTemplate WITH (NOLOCK) 
												WHERE	GameTypeID = @GameTypeID
														AND CasinoID = @CasinoID
												) GameTemplate INNER JOIN 
												dbo.GameStakeLevel WITH (NOLOCK) ON GameTemplate.GameTemplateID = GameStakeLevel.GameTemplateID 
												WHERE ExchangeID = @ExchangeID 
										)
				) 
				A LEFT OUTER JOIN
				(
				SELECT	StakeLevelID,MinLabel,MaxLabel,MinStake 
				FROM	dbo.StakeLevel WITH (NOLOCK) 
				WHERE	CHARINDEX('"' + convert(varchar(20),StakeLevelID) + '"','"' + replace(@Self_StakeLevelList,',','","') + '"',0) > 0  
				) 
				B ON A.StakeLevelID = B.StakeLevelID
			ORDER BY A.MinStake,A.MaxStake
		END
		
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
