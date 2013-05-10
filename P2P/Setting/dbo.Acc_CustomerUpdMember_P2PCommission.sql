 
ALTER PROCEDURE [dbo].[Acc_CustomerUpdMember_P2PCommission]
@custid INT,
@playerdiscount_1 DECIMAL(9,8),--Comm for Game
@playerdiscount_2 DECIMAL(9,8),--Comm for Private Games

@SubAccID INT = 0, --Sub-AccountID
@UserID INT = 0, 
@Language VARCHAR(2) = 'E',
@IP VARCHAR(40)='',
@ErrCode INT = 0 OUTPUT,
@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: 20110421@Amy
Task : Update Member's P2P Commission
DB: DBTrans.bodb02
Original:

Revisions: 

Param's Explanation:
@ErrCode:
	= 0: Update commission successfully.
	> 0: SpecIFic Error.
	range: 101-102
@ErrMsg: Error description.
*/

SET NOCOUNT ON

DECLARE @startRun DATETIME
DECLARE @endRun DATETIME
DECLARE @duration INT
SET @startRun = getdate()

DECLARE @Old_Playerdiscount_1 DECIMAL(9,8),@Old_Playerdiscount_2 DECIMAL(9,8)

--Check Param
IF	@playerdiscount_1 < 0 OR @playerdiscount_1 > 0.67
BEGIN	
	SELECT @ErrMsg = CASE @Language 
						WHEN 'E' THEN 'Invalid commission rate (Game).'
						WHEN 'CS' THEN N'Invalid commission rate (Game).'
						WHEN 'CT' THEN N'Invalid commission rate (Game).'
						WHEN 'TH' THEN N'Invalid commission rate (Game).'
						WHEN 'J' THEN N'Invalid commission rate (Game).'
						WHEN 'KO' THEN N'Invalid commission rate (Game).'
						ELSE N'Invalid commission rate (Game).'
					END, @ErrCode = 101
	RETURN
END
IF	@playerdiscount_2 < 0 OR @playerdiscount_2 > 0.67
BEGIN	
	SELECT @ErrMsg = CASE @Language 
						WHEN 'E' THEN 'Invalid commission rate (Private Game).'
						WHEN 'CS' THEN N'Invalid commission rate (Private Game).'
						WHEN 'CT' THEN N'Invalid commission rate (Private Game).'
						WHEN 'TH' THEN N'Invalid commission rate (Private Game).'
						WHEN 'J' THEN N'Invalid commission rate (Private Game).'
						WHEN 'KO' THEN N'Invalid commission rate (Private Game).'
						ELSE N'Invalid commission rate (Private Game).'
					END, @ErrCode = 102
	RETURN
END

SELECT @Old_Playerdiscount_1= playerdiscount
FROM P2PGroupComm WITH (NOLOCK) WHERE CustID = @custid AND GroupID=1

SELECT @Old_Playerdiscount_2= playerdiscount
FROM P2PGroupComm WITH (NOLOCK) WHERE CustID = @custid AND GroupID=2

UPDATE P2PGroupComm WITH (ROWLOCK, UPDLOCK)
SET	
	playerdiscount = CASE	WHEN GroupID =1 THEN @playerdiscount_1 
							WHEN GroupID =2 THEN @playerdiscount_2 							
							ELSE playerdiscount END
WHERE custid=@custid and GroupID in (1,2)


DECLARE @LogSPData VARCHAR(5000)
DECLARE @TrackingValue2 VARCHAR(5000)

SELECT @LogSPData = '<Acc_CustomerUpdMember_P2PCommission custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +
'discount_1="'+ coalesce(cast(@playerdiscount_1 as varchar(50)),space(1)) + '" ' +
'discount_2="'+ coalesce(cast(@playerdiscount_2 as varchar(50)),space(1)) + '" ' +
'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1)) + '" ' +
'SubAccName="'+ coalesce(cast(dbo.f_GetSubUsername(@SubAccID) as varchar(30)),space(1)) + '" ' +
'Language="'+ coalesce(cast(@Language as varchar(2)),space(1)) + '" ' +
'IP="'+ coalesce(cast(@IP as varchar(40)),space(1)) + '" ' +
'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(5000)),space(1))+ '" />'

SELECT @TrackingValue2 = '<Acc_CustomerUpdMember_P2PCommission custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +
'discount_1="'+ coalesce(cast(@old_playerdiscount_1 as varchar(50)),space(1)) + '" ' +
'discount_2="'+ coalesce(cast(@old_playerdiscount_2 as varchar(50)),space(1)) + '" ' +
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
	@ActionID = 223,
	@TrackingValue = @LogSPData,
	@TrackingValue2 = @TrackingValue2,
	@duration = @duration
	
GO
GRANT EXECUTE ON [dbo].[Acc_CustomerUpdMember_P2PCommission] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_CustomerUpdMember_P2PCommission] TO [bodbDownlineNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CustomerUpdMember_P2PCommission] TO vnteam


