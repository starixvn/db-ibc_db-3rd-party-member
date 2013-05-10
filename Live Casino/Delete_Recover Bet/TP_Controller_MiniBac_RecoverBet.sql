 set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[TP_Controller_MiniBac_RecoverBet]
	@IBCTransID		bigint			= 0,
	@Sysdate		datetime		= null,
	@AdminID		int				= null,
	@AdminName		nvarchar(30)	= null,	
	@CasinoNo		varchar(10)		= null,
	@ErrCode		varchar(5)		= '' OUTPUT,--Return ErrCode
	@ErrMsg			nvarchar(500)	= '' OUTPUT	--Return Exception Message
AS

/*
Purpose:	Account Site, RecoverBet
			1)Update UserBet
Used By:	Casino System,
Add By:		Karen, 2011/12/19
Modify By:	Name,YYYY/MM/DD
			purpose,change where
*/

SET NOCOUNT ON

DECLARE @GameID		bigint
DECLARE @GameNo		varchar(18)
DECLARE @CasinoID	int
DECLARE @LogDetail	varchar(500)
DECLARE @CanceledBy	int
DECLARE @Status		varchar(2)
DECLARE @UpdateCount int
DECLARE @GameStatus	varchar(20)
DECLARE @MatchID	int

BEGIN TRY

	IF @IBCTransID is null or @IBCTransID = 0
	BEGIN
		SELECT @ErrCode = 'E0004'
		SELECT @ErrMsg = 'IBCTransID is required'
		Return	
	END

	SELECT	@CasinoID = CasinoID
	FROM	Casino (nolock)
	WHERE	CasinoNo = @CasinoNo
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 'E0001'
		SELECT @ErrMsg = 'CasinoNo=' + @CasinoNo + ' not in Casino'
		Return
	END	
			
	SELECT	@GameID = GameID, @Status = Status
	FROM	UserBet (nolock)
	WHERE	IBCTransID = @IBCTransID
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 'E0002'
		SELECT @ErrMsg = 'IBCTransID=' + rtrim(@IBCTransID) + ' not in UserBet'
		Return
	END	
	ELSE
	IF @Status <> '60'
	BEGIN
		SELECT @ErrCode = 'E0003'
		SELECT @ErrMsg = 'only delete userbet can be recoverbet'
		Return
	END
		
	SELECT	@GameStatus = Status, @MatchID = MatchID
	FROM	Game (nolock)
	WHERE	GameID = @GameID		
	IF @GameStatus <> '30'
	BEGIN
		SELECT @ErrCode = 'E0005'
		SELECT @ErrMsg = 'only uncompleted game can be recoverbet'
		Return

	END
		
	SELECT	@CanceledBy = AdminID
	FROM	[Admin] (nolock) 
	WHERE	AdminName = 'rdaccount'

	--Update UserBet's Status
	UPDATE	UserBet with(rowlock)
	SET		[Status] = '20'
	WHERE	GameID = @GameID
			AND IBCTransID = @IBCTransID 
	
	SET @LogDetail = 'Delete userbet:IBCTransID=' + rtrim(@IBCTransID) + ',GameID=' + rtrim(@GameID) + ',MatchID=' + rtrim(@MatchID) 
	
	SET @AdminName = 'Account[' + @AdminName + ']'

	EXEC LIVECASINOBACKUP.LiveCasinoAdmin.[dbo].[AP_Game_GameLog_Ins]
							@CasinoID = @CasinoID,	
							@GameID  = @GameID,		
							@GameNo  = @GameNo,		
							@System  = 'API-IBC',		
							@ActorID  = @AdminID,		
							@ActorName  = @AdminName,		
							@ActionTime  = @Sysdate,		
							@LogDetail  = @LogDetail	

END TRY

BEGIN CATCH
	SELECT @ErrCode = 'E0099'
	SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)
END CATCH




