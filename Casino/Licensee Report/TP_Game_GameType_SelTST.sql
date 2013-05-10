 CREATE PROCEDURE  [dbo].[TP_Game_GameType_SelTST]  
 @GameGroupID int    = '' OUTPUT,  
 @ErrCode  varchar(5)  = '' OUTPUT,--Return ErrCode  
 @ErrMsg   nvarchar(500) = '' OUTPUT --Return Exception Message  
AS  
  
  
/*  
Purpose: Get GameType data  
Used By: Oneworks admin, get TST gametype  
Add By:  Karen,2013/1/23  
Modify By: Name,YYYY/MM/DD  
   purpose,change where  
*/  
  
SET NOCOUNT ON  
  
BEGIN TRY  
  
 --Get data   
 --Card Games  
 IF @GameGroupID = 0 or @GameGroupID = 1  
 BEGIN  
  SELECT GameTypeID, GameTypeName, GameTypeName_Ct, GameTypeName_Cs, GameTypeName_Jp, GameTypeName_It,  
    GameTypeName_Th, GameTypeName_Ko  
  FROM GameType (nolock)   
  WHERE GameTypeNo in ('R0001','R0015','R0003','R0014','R0006','R0017','R0007','R0018','M0001','M0003','M0002')  
    AND CasinoID = 1  
  ORDER BY GameTypeName  
 END  
   
END TRY  
  
BEGIN CATCH  
 SELECT @ErrCode = 'E0004'  
 SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)  
END CATCH  