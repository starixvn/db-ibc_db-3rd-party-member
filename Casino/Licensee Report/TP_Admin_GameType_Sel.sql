 CREATE PROCEDURE  [dbo].[TP_Admin_GameType_Sel]  
 @CasinoID int = null,  --Input TABLE's field  
 @GameKind int = null,  --Input TABLE's field  
 @GameGroupID int = null,  --Input TABLE's field  
 @ErrCode varchar(5) = '' OUTPUT, --Return ErrCode  
 @ErrMsg  nvarchar(500)= '' OUTPUT --Return Exception Message  
AS  
  
SET NOCOUNT ON  
  
BEGIN TRY  
  
 --Get data   
 SELECT GameTypeID, GameTypeNo,CasinoID, GameGroupID, GameKind, GameTypeName, GameTypeName AS GameTypeName_En, GameTypeName_Ct, GameTypeName_Cs, GameTypeName_Jp, GameTypeName_It, GameTypeName_Th, GameTypeName_Ko   
 FROM GameType with (NOLOCK)   
 WHERE (CasinoID = @CasinoID)  
   AND (@GameKind IS NULL OR GameKind = @GameKind)  
   AND (@GameGroupID IS NULL OR GameGroupID = @GameGroupID)  
   AND (IsDisabled = 0)  
  
END TRY  
  
BEGIN CATCH  
 SELECT @ErrCode = 'E0004'  
 SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)  
END CATCH  