 CREATE PROCEDURE [dbo].[TP_Admin_GameGroup_Sel]  
 @CasinoID int = null,  --Input TABLE's field  
 @ErrCode varchar(5) = '' OUTPUT, --Return ErrCode  
 @ErrMsg  nvarchar(500)= '' OUTPUT --Return Exception Message  
AS  
  
SET NOCOUNT ON  
  
BEGIN TRY  
  
 --Get data   
 SELECT GameGroupID, CasinoID, GameGroupNo, GameGroupName,GameGroupName_Ct, GameGroupName_Cs, GameGroupName_Jp, GameGroupName_It, GameGroupName_Th, GameGroupName_Ko, IsDisabled   
 FROM GameGroup with (NOLOCK)   
 WHERE CasinoID = @CasinoID  
  
END TRY  
  
BEGIN CATCH  
 SELECT @ErrCode = 'E0004'  
 SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)  
END CATCH  