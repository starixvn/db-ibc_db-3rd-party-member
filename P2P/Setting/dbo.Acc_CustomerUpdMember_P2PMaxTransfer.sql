 
ALTER PROCEDURE [dbo].[Acc_CustomerUpdMember_P2PMaxTransfer]
@custid INT,
@MaxTransfer MONEY,
@IsDailyAutoReset BIT,

@SubAccID INT = 0, --Sub-AccountID
@UserID INT = 0, 
@Language VARCHAR(2) = 'E',
@IP VARCHAR(40)='',
@ErrCode INT = 0 OUTPUT,
@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: 20110421@Amy
Task : Update Agent's P2P Max Transfer limit
DB: DBTrans.bodb02
Original:

Revisions: 

Param's Explanation:
@ErrCode:
	= 0: Update commission successfully.
	> 0: SpecIFic Error.	
	range: 301-303
@ErrMsg: Error description.
*/

SET NOCOUNT ON

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
SET @startRun = getdate()

DECLARE @Old_MaxTransfer MONEY,@Old_IsDailyAutoReset BIT, @MinTransferLimit MONEY, @MaxTransferLimit MONEY, @Roleid INT, @Currency int
DECLARE @UplineIsAutoReset BIT

SELECT @MaxTransferLimit = sa.MaxTransferP2P,
		@Roleid=c.roleid,
		@Currency = sa.currency,
		@UplineIsAutoReset = sa.IsAutoResetP2P
FROM CustInfo c WITH (NOLOCK) 
INNER JOIN CustInfo sa WITH (NOLOCK) ON sa.custid=c.recommend
WHERE c.custid=@custid

SELECT @MinTransferLimit = MinCredit 
FROM P2PDefaultSetting WITH (NOLOCK)
WHERE Currency = @Currency


IF @Roleid <>1
BEGIN
	SELECT @ErrMsg = CASE @Language 
						WHEN 'E' THEN 'Invalid user!!'
						WHEN 'CS' THEN N'账号无效.'
						WHEN 'CT' THEN N'帳號無效.'
						WHEN 'TH' THEN N'ผู้ใช้ไม่ถูกต้อง.'
						WHEN 'J' THEN N'Invalid user!!'
						WHEN 'KO' THEN N'잘못된 사용자 입니다!!'
						ELSE N'Invalid user!!'
					END	,
		@ErrCode = 301	
	RETURN
END

IF @UplineIsAutoReset = 0
BEGIN
	SELECT @ErrMsg = CASE @Language 
						WHEN 'E' THEN 'You are not allowed to change Daily Auto Reset Limit.'
						WHEN 'CS' THEN N'You are not allowed to change Daily Auto Reset Limit.'
						WHEN 'CT' THEN N'You are not allowed to change Daily Auto Reset Limit.'
						WHEN 'TH' THEN N'You are not allowed to change Daily Auto Reset Limit.'
						WHEN 'J' THEN N'You are not allowed to change Daily Auto Reset Limit.'
						WHEN 'KO' THEN N'You are not allowed to change Daily Auto Reset Limit.'
						ELSE N'You are not allowed to change Daily Auto Reset Limit.'
					END	
			,@ErrCode = 303
	RETURN
END

IF @MaxTransfer < @MinTransferLimit or @MaxTransfer > @MaxTransferLimit
BEGIN
	SELECT @ErrMsg = CASE @Language 
						WHEN 'E' THEN 'Max transfer credit must be in range'
						WHEN 'CS' THEN N'Max transfer credit must be in range'
						WHEN 'CT' THEN N'Max transfer credit must be in range'
						WHEN 'TH' THEN N'Max transfer credit must be in range'
						WHEN 'J' THEN N'Max transfer credit must be in range'
						WHEN 'KO' THEN N'Max transfer credit must be in range'
						ELSE N'Max transfer credit must be in range'
					END	
					+ ' '+ CONVERT(VARCHAR(20),@MinTransferLimit) +'-'+ CONVERT(VARCHAR(20),@MaxTransferLimit) 
			,@ErrCode = 302	
	RETURN
END

UPDATE custInfo WITH (UPDLOCK,ROWLOCK)
SET MaxTransferP2P = @MaxTransfer,
	IsAutoResetP2P = @IsDailyAutoReset
WHERE custid = @custid

DECLARE @LogSPData VARCHAR(5000)
DECLARE @TrackingValue2 VARCHAR(5000)

SELECT @LogSPData = '<Acc_CustomerUpdMember_P2PMaxTransfer custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +
'MaxTransfer="'+ coalesce(cast(@MaxTransfer as varchar(50)),space(1)) + '" ' +
'AutoReset="'+ coalesce(cast(@IsDailyAutoReset as varchar(50)),space(1)) + '" ' +
'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1)) + '" ' +
'SubAccName="'+ coalesce(cast(dbo.f_GetSubUsername(@SubAccID) as varchar(30)),space(1)) + '" ' +
'Language="'+ coalesce(cast(@Language as varchar(2)),space(1)) + '" ' +
'IP="'+ coalesce(cast(@IP as varchar(40)),space(1)) + '" ' +
'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(5000)),space(1))+ '" />'

SELECT @TrackingValue2 = '<Acc_CustomerUpdMember_P2PMaxTransfer custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +
'MaxTransfer="'+ coalesce(cast(@Old_MaxTransfer as varchar(50)),space(1)) + '" ' +
'AutoReset="'+ coalesce(cast(@Old_IsDailyAutoReset as varchar(50)),space(1)) + '" ' +
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
	@ActionID = 1215,
	@TrackingValue = @LogSPData,
	@TrackingValue2 = @TrackingValue2,
	@duration = @duration
	
GO
GRANT EXECUTE ON [dbo].[Acc_CustomerUpdMember_P2PMaxTransfer] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_CustomerUpdMember_P2PMaxTransfer] TO [bodbDownlineNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CustomerUpdMember_P2PMaxTransfer] TO vnteam


