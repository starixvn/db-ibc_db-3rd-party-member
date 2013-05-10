USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_P2P_GameDetailsUpd]    Script Date: 10/10/2012 04:00:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Dot_P2P_GameDetailsUpd] 
	@CustID				INT,  	
	@TableID			NVARCHAR(10),
	@SessionID			NVARCHAR(50),
	@Turnover			MONEY = 0,
	@Winlost			MONEY = 0,
	@TotalRake			SMALLMONEY = 0,
	@IBC_comm			SMALLMONEY = 0,
	@Player_comm		MONEY = 0,
	@IP					NVARCHAR(15)='',
	@GameID				NVARCHAR(50)='',
	@TourTransType		TINYINT =  0,
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(200) = '' OUTPUT
AS
/*
Creator : Amy
Date : 2011-02-10
Task : Update game details into table bettrans when member exits game table
DB: DBTrans.bodb02

Revisions:
	-20110409@Tim :fix calculation of @IBC_comm
	-20110412@Tim :remove calculation of @IBC_comm. b/c no need. the value pass in is ok
	-20110530@Amy :remove update winlostdate in bettransm (this will be updated when member transfers credit back IBC)
	-20120827@Tim :add @gameID (store in betcheck) check so don't update duplicated table session values.
	-20120829@Tim :add @TourTransType check. if tournament action is register (1) then gameID = 0. so need to allow it to update

Param's Explanation:

- @CustID: member custid    
- @TableID: tableID which member played game
- @SessionID: current session ID which member plays game
- @Turnover: member turnover in game table
- @Winlost: Member Winlost in game table session id when member login to play P2P
			@Winlost > @Turnover: member WON
			@Winlost < @Turnover: member LOSE
			@Winlost = @Turnover: member DRAW
- @IBC_comm: Commission which IBC is received in game table
- @Player_comm: Commission which Member is received in game table
- @GameID: unique game id in p2p. 
- @TourTransType: tournament action. only when tournament will pass in this value. otherwise will not pass
		1: register
		2: unRegister
		3: rebuy
		4: addon
		5: refund
		6: payout

- @ErrCode:
	= 0: Transaction recorded successfully.
	> 0: Specific Error.
	
- @ErrMsg: Error description.
*/

SET NOCOUNT ON

DECLARE @DBplayer_comm MONEY, @acomm MONEY, @mcomm MONEY, @scomm MONEY
DECLARE @Mem_statusID INT, @Mem_status NVARCHAR(10)
DECLARE @refno BIGINT, @winlostdate DATETIME
DECLARE @srecommend	INT
SELECT @ErrMsg = '' ,  @ErrCode=0

IF @Turnover < 0 OR @Winlost < 0 
BEGIN
	SELECT @ErrMsg = 'Sorry, amount is invalid.', @ErrCode = 101	
	RETURN
END

-- check the transfer transaction existed
SELECT @refno=refno, @srecommend = srecommend
FROM bettrans WITH (NOLOCK)
WHERE custId = @custid AND bettype = 23101 AND ruben = 0 AND betcheck=@sessionId

IF @refno IS NULL
	BEGIN
		SELECT @ErrMsg = 'There is NO running P2P transfer transaction (match with the session/refno)', @ErrCode = 102
		RETURN
	END

IF NOT EXISTS (SELECT 1 FROM custInfo WITH (NOLOCK)
				WHERE custId=@custid)
	BEGIN
		SELECT @ErrMsg = 'There is NO valid account user', @ErrCode = 103
		RETURN
	END

IF (EXISTS (select 1 FROM bettransm WITH (NOLOCK)
			WHERE  custId=@CustID AND refno=@refno AND betcheck = @GameID AND ruben = 1) AND @TourTransType =0)
	BEGIN
		SELECT @ErrMsg = 'Duplicated Table Session', @ErrCode = 107
		RETURN
	END 

-- check there is running transaction of game detail
SELECT @DBplayer_comm = @TotalRake * ISNULL(playerdiscount,0),
		@acomm = @TotalRake * ISNULL(discount,0),
		@mcomm = @TotalRake * ISNULL(adiscount,0),
		@scomm = @TotalRake * ISNULL(sdiscount,0)
FROM bettransm WITH (NOLOCK)
WHERE custId=@CustID AND refno=@refno AND betteam=@TableID AND statusID=0 

IF @DBplayer_comm IS NULL
	BEGIN
		SELECT @ErrMsg = 'There is NO running game detail (match with TableID)', @ErrCode = 104
		RETURN
	END	
-- 2012-6-11 Tim: marked out to prevent precision problem cause the flow to break (temp)
/*IF @DBplayer_comm <> @Player_comm
	BEGIN
		SELECT @ErrMsg = 'There is INVALID commission setting', @ErrCode = 105
		RETURN
	END	
*/
-- 2012-03-26 Tim:Rake that ibc gets need to calculate from ibc site. p2p don't have that value
-- 2012-04-09 Tim: p2p pass in @IBC_com = total rake licensee. thus need to do below calculation
-- 2012-04-12 Tim: remove ibc_comm calculation
/*
SELECT @IBC_comm = CASE WHEN @srecommend < 100 
							THEN @IBC_comm - @DBplayer_comm - @acomm
						ELSE @IBC_comm - @DBplayer_comm - @acomm - @mcomm
						END
*/
SELECT @Mem_status = CASE WHEN @Winlost > @Turnover THEN 'WON'
						  WHEN @Winlost < @Turnover THEN 'LOSE'
						  ELSE 'DRAW' END 

SELECT @Mem_statusID = CASE WHEN @Winlost > @Turnover THEN 112
						  WHEN @Winlost < @Turnover THEN 113
						  ELSE 111 END

SELECT @winlostdate = CONVERT(NVARCHAR(10), CURRENT_TIMESTAMP, 120)
						  
UPDATE dbo.bettransm WITH (ROWLOCK, UPDLOCK)
SET
	stake=@turnover,
	winlost=@Winlost, 
	betcheck = @GameID,
	playercomm=@Player_comm,
	comm=@acomm,
	acomm=@mcomm,
	scomm=@scomm, 
	odds=@IBC_comm,
	oddsspread=@TotalRake,
	status=@Mem_status,
	statusID=@Mem_statusID,
	ruben=1	
WHERE custId=@CustID AND statusID=0 AND refno=@refno AND betteam=@TableID

IF (@@Rowcount =0 OR @@ERROR <> 0)
BEGIN
	SELECT @ErrMsg = 'Update game detail transaction fail', @ErrCode = 106	
	RETURN
END

DECLARE @LogData NVARCHAR(300)

SELECT @LogData = 'P2P Bet detail: SessionID = ' + CONVERT(NVARCHAR(20),@sessionId)  
					 + ', TableID = ' + CONVERT(NVARCHAR(10),@TableID)
					 + ', Turnover = ' + CONVERT(NVARCHAR(10),@Turnover)
					 + ', WinLost = ' + CONVERT(NVARCHAR(10),@Winlost)
					 + ', Betcheck = ' + CONVERT(NVARCHAR(50),@GameID)
					 + ', TotalRake = ' + CONVERT(NVARCHAR(10),@TotalRake)
					 + ', playerComm = ' + CONVERT(NVARCHAR(10),@Player_comm) 
					 + ', IBCcomm = ' + CONVERT(NVARCHAR(10),@IBC_comm) 					 
					 + ', IP = '+ @ip 

BEGIN TRY
	EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData
END TRY
BEGIN CATCH
	-- if write log error: not return error code
END CATCH

