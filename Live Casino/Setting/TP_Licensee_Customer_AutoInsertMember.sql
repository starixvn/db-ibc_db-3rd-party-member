  
CREATE PROCEDURE [dbo].[TP_Licensee_Customer_AutoInsertMember]  
 @CustID   int = null,  
 @IBCSiteID  varchar(7),  
 @ErrCode  varchar(5)  = '' OUTPUT,--Return ErrCode  
 @ErrMsg   nvarchar(500) = '' OUTPUT --Return Exception Message  
AS  
  
/*  
Purpose: Create Default data for member  
Used By: Licesee  
Add By:  Karen,2012/8/23  
Modify By:   
*/  
  
SET NOCOUNT ON  
  
DECLARE @Tmp_Customer TABLE (  
  CustID int,  
  username varchar(30),  
  srecommend int,  
  mrecommend int,  
  recommend int,  
  roleid tinyint,  
  currency tinyint,  
  Site varchar(10)  
)  
  
DECLARE @GameGroupID int  
DECLARE @GameTypeID  int  
DECLARE @CasinoID  int  
DECLARE @IsInternal  bit  
DECLARE @SiteID   int  
  
DECLARE @ExchangeID  int  
DECLARE @UserName  nvarchar(30)  
DECLARE @RoleID   tinyint  
DECLARE @SAgentID  int  
DECLARE @MAgentID  int  
DECLARE @AgentID  int  
  
DECLARE @StakeLevelList varchar(100)  
DECLARE @StakeLevelListValue varchar(100)  
DECLARE @SuperStakeLevelList varchar(100)  
DECLARE @SuperStakeLevelListValue varchar(100)  
DECLARE @DefaultStakeLevelList varchar(100)  
DECLARE @DefaultStakeLevelListValue varchar(100)  
  
DECLARE @GameTypeName varchar(100)  
DECLARE @ToUserName  nvarchar(50)  
DECLARE @CustSite  nvarchar(50)  
DECLARE @StakeLevelID int  
DECLARE @MinLabel  varchar(100)  
DECLARE @MaxLabel  varchar(100)  
DECLARE @MaxStake  decimal(19,8)  
  
DECLARE @Tmp_SAgentID  int  
DECLARE @Tmp_MAgentID  int  
DECLARE @Tmp_AgentID  int  
DECLARE @AdminID   int  
  
SET @StakeLevelListValue = ''  
SET @StakeLevelList = ''  
SET @SuperStakeLevelList = ''  
SET @SuperStakeLevelListValue = ''  
  
BEGIN TRY  
  
 --如果已有資料, 就不用做了  
 SELECT LVCustSettingID  
 FROM LVCustSetting (nolock)  
 WHERE LVCustSettingID = @CustID  
 IF @@ROWCOUNT > 0   
 Begin  
  Print 'Already has LVCustSetting, exit'  
  Return  
 End  
   
 SELECT @AdminID = AdminID   
 FROM Admin (nolock)  
 WHERE AdminName = 'rdmanager'  
  
 --找出這個玩家以及其上線資料  
 SELECT @Tmp_SAgentID = C.srecommend, @Tmp_MAgentID = C.mrecommend, @Tmp_AgentID = C.recommend, @UserName = UserName, @ExchangeID = Currency  
 From Customer C (nolock)  
 Where C.CustID = @CustID  
  
 Insert Into @Tmp_Customer(CustID, username, srecommend, mrecommend, recommend, roleid, currency, Site)  
 SELECT C.CustID, C.username,   
   C.srecommend, C.mrecommend, C.recommend,   
   C.roleid, C.currency, C.Site  
 FROM dbo.Customer C (nolock)  
 WHERE C.custid = @CustID or   
   C.custid = @Tmp_SAgentID or  
   C.custid = @Tmp_MAgentID or  
   C.custid = @Tmp_AgentID  
 ORDER BY RoleID DESC, C.CustID  
  
 WHILE (1=1)  
 BEGIN  
  
  SELECT TOP 1 @CustID = CustID, @UserName = username,   
      @SAgentID = srecommend,  
      @MAgentID = mrecommend,   
      @AgentID = recommend,   
      @RoleID = roleid,   
      @ExchangeID = currency, @CustSite = Site  
  FROM @Tmp_Customer   
  ORDER BY RoleID DESC, CustID  
  
  --若無資料跳出  
  IF (@@ROWCOUNT = 0) BREAK  
  
  Print 'Username=' + @UserName + ',CustID=' + rtrim(@CustID)  
   
  SET @ToUserName = ''  
  SET @CasinoID = null  
  SET @SiteID = null  
  SET @IsInternal = null  
  
  IF @RoleID = 1  --Member  
  BEGIN  
   SET @ToUserName = 'Member[' + @UserName + ']'  
  
   SELECT @CasinoID = CasinoID, @SiteID=SiteID, @IsInternal = IsInternal  
   FROM LVCustSetting (nolock)  
   WHERE LVCustSettingID = @SAgentID  
  
  END  
  ELSE IF @RoleID = 2  --Agent  
  BEGIN  
   SET @ToUserName = 'Agent[' + @UserName + ']'  
     
   SELECT @CasinoID = CasinoID, @SiteID=SiteID, @IsInternal = IsInternal  
   FROM LVCustSetting (nolock)  
   WHERE LVCustSettingID = @SAgentID  
  
  END  
  ELSE IF @RoleID = 3  --Master  
  BEGIN  
   SET @ToUserName = 'Master[' + @UserName + ']'  
     
   SELECT @CasinoID = CasinoID, @SiteID=SiteID, @IsInternal = IsInternal  
   FROM LVCustSetting (nolock)  
   WHERE LVCustSettingID = @SAgentID  
  END  
  ELSE IF @RoleID = 4  --Super  
  BEGIN  
    
   EXEC TP_Admin_SiteMapping_ByIBCSiteID @IBCSiteID = @IBCSiteID,  
             @SiteID  = @SiteID OUTPUT,  
             @CasinoID = @CasinoID OUTPUT,  
             @ErrCode = @ErrCode OUTPUT,  
             @ErrMsg  = @ErrMsg OUTPUT   
    
   --print rtrim(@custid) + ',' + @CustSite + ',' + rtrim(@SiteID) + ',' + rtrim(@CasinoID)  
    
   SET @ToUserName = 'Super[' + @UserName + ']'  
         
   IF @ExchangeID = 20   
    SET @IsInternal = 1   
   ELSE   
    SET @IsInternal = 0   
  END  
     
  --如果沒有LVCustSetting的資料, 就新增這個玩家的資料          
  SELECT LVCustSettingID  
  FROM LVCustSetting (nolock)  
  WHERE LVCustSettingID = @CustID  
  IF @@ROWCOUNT = 0  
  BEGIN  
   INSERT INTO LVCustSetting(LVCustSettingID,CanUseChat,IsEnablePT,IsInternal,SiteID,CasinoID,Remark)   
    VALUES(@CustID,0,1,@IsInternal,@SiteID,@CasinoID,'From licensee')  
  
   INSERT INTO ActionLog (CasinoID,FromID,FromRoleID,FromUserName,ToID,ToRoleID,ToUserName,ActionTime,TableName,KeyID,ExtraInfo,FromIP)  
     VALUES(@CasinoID,@AdminID,1,'Admin[rdmanager]',@CustID,2,@ToUserName,GetDate(),'LVCustSetting',@CustID,'New account created (By Licensee auto Create)','10.40.40.187')  
  
  END  
  Else  
  Begin  
   Print 'Has LVCustSetting'  
  End  
  
  --如果沒有CustFinance的資料, 就新增這個玩家的資料  
  SELECT CustFinanceID  
  FROM CustFinance (nolock)  
  WHERE CustFinanceID = @CustID  
  IF @@ROWCOUNT=0  
  BEGIN  
   INSERT INTO CustFinance(CustFinanceID) VALUES(@CustID)  
  END  
  Else  
  Begin  
   Print 'Has CustFinance'  
  End  
  
  --如果沒有CustGameType的資料, 就新增這個玩家的資料  
    
    
  --SELECT @GameGroupID = GameGroupID, @GameTypeID = GameTypeID, @GameTypeName = GameTypeName  
  IF OBJECT_ID('tempdb..#temp_GameType') IS NOT NULL DROP TABLE #temp_GameType  
  SELECT GameGroupID, GameTypeID, GameTypeName  
  INTO #temp_GameType  
  FROM GameType (nolock)  
  ORDER BY GameTypeID  
  WHILE (1=1)  
  BEGIN  
   SELECT Top 1 @GameGroupID = GameGroupID, @GameTypeID = GameTypeID, @GameTypeName = GameTypeName    
   FROM #temp_GameType with(nolock)  
   ORDER BY GameTypeID  
   IF (@@ROWCOUNT = 0) BREAK  
     
   SELECT CustID  
   FROM CustGameType (nolock)  
   WHERE CustID = @CustID  
     AND GameTypeID = @GameTypeID   
   IF @@ROWCOUNT=0  
   BEGIN  
  
    --Get Default StakeLevel  
    IF OBJECT_ID('tempdb..#temp_StakeLevel') IS NOT NULL DROP TABLE #temp_StakeLevel  
    SELECT SL.StakeLevelID, SL.MinStake, SL.MaxStake, SL.MinLabel, SL.MaxLabel  
    INTO #temp_StakeLevel  
    FROM GameStakeLevel (nolock) GSL INNER JOIN  
      StakeLevel (nolock) SL ON GSL.StakeLevelID = SL.StakeLevelID INNER JOIN  
      GameTemplate (nolock) GT ON GT.GameTemplateID = GSL.GameTemplateID  
    WHERE (GSL.ExchangeID = @ExchangeID)  
      AND GT.CasinoID = @CasinoID  
    ORDER BY SL.MinStake  
    WHILE (1=1)  
    BEGIN  
  
     SELECT Top 1 @StakeLevelID = CONVERT(VARCHAR(10),StakeLevelID),  
         @MinLabel = rtrim(MinLabel),   
         @MaxLabel = rtrim(MaxLabel),  
         @MaxStake = MaxStake   
     FROM #temp_StakeLevel with(nolock)  
  
     IF (@@ROWCOUNT = 0)   
     BEGIN  
      IF len(@SuperStakeLevelListValue) > 0  
      BEGIN  
       SET @SuperStakeLevelListValue = substring(@SuperStakeLevelListValue,2,len(@SuperStakeLevelListValue)-1)  
      END  
      IF len(@SuperStakeLevelList) > 0  
      BEGIN  
       SET @SuperStakeLevelList = substring(@SuperStakeLevelList,1,len(@SuperStakeLevelList)-1)  
      END  
      BREAK  
     END  
  
     IF @MaxStake <> 0  
     BEGIN  
      IF @StakeLevelList = '' SET @StakeLevelList = @StakeLevelID  
      IF @StakeLevelListValue = '' SET @StakeLevelListValue = @MinLabel + '-' + @MaxLabel  
     END  
       
     SET @SuperStakeLevelList = @SuperStakeLevelList + RTRIM(@StakeLevelID) + ','  
     SET @SuperStakeLevelListValue = @SuperStakeLevelListValue + ';' + @MinLabel + '-' + @MaxLabel  
  
     Delete From #temp_StakeLevel   
     WHERE StakeLevelID = @StakeLevelID  
    END  
  
    IF @RoleID = 1  --Member  
    BEGIN  
     SET @DefaultStakeLevelList = @StakeLevelList  
     SET @DefaultStakeLevelListValue = @StakeLevelListValue  
    END  
    ELSE IF @RoleID = 2  --Agent  
    BEGIN  
     SET @DefaultStakeLevelList = @StakeLevelList  
     SET @DefaultStakeLevelListValue = @StakeLevelListValue  
    END  
    ELSE IF @RoleID = 3  --Master  
    BEGIN  
     SET @DefaultStakeLevelList = @SuperStakeLevelList  
     SET @DefaultStakeLevelListValue = @SuperStakeLevelListValue  
    END  
    ELSE IF @RoleID = 4  --Super  
    BEGIN  
     SET @DefaultStakeLevelList = @SuperStakeLevelList  
     SET @DefaultStakeLevelListValue = @SuperStakeLevelListValue  
    END  
  
    INSERT INTO CustGameType(GameGroupID,GameTypeID,CustID,StakeLevelList)  
      VALUES(@GameGroupID,@GameTypeID,@CustID,@DefaultStakeLevelList)  
  
    INSERT INTO ActionLog (CasinoID,FromID,FromRoleID,FromUserName,ToID,ToRoleID,ToUserName,ActionTime,TableName,KeyID,NewData,ExtraInfo,FromIP)  
      VALUES(@CasinoID,@AdminID,1,'Admin[rdmanager]',@CustID,2,@ToUserName,GetDate(),'CustGameType',@GameTypeID,@DefaultStakeLevelListValue,@GameTypeName + ' - Betting Limit (By Licensee auto Create)','10.40.40.187')  
  
   END  
   IF (@ErrMsg <> '') RAISERROR(@ErrMsg,16,1)  
   DELETE FROM #temp_GameType WHERE GameTypeID = @GameTypeID  
  END   
  
  IF (@ErrMsg <> '') RAISERROR(@ErrMsg,16,1)  
  DELETE FROM @Tmp_Customer WHERE CustID = @CustID  
  
 END  
  
 IF (@ErrMsg <> '') RAISERROR(@ErrMsg,16,1)   
   
END TRY  
  
BEGIN CATCH  
 SELECT @ErrCode = 'E0004'  
 SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)  
END CATCH  
  
  
  
  