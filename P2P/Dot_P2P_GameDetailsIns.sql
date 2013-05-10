USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_P2P_GameDetailsIns]    Script Date: 10/10/2012 03:59:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Dot_P2P_GameDetailsIns    Script Date: 2/9/2012 3:49:07 PM ******/
ALTER PROCEDURE [dbo].[Dot_P2P_GameDetailsIns] 
	@CustID				INT,  
	@P2P_playerdiscount	SMALLMONEY = 0 OUTPUT,	
	@sessionId			NVARCHAR(50),
	@bettype			BIGINT,
	@GroupCommID		INT,
	@StakeLevelType		VARCHAR(10),
	@TableID			NVARCHAR(10)='',	
	@ip					NVARCHAR(15)='',	
	@ErrCode			INT = 0 OUTPUT,
	@ErrMsg				NVARCHAR(200) = '' OUTPUT
AS
/*
Creator : Amy
Date : 2011-02-10
Task : Insert transaction into table bettrans when member play in game table
		to record the agency comm setting
DB: DBTRANS.bodb02

Revisions:

Param's Explanation:

• @custid: member custid    
• @P2P_playerdiscount: return the player discount to record in P2P DB
• @sessionId: session id when member login to play P2P
• @bettype: 1001 for 13 cards, 1002 for Hold'em
• @GroupCommID: 1 for Games commission group, 2 Private Games commission group
• @StakeLevelType: required to input 'Fun': play for fun, 'Low', 'Medium', 'High', 'Vip'
• @tableId: store in betteam(bettransm) column to keep tableID for settlement

• @ErrCode:
	= 0: Transaction recorded successfully.
	= 102: Invalid Stake Level
	> 0: Specific Error.
	max is: 106
	
• @ErrMsg: Error description.
*/
SET NOCOUNT ON

DECLARE @playerdiscount DECIMAL(9,8), @adiscount DECIMAL(9,8), @mdiscount DECIMAL(9,8), @sdiscount DECIMAL(9,8)
DECLARE @srecommend INT, @mrecommend INT, @recommend INT
DECLARE @refno BIGINT, @stakeLevel BIT

IF @bettype <> 1001 AND @bettype<>1002
BEGIN
	SELECT @ErrMsg = 'Invalid Game type.', @ErrCode = 101
	RETURN
END

--Check stake level
SELECT @stakeLevel=(CASE WHEN @StakeLevelType ='fun' THEN StakeLevel1
						WHEN @StakeLevelType='low' THEN StakeLevel2
						WHEN @StakeLevelType='medium' THEN StakeLevel3
						WHEN @StakeLevelType='high' THEN StakeLevel4
						WHEN @StakeLevelType='vip' THEN StakeLevel5
						WHEN @StakeLevelType='t' THEN StakeLevel1 END)
FROM P2PGameSetting WITH(NOLOCK) 
WHERE custId=@custid AND bettype=@bettype

IF @stakeLevel<>1 
BEGIN
	SELECT @ErrMsg = 'Sorry, you are not allowed to play game with this stake level', @ErrCode = 102
	RETURN
END

-- check the transfer transaction existed
SELECT @refno=refno 
FROM bettrans WITH (NOLOCK)
WHERE custId = @custid AND bettype = 23101 AND ruben = 0 AND betcheck=@sessionId

IF @refno IS NULL
	BEGIN
		SELECT @ErrMsg = 'There is NO running P2P transfer transaction (match with the session/refno)', @ErrCode = 103
		RETURN
	END
-- check valid account 
IF NOT EXISTS (SELECT 1 FROM custInfo WITH (NOLOCK)
				WHERE custId=@custid)
	BEGIN
		SELECT	@ErrMsg = 'There is NO valid account user', @ErrCode = 104
		RETURN
	END

-- check the running game detail
IF EXISTS (SELECT top 1 1 FROM bettransm WITH (NOLOCK)
			WHERE custId=@CustID AND refno=@refno AND betteam=@TableID AND statusID=0)
BEGIN
	SELECT @ErrMsg = 'There is RUNNING Game of this Game Type', @ErrCode = 105	
	RETURN
END

-- get commission setting
SELECT @playerdiscount = playerdiscount, @adiscount = discount, @mdiscount=adiscount, @sdiscount=sdiscount
FROM P2PGroupComm WITH (NOLOCK)
WHERE custId=@custid AND groupID = @GroupCommID

-- Insert transaction into bettransm
DECLARE @eventdate SMALLDATETIME
SET @eventdate=CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

INSERT INTO dbo.bettransm
	(custId, oddsid, hdp1, hdp2, odds, stake, status,
	livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus,
	winlostdate, betfrom, matchid, matchdate, statuswinlost, ruben, bettype,
	apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, oddsspread,
	playerdiscount, discount, adiscount, sdiscount,
	winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, finalodds, 
	statusID
	) VALUES
	(
	@custid, @GroupCommID, 0, 0, 0, 0, N'running',
	0, 0, 0, @TableID, @custid, @refno, @refno,
	NULL, 'i', 1000, @eventdate, 0, 0, @bettype,
	0, 0, 0, 0, 0, @playerdiscount, @adiscount, @mdiscount, @sdiscount,
	0, 0, 0, 0, 0, 0, 0, 0, 0,
	0)

IF (@@Rowcount =0 OR @@ERROR <> 0)
BEGIN
	SELECT @ErrMsg = 'Insert game detail transaction fail', @ErrCode = 106	
	RETURN
END
ELSE
BEGIN
	SELECT @ErrMsg = '', @ErrCode = 0
END

SELECT @P2P_playerdiscount = @playerdiscount
			
-- write log for transaction
DECLARE @LogData NVARCHAR(300)

SELECT @LogData = 'P2P Bet detail: SessionID = ' + CONVERT(NVARCHAR(50),@sessionId)  
			+ ', TableID = ' + CONVERT(NVARCHAR(10),@TableID)
			+ ', bettype = '+ CONVERT(NVARCHAR(10), @bettype)  
			+ ', GroupCommID = ' + CONVERT(NVARCHAR(10),@GroupCommID)
			+ ', playerdiscount = ' + CONVERT(NVARCHAR(10),@playerdiscount)
			+ ', Stakelevel = ' + CONVERT(NVARCHAR(10),@StakeLevelType) 
			+ ', IP = '+ @ip 

BEGIN TRY
	EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData
END TRY
BEGIN CATCH
	-- if write log error: not return error code
END CATCH



