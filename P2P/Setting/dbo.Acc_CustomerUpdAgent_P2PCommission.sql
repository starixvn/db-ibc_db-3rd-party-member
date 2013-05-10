 
ALTER PROCEDURE [dbo].[Acc_CustomerUpdAgent_P2PCommission]
@custid INT,
@discount_1 DECIMAL(9,8),--Comm for Game
@discount_2 DECIMAL(9,8),--Comm for Private Games

@SubAccID INT = 0, --Sub-AccountID
@UserID INT = 0, 
@Language VARCHAR(2) = 'E',
@IP VARCHAR(40)='',
@ErrCode INT = 0 OUTPUT,
@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS
/*
Created: 20110421@Amy
Task : Update Agent's P2P Commission
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

DECLARE @Old_discount_1 DECIMAL(9,8),@Old_discount_2 DECIMAL(9,8)

--Check Param
IF	@discount_1 < 0 OR @discount_1 > 0.67
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
IF	@discount_2 < 0 OR @discount_2 > 0.67
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

SELECT @Old_discount_1= discount
FROM P2PGroupComm WITH (NOLOCK) WHERE CustID = @custid AND GroupID=1

SELECT @Old_discount_2= discount
FROM P2PGroupComm WITH (NOLOCK) WHERE CustID = @custid AND GroupID=2

--Update for Agent

UPDATE P2PGroupComm WITH (ROWLOCK, UPDLOCK)
SET	
	discount = CASE	WHEN GroupID =1 AND ISNULL(@Old_discount_1,0) <> @discount_1 THEN @discount_1 
					WHEN GroupID =2 AND ISNULL(@Old_discount_2,0) <> @discount_2 THEN @discount_2 							
				ELSE discount END
WHERE custid=@custid and GroupID in (1,2)

-- Update for Member level
UPDATE gc WITH (ROWLOCK, UPDLOCK) 
SET	gc.discount = CASE WHEN GroupID =1 THEN @discount_1 
					WHEN GroupID =2 THEN @discount_2 							
					ELSE discount END
FROM P2PGroupComm gc INNER JOIN CustInfo c WITH (NOLOCK) ON gc.CustID=c.CustID
WHERE c.recommend = @custid AND GroupID IN (1,2) AND c.roleid=1

-- Update for Member level update playerdiscount = discount if playerdiscount > discount
UPDATE gc WITH (ROWLOCK, UPDLOCK) 
SET	gc.playerdiscount = gc.discount
FROM P2PGroupComm gc INNER JOIN CustInfo c WITH (NOLOCK) ON gc.CustID=c.CustID
WHERE c.recommend = @custid AND c.roleid=1 AND GroupID IN (1,2) AND gc.playerdiscount > gc.discount
 

DECLARE @LogSPData VARCHAR(5000)
DECLARE @TrackingValue2 VARCHAR(5000)

SELECT @LogSPData = '<Acc_CustomerUpdAgent_P2PCommission custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +
'discount_1="'+ coalesce(cast(@discount_1 as varchar(50)),space(1)) + '" ' +
'discount_2="'+ coalesce(cast(@discount_2 as varchar(50)),space(1)) + '" ' +
'UserID="'+ coalesce(cast(@UserID as varchar(50)),space(1)) + '" ' +
'SubAccName="'+ coalesce(cast(dbo.f_GetSubUsername(@SubAccID) as varchar(30)),space(1)) + '" ' +
'Language="'+ coalesce(cast(@Language as varchar(2)),space(1)) + '" ' +
'IP="'+ coalesce(cast(@IP as varchar(40)),space(1)) + '" ' +
'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(5000)),space(1))+ '" />'

SELECT @TrackingValue2 = '<Acc_CustomerUpdAgent_P2PCommission custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +
'discount_1="'+ coalesce(cast(@old_discount_1 as varchar(50)),space(1)) + '" ' +
'discount_2="'+ coalesce(cast(@old_discount_2 as varchar(50)),space(1)) + '" ' +
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
	@ActionID = 222,
	@TrackingValue = @LogSPData,
	@TrackingValue2 = @TrackingValue2,
	@duration = @duration
	
GO
GRANT EXECUTE ON [dbo].[Acc_CustomerUpdAgent_P2PCommission] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_CustomerUpdAgent_P2PCommission] TO [bodbDownlineNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CustomerUpdAgent_P2PCommission] TO vnteam


