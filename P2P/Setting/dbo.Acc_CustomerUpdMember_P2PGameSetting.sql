
CREATE PROCEDURE [dbo].[Acc_CustomerUpdMember_P2PGameSetting]
@custid INT,
@StakeLevel1_91 BIT, 
@StakeLevel2_91 BIT, 
@StakeLevel3_91 BIT, 
@StakeLevel4_91 BIT, 
@StakeLevel5_91 BIT, 

@StakeLevel1_92 BIT, 
@StakeLevel2_92 BIT, 
@StakeLevel3_92 BIT, 
@StakeLevel4_92 BIT, 
@StakeLevel5_92 BIT, 

@SubAccID INT = 0, --Sub-AccountID
@UserID INT = 0, 
@Language VARCHAR(2) = 'E',
@IP VARCHAR(40)='',
@ErrCode INT = 0 OUTPUT,
@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: 20110421@Amy
Task : Update Member's P2P GameSETting
DB: DBTrans.bodb02
Original:

Revisions: 

Param's Explanation:
@ErrCode:
	= 0: Update commission successfully.
	> 0: SpecIFic Error.
	range: 201-202
@ErrMsg: Error description.
*/

SET NOCOUNT ON

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
SET @startRun = getdate()

DECLARE @LogData varchar(5000), @UplineID INT
SET @LogData=''
DECLARE @Upline_SL1 BIT, @Upline_SL2 BIT, @Upline_SL3 BIT, @Upline_SL4 BIT, @Upline_SL5 BIT,		
		@Old_StakeLevel1_91 BIT, @Old_StakeLevel2_91 BIT, @Old_StakeLevel3_91 BIT, @Old_StakeLevel4_91 BIT, @Old_StakeLevel5_91 BIT, 
		@Old_StakeLevel1_92 BIT, @Old_StakeLevel2_92 BIT, @Old_StakeLevel3_92 BIT, @Old_StakeLevel4_92 BIT, @Old_StakeLevel5_92 BIT
		
DECLARE @CustSetting TABLE (custid INT, gametype INT, stakelevel1 BIT, stakelevel2 BIT, stakelevel3 BIT, stakelevel4 BIT, stakelevel5 BIT)  


SELECT @Old_StakeLevel1_91=stakelevel1, 
		@Old_StakeLevel2_91=stakelevel2, 
		@Old_StakeLevel3_91=stakelevel3, 
		@Old_StakeLevel4_91=stakelevel4, 
		@Old_StakeLevel5_91=stakelevel5
FROM P2PGameSetting p WITH(nolock) WHERE custid=@custid AND bettype=91

SELECT @Old_StakeLevel1_92=stakelevel1, 
		@Old_StakeLevel2_92=stakelevel2, 
		@Old_StakeLevel3_92=stakelevel3, 
		@Old_StakeLevel4_92=stakelevel4, 
		@Old_StakeLevel5_92=stakelevel5
FROM P2PGameSetting p WITH(nolock) WHERE custid=@custid AND bettype=92

SELECT @UplineID=recommend FROM CustInfo (nolock) WHERE custid=@custid

IF	@Old_StakeLevel1_91 = @StakeLevel1_91 AND
	@Old_StakeLevel2_91 = @StakeLevel2_91 AND
	@Old_StakeLevel3_91 = @StakeLevel3_91 AND
	@Old_StakeLevel4_91 = @StakeLevel4_91 AND 
	@Old_StakeLevel5_91 = @StakeLevel5_91 AND
	@Old_StakeLevel1_92 = @StakeLevel1_92 AND
	@Old_StakeLevel2_92 = @StakeLevel2_92 AND
	@Old_StakeLevel3_92 = @StakeLevel3_92 AND
	@Old_StakeLevel4_92 = @StakeLevel4_92 AND 
	@Old_StakeLevel5_92 = @StakeLevel5_92
RETURN


SELECT @Upline_SL1=stakelevel1, @Upline_SL2=stakelevel2, @Upline_SL3=stakelevel3, @Upline_SL4=stakelevel4, @Upline_SL5=stakelevel5
FROM P2PGameSetting p WITH(nolock) WHERE custid=@UplineID AND bettype=91

IF (@Upline_SL1=0 AND @StakeLevel1_91=1) OR (@Upline_SL2=0 AND @StakeLevel2_91=1) OR (@Upline_SL3=0 AND @StakeLevel3_91=1) OR (@Upline_SL4=0 AND @StakeLevel4_91=1) OR (@Upline_SL5=0 AND @StakeLevel5_91=1)
BEGIN
	SELECT @ErrMsg = CASE @Language 
				WHEN 'E' THEN 'You do not have permission to update Game setting'
				WHEN 'CS' THEN N'You do not have permission to update Game setting'
				WHEN 'CT' THEN N'You do not have permission to update Game setting'
				WHEN 'TH' THEN N'You do not have permission to update Game setting'
				WHEN 'J' THEN N'You do not have permission to update Game setting'
				WHEN 'KO' THEN N'You do not have permission to update Game setting'
				ELSE N'You do not have permission to update Game setting'
				END, @ErrCode = 201
	RETURN 
END

INSERT INTO @CustSetting
SELECT @custid, 91, @StakeLevel1_91, @StakeLevel2_91, @StakeLevel3_91, @StakeLevel4_91, @StakeLevel5_91

SELECT @Upline_SL1=stakelevel1, @Upline_SL2=stakelevel2, @Upline_SL3=stakelevel3, @Upline_SL4=stakelevel4, @Upline_SL5=stakelevel5
FROM P2PGameSetting p WITH(nolock) WHERE custid=@UplineID AND bettype=92

IF (@Upline_SL1=0 AND @StakeLevel1_92=1) OR (@Upline_SL2=0 AND @StakeLevel2_92=1) OR (@Upline_SL3=0 AND @StakeLevel3_92=1) OR (@Upline_SL4=0 AND @StakeLevel4_92=1) OR (@Upline_SL5=0 AND @StakeLevel5_92=1)
BEGIN
	SELECT @ErrMsg = CASE @Language 
				WHEN 'E' THEN 'You do not have permission to update Game setting'
				WHEN 'CS' THEN N'You do not have permission to update Game setting'
				WHEN 'CT' THEN N'You do not have permission to update Game setting'
				WHEN 'TH' THEN N'You do not have permission to update Game setting'
				WHEN 'J' THEN N'You do not have permission to update Game setting'
				WHEN 'KO' THEN N'You do not have permission to update Game setting'
				ELSE N'You do not have permission to update Game setting'
				END, @ErrCode = 202
	RETURN 
END

INSERT INTO @CustSetting
SELECT @custid, 92, @StakeLevel1_92, @StakeLevel2_92, @StakeLevel3_92, @StakeLevel4_92, @StakeLevel5_92


-- Update Member
UPDATE P2PGameSetting WITH (ROWLOCK, UPDLOCK)
SET stakelevel1=c.stakelevel1, stakelevel2=c.stakelevel2, stakelevel3=c.stakelevel3, stakelevel4=c.stakelevel4,stakelevel5=c.stakelevel5
FROM P2PGameSetting p
	INNER JOIN @CustSetting c on p.bettype=c.gametype
WHERE p.custid=@custid


DECLARE @LogSPData VARCHAR(5000)
DECLARE @TrackingValue2 VARCHAR(5000)

SELECT @LogSPData = '<Acc_CustomerUpdMember_P2PGameSetting custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +
'stakelevel1_91="'+ coalesce(cast(@stakelevel1_91 as varchar(50)),space(1)) + '" ' +
'stakelevel2_91="'+ coalesce(cast(@stakelevel2_91 as varchar(50)),space(1)) + '" ' +
'stakelevel3_91="'+ coalesce(cast(@stakelevel3_91 as varchar(50)),space(1)) + '" ' +
'stakelevel4_91="'+ coalesce(cast(@stakelevel4_91 as varchar(50)),space(1)) + '" ' +
'stakelevel5_91="'+ coalesce(cast(@stakelevel5_91 as varchar(50)),space(1)) + '" ' +
'stakelevel1_92="'+ coalesce(cast(@stakelevel1_92 as varchar(50)),space(1)) + '" ' +
'stakelevel2_92="'+ coalesce(cast(@stakelevel2_92 as varchar(50)),space(1)) + '" ' +
'stakelevel3_92="'+ coalesce(cast(@stakelevel3_92 as varchar(50)),space(1)) + '" ' +
'stakelevel4_92="'+ coalesce(cast(@stakelevel4_92 as varchar(50)),space(1)) + '" ' +
'stakelevel5_92="'+ coalesce(cast(@stakelevel5_92 as varchar(50)),space(1)) + '" ' +
'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1)) + '" ' +
'SubAccName="'+ coalesce(cast(dbo.f_GetSubUsername(@SubAccID) as varchar(30)),space(1)) + '" ' +
'Language="'+ coalesce(cast(@Language as varchar(2)),space(1)) + '" ' +
'IP="'+ coalesce(cast(@IP as varchar(40)),space(1)) + '" ' +
'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(5000)),space(1))+ '" />'

SELECT @TrackingValue2 = '<Acc_CustomerUpdMember_P2PGameSetting custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +
'stakelevel1_91="'+ coalesce(cast(@Old_stakelevel1_91 as varchar(50)),space(1)) + '" ' +
'stakelevel2_91="'+ coalesce(cast(@Old_stakelevel2_91 as varchar(50)),space(1)) + '" ' +
'stakelevel3_91="'+ coalesce(cast(@Old_stakelevel3_91 as varchar(50)),space(1)) + '" ' +
'stakelevel4_91="'+ coalesce(cast(@Old_stakelevel4_91 as varchar(50)),space(1)) + '" ' +
'stakelevel5_91="'+ coalesce(cast(@Old_stakelevel5_91 as varchar(50)),space(1)) + '" ' +
'stakelevel1_92="'+ coalesce(cast(@Old_stakelevel1_92 as varchar(50)),space(1)) + '" ' +
'stakelevel2_92="'+ coalesce(cast(@Old_stakelevel2_92 as varchar(50)),space(1)) + '" ' +
'stakelevel3_92="'+ coalesce(cast(@Old_stakelevel3_92 as varchar(50)),space(1)) + '" ' +
'stakelevel4_92="'+ coalesce(cast(@Old_stakelevel4_92 as varchar(50)),space(1)) + '" ' +
'stakelevel5_92="'+ coalesce(cast(@Old_stakelevel5_92 as varchar(50)),space(1)) + '" ' +
'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1)) + '" ' +
'SubAccName="'+ coalesce(cast(dbo.f_GetSubUsername(@SubAccID) as varchar(30)),space(1)) + '" ' +
'Language="'+ coalesce(cast(@Language as varchar(2)),space(1)) + '" ' +
'IP="'+ coalesce(cast(@IP as varchar(40)),space(1)) + '" ' +
'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(5000)),space(1))+ '" />'

SET @endRun = getdate()
SET @duration  = datedIFf (millisecond,@startRun,@endRun)
--Log customer info 
EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
	@UserID = @UserID,
	@CustID = @CustID,
	@ActionID = 354,
	@TrackingValue = @LogSPData,
	@TrackingValue2 = @TrackingValue2,
	@duration = @duration
	
GO
GRANT EXECUTE ON [dbo].[Acc_CustomerUpdMember_P2PGameSetting] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_CustomerUpdMember_P2PGameSetting] TO [bodbDownlineNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CustomerUpdMember_P2PGameSetting] TO vnteam


