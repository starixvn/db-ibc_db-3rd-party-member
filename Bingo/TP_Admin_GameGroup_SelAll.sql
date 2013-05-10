 set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[TP_Admin_GameGroup_SelAll]
	@SiteNo			varchar(10) = null,		--Input TABLE's field
	@ErrCode		varchar(5)	= '' OUTPUT,	--Return ErrCode
	@ErrMsg			nvarchar(500)= '' OUTPUT	--Return Exception Message
AS
/*
Purpose:	Get GameGroup
Used By:	Admin Site
Used By:
Add By:		Karen 2010/8/2
			purpose,change where
Modify By:	Name,YYYY/MM/DD
			purpose,change where
*/
SET NOCOUNT ON

DECLARE @SiteID int

BEGIN TRY

	IF @SiteNo is null
	BEGIN
		SET @ErrCode = 'E0001'
		SET @ErrMsg = 'SiteNo is null'
		RETURN
	END

	SELECT	@SiteID = SiteID
	FROM	Site (nolock)
	WHERE	SiteNo = @SiteNo
	IF @@ROWCOUNT = 0
	BEGIN
		SET @ErrCode = 'E0002'
		SET @ErrMsg = 'SiteNo:' + @SiteNo + ' not exist'
		RETURN
	END

	--Get data 
	SELECT	GameGroupID,SiteID,GameGroupNo,GameGroupName,GameGroupName AS GameGroupName_En,GameGroupName_Ct,GameGroupName_Cs,GameGroupName_Jp,GameGroupName_It,
			GameGroupName_Th,GameGroupName_Ko,IsDisabled 
	FROM	GameGroup with (NOLOCK) 
	WHERE	SiteID = @SiteID
			AND IsDisabled = 0

END TRY

BEGIN CATCH
	SELECT @ErrCode = 'E0010'
	SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)
END CATCH



