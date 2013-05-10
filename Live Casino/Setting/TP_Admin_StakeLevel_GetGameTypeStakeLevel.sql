CREATE PROCEDURE [dbo].[TP_Admin_StakeLevel_GetGameTypeStakeLevel]  
 @ExchangeID  int = NULL,  
 @CasinoNo  varchar(10) = '01',  
 @ErrCode  varchar(5) = '' OUTPUT, --Return ErrCode  
 @ErrMsg   nvarchar(500)= '' OUTPUT --Return Exception Message  
AS  
/*  
Purpose: Get GameType StakeLevel  
Used By: Agent Site call SP directly  
Used By:  
Add By:  Karen,2011/11/22  
   purpose,change where  
*/  
SET NOCOUNT ON  
  
DECLARE @CasinoID int  
  
BEGIN TRY  
  
 IF @ExchangeID is null  
 BEGIN  
  SET @ErrCode = 'E0002'  
  SET @ErrMsg = 'ExchangeID is null'  
  RETURN  
 END  
  
 SELECT @CasinoID = CasinoID FROM Casino (Nolock) where CasinoNo = @CasinoNo  
   
 SELECT GameType.GameTypeID, GameTypeName GameTypeName_En, GameTypeName_Ct, GameTypeName_Cs, GameTypeName_Jp,  
   GameTypeName_It, GameTypeName_Th, GameTypeName_Ko, IBCBetTypeID,   
   StakeLevel.StakeLevelID,MinLabel+'-'+MaxLabel StakeLevelName  
 FROM dbo.StakeLevel WITH (NOLOCK) INNER JOIN   
   BetTemplate WITH (NOLOCK) ON StakeLevel.BetTemplateID = BetTemplate.BetTemplateID INNER JOIN  
   GameType WITH (NOLOCK) ON BetTemplate.GameTypeID = GameType.GameTypeID  
 WHERE StakeLevel.StakeLevelID IN   
   (  
   SELECT GameStakeLevel.StakeLevelID   
   FROM (  
     SELECT GameTemplateID,StakeLevelID   
     FROM dbo.GameTemplate WITH (NOLOCK)   
     WHERE CasinoID = @CasinoID  
     ) GameTemplate INNER JOIN   
     dbo.GameStakeLevel WITH (NOLOCK) ON GameTemplate.GameTemplateID = GameStakeLevel.GameTemplateID   
   WHERE ExchangeID = @ExchangeID  
   )  
 ORDER BY GameTypeID, MinStake, MaxStake  
  
END TRY  
  
BEGIN CATCH  
 SELECT @ErrCode = 'E0099'  
 SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)  
END CATCH  