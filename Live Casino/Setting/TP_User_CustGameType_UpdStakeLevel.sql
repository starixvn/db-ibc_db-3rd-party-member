USE [LiveCasinoAdmin]
GO
/****** Object:  StoredProcedure [dbo].[TP_User_CustGameType_UpdStakeLevel]    Script Date: 09/07/2012 10:35:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TP_User_CustGameType_UpdStakeLevel]
	@GameTypeID		int = null,
	@CustID			int = null,		--Input TABLE's field
	@StakeLevelList varchar(100) = null,		--Input TABLE's field
	@RoleID			int = null,	
	@ErrCode		varchar(5)	= '' OUTPUT,	--Return ErrCode
	@ErrMsg			nvarchar(3000)= '' OUTPUT	--Return Exception Message
AS
/*
Purpose:	Update Stake Level
Used By:	Agent Site call SP directly
Used By:
Add By:		Karen,2011/11/22
*/
SET NOCOUNT ON

DECLARE @CustGameTypeID int
DECLARE @GameGroupID int
DECLARE @DownLineID int
DECLARE @DownLineRoleID int

DECLARE @Downline_StakeLevelList varchar(100)
DECLARE @OldStakeLevelList varchar(100)
DECLARE @LowestStakeLevelList varchar(100)
DECLARE @val nvarchar(4000)

DECLARE @temp_gametype_comm_downline TABLE	(	
											CustID			int, 
											RoleID			tinyint,
											StakeLevelList	varchar(100),
											CustGameTypeID	int 
											)

SET @Downline_StakeLevelList = ''

IF rtrim(@GameGroupID) = ''		SET @GameGroupID = NULL
IF rtrim(@GameTypeID) = ''		SET @GameTypeID = NULL
IF rtrim(@CustID) = ''			SET @CustID = NULL
IF rtrim(@RoleID) = ''			SET @RoleID = NULL

BEGIN TRY

	--Get Customer's data
	IF @CustID is null
	BEGIN
		SET @ErrCode = 'E0001'
		SET @ErrMsg = 'CustID is null'
		RETURN
	END
	
	/*SELECT	@RoleID = RoleID
	FROM	Customer with(nolock)
	WHERE	CustID = @CustID
	IF @@ROWCOUNT = 0
	BEGIN
		--Return Data
		SELECT @ErrCode = 'E0002'
		SET @ErrMsg = 'No data in Customer for CustID=' + CONVERT(varchar(20),@CustID)
		RETURN
	END*/
	
	IF @GameTypeID is null
	BEGIN
		SET @ErrCode = 'E0003'
		SET @ErrMsg = 'GameTypeID is null'
		RETURN
	END
	
	SELECT	@GameGroupID = GameGroupID
	FROM	GameType with(nolock)
	WHERE	GameTypeID = @GameTypeID		
	IF @@ROWCOUNT = 0
	BEGIN
		--Return Data
		SELECT @ErrCode = 'E0004'
		SET @ErrMsg = 'No data in GameType for GameTypeID=' + CONVERT(varchar(20),@GameTypeID)
		RETURN
	END

	--Update itself
	SELECT	@CustGameTypeID = CustGameTypeID, @OldStakeLevelList = StakeLevelList 
	FROM	CustGameType with (NOLOCK) 
	WHERE	GameTypeID = @GameTypeID AND CustID = @CustID
	IF @@ROWCOUNT = 0
	BEGIN
		--If not exists, insert one
		INSERT CustGameType(GameGroupID,GameTypeID,CustID,StakeLevelList)
			VALUES(@GameGroupID,@GameTypeID,@CustID,@StakeLevelList)
	END
	ELSE
	BEGIN	
		--Update CustGameType data
		UPDATE	CustGameType with(rowlock)
		SET		StakeLevelList = @StakeLevelList
		WHERE	CustGameTypeID = @CustGameTypeID
	END

	IF @StakeLevelList <> @OldStakeLevelList
	BEGIN 

		--抓出這次刪除的StakeLevel
		IF OBJECT_ID('tempdb..#temp_DelStakeLevelList') IS NOT NULL DROP TABLE #temp_DelStakeLevelList
		IF @OldStakeLevelList <> @StakeLevelList
		BEGIN
			SELECT	ISNULL(Val,'') 
			FROM	dbo.strSplit(@OldStakeLevelList,',')
			WHERE	Val not IN(SELECT val FROM dbo.strSplit(@StakeLevelList,',')) 
			IF @@ROWCOUNT > 0
				SELECT	ISNULL(Val,'') Val INTO #temp_DelStakeLevelList
				FROM	dbo.strSplit(@OldStakeLevelList,',')
				WHERE	ISNULL(Val,'') not IN(SELECT ISNULL(val,'') Val FROM dbo.strSplit(@StakeLevelList,',')) 
		END

		--抓出最小StakeLevel
		SELECT	top 1 @LowestStakeLevelList = CONVERT(VARCHAR(10),StakeLevelID)
		FROM	StakeLevel with(nolock)
		WHERE	CHARINDEX('''' + convert(varchar(5),StakeLevelID) + '''','''' + replace(@StakeLevelList,',',''',''') + '''') > 0
				AND MinStake <> 0
				AND MaxStake <> 0
		ORDER BY MinStake, MaxStake		

		--Step 3 Get Downline member
		--若temp table已存在先刪除
		--IF OBJECT_ID('tempdb..#temp_gametype_comm_downline') IS NOT NULL DROP TABLE #temp_gametype_comm_downline
		--取得全部工作
		/*IF @RoleID = 1
		BEGIN
			SELECT	LVCustomer.CustID ,LVCustomer.RoleID, ISNULL(StakeLevelList,'') StakeLevelList,CustGameTypeID
			INTO	@temp_gametype_comm_downline 
			FROM	dbo.LVCustomer WITH (NOLOCK) INNER JOIN 
					(SELECT CustGameTypeID,GameGroupID,GameTypeID,CustID,StakeLevelList FROM dbo.CustGameType WITH (NOLOCK) WHERE GameTypeID = @GameTypeID) CustGameType ON LVCustomer.CustID = CustGameType.CustID
			WHERE	LVCustomer.CUSTID = @CustID
		END*/
		IF @RoleID = 2 
		BEGIN
			INSERT INTO	@temp_gametype_comm_downline 
			SELECT	LVCustomer.CustID ,LVCustomer.RoleID, ISNULL(StakeLevelList,'') StakeLevelList,CustGameTypeID
			FROM	dbo.LVCustomer WITH (NOLOCK) INNER JOIN 
					(SELECT CustGameTypeID,GameGroupID,GameTypeID,CustID,StakeLevelList FROM dbo.CustGameType WITH (NOLOCK) WHERE GameTypeID = @GameTypeID) CustGameType ON LVCustomer.CustID = CustGameType.CustID
			WHERE	LVCustomer.AgentID = @CustID
		END
		IF @RoleID = 3
		BEGIN
			INSERT INTO	@temp_gametype_comm_downline 
			SELECT	LVCustomer.CustID ,LVCustomer.RoleID, ISNULL(StakeLevelList,'') StakeLevelList,CustGameTypeID
			FROM	dbo.LVCustomer WITH (NOLOCK) INNER JOIN 
					(SELECT CustGameTypeID,GameGroupID,GameTypeID,CustID,StakeLevelList FROM dbo.CustGameType WITH (NOLOCK) WHERE GameTypeID = @GameTypeID) CustGameType ON LVCustomer.CustID = CustGameType.CustID
			WHERE	LVCustomer.MAgentID = @CustID
		END
		IF @RoleID = 4
		BEGIN
			INSERT INTO	@temp_gametype_comm_downline 
			SELECT	LVCustomer.CustID ,LVCustomer.RoleID, ISNULL(StakeLevelList,'') StakeLevelList,CustGameTypeID
			FROM	dbo.LVCustomer WITH (NOLOCK) INNER JOIN 
					(SELECT CustGameTypeID,GameGroupID,GameTypeID,CustID,StakeLevelList FROM dbo.CustGameType WITH (NOLOCK) WHERE GameTypeID = @GameTypeID) CustGameType ON LVCustomer.CustID = CustGameType.CustID
			WHERE	LVCustomer.SAgentID = @CustID
		END
		
		--run loop
		WHILE (1 = 1)
		BEGIN

			SELECT TOP 1 @DownLineID = CustID, @DownLineRoleID = RoleID, @Downline_StakeLevelList = StakeLevelList, @CustGameTypeID = CustGameTypeID
			FROM	@temp_gametype_comm_downline 
			ORDER BY CustID
			--若無資料跳出
			IF (@@ROWCOUNT = 0) BREAK
			PRINT 'CustID:' + RTRIM(@DownLineID)
			PRINT 'RoleID:' + RTRIM(@DownLineRoleID)

			--判斷若上層拿掉BettingLimit,則下層要一併拿掉
			IF OBJECT_ID('tempdb..#temp_DelStakeLevelList') IS NOT NULL
			BEGIN

				IF @Downline_StakeLevelList <> ''
				BEGIN
					SET @Downline_StakeLevelList = '''' + REPLACE(@Downline_StakeLevelList,',',''',''') + ''''

					DECLARE CUR_StakeLevelList CURSOR FOR
						SELECT	'''' + val + ''''
						FROM	#temp_DelStakeLevelList WITH(NOLOCK)
					OPEN CUR_StakeLevelList
					FETCH NEXT FROM CUR_StakeLevelList Into @val
					WHILE (@@FETCH_STATUS <> -1)
					BEGIN

						IF CHARINDEX(@val+',',@Downline_StakeLevelList) > 0
						BEGIN
							SET @Downline_StakeLevelList = REPLACE(@Downline_StakeLevelList,@val+',','')
						END
						IF CHARINDEX(@val,@Downline_StakeLevelList) > 0
						BEGIN
							SET @Downline_StakeLevelList = REPLACE(@Downline_StakeLevelList,@val,'')
						END

						FETCH NEXT FROM CUR_StakeLevelList Into @val
					END

					CLOSE CUR_StakeLevelList
					DEALLOCATE CUR_StakeLevelList

					SET @Downline_StakeLevelList = REPLACE(@Downline_StakeLevelList,'''','')
					IF RIGHT(@Downline_StakeLevelList,1) = ',' SET @Downline_StakeLevelList = LEFT(@Downline_StakeLevelList,LEN(@Downline_StakeLevelList)-1)
					
					IF ISNULL(@Downline_StakeLevelList,'') = ''
					BEGIN
						SET @Downline_StakeLevelList = @LowestStakeLevelList
					END
					
				END
			END

			--若原本都沒有但回設回來,則Agent/Member預設最小的Betting limit,Master預設跟Super一樣
			IF RTRIM(ISNULL(@OldStakeLevelList,'')) = '' AND RTRIM(ISNULL(@StakeLevelList,'')) <> ''
			BEGIN
				IF @DownLineRoleID = 1 or @DownLineRoleID = 2 
				BEGIN
					SET @Downline_StakeLevelList = @LowestStakeLevelList
				END
				ELSE IF @DownLineRoleID = 3
				BEGIN	
					SET @Downline_StakeLevelList = @StakeLevelList
				END
			END
			
			UPDATE	dbo.CustGameType WITH (ROWLOCK)
			SET		StakeLevelList = @Downline_StakeLevelList
			WHERE	CustGameTypeID = @CustGameTypeID

			IF (@ErrMsg <> '') RAISERROR(@ErrMsg,16,1)

			DELETE FROM @temp_gametype_comm_downline WHERE CustID = @DownLineID
		END
	END
	
	--IF OBJECT_ID('tempdb..#temp_gametype_comm_downline') IS NOT NULL DROP TABLE #temp_gametype_comm_downline
END TRY

BEGIN CATCH

	SELECT @ErrCode = 'E0099'
	SELECT @ErrMsg = ERROR_MESSAGE()
	--SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)
END CATCH
