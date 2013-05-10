 CREATE PROCEDURE  [dbo].[TP_Game_GameGroup_SelTST]  
 @ErrCode  varchar(5)  = '' OUTPUT,--Return ErrCode  
 @ErrMsg   nvarchar(500) = '' OUTPUT --Return Exception Message  
AS  
  
  
/*  
Purpose: Get GameGroup data  
Used By: Oneworks admin, get TST gamegroup  
Add By:  Karen,2013/1/23  
Modify By: Name,YYYY/MM/DD  
   purpose,change where  
*/  
  
SET NOCOUNT ON  
  
BEGIN TRY  
  
 --Get data   
 SELECT 1 GameGroupID, GameGroupName, GameGroupName_Ct, GameGroupName_Cs, GameGroupName_Jp, GameGroupName_It,  
   GameGroupName_Th, GameGroupName_Ko  
 FROM GameGroup (nolock)   
 WHERE GameGroupNo = 'R001'  
   AND CasinoID = 1  
 ORDER BY GameGroup.GameGroupName  
  
END TRY  
  
BEGIN CATCH  
 SELECT @ErrCode = 'E0004'  
 SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)  
END CATCH  