 ALTER PROCEDURE [dbo].[Dot_P2P_GamesIns] 
	@custid				int,  	
	@P2P_playerdiscount		smallmoney = 0 OUTPUT,	
	@sessionId			bigint = 0,
	@bettype			bigint,
	@tableId			int,	
	@ip					nvarchar(15)='',	
	@ErrCode			int = 0 OUTPUT,
	@ErrMsg				nvarchar(200) = '' OUTPUT
AS
/*
Creator : Amy
Date : 2011-02-10
Task : Insert transaction into table bettrans when member play in game table
		to record the agency comm setting
DB: DB02.bodb02

Revisions:

Param's Explanation:

• @custid: member custid    
• @P2P_playerdiscount: return the player discount to record in P2P DB
• @sessionId: session id when member login to play P2P
• @bettype: 91 for 13 cards, 92 for Hold'em
• @tableId: store in matchid(bettransm) column to keep tableID for settlement

• @ErrCode:
	= 0: Transaction recorded successfully.
	> 0: Specific Error.
	
• @ErrMsg: Error description.
*/
SET NOCOUNT ON

DECLARE @playerdiscount decimal(9,8), @adiscount decimal(9,8), @mdiscount decimal(9,8), @sdiscount decimal(9,8)
DECLARE @srecommend int, @mrecommend int, @recommend int
DECLARE @refno bigint

-- check the transfer transaction existed
SELECT @refno=refno FROM bettrans WITH (nolock)
				WHERE custid = @custid AND bettype = 23101 AND ruben = 0 AND betid=@sessionId

IF @refno =0
	BEGIN
		SELECT @ErrMsg = 'There is NO running P2P transfer transaction (match with the session/refno)', @ErrCode = 103	
		RETURN
	END

IF NOT EXISTS (SELECT 1 FROM custinfo WITH (nolock)
				WHERE custid=@custid)
	BEGIN
		SELECT
			@ErrMsg = 'There is NO valid account user', @ErrCode = 105	
		RETURN
	END

-- get commission setting
SELECT @playerdiscount = playerdiscount, @adiscount = discount, @mdiscount=adiscount, @sdiscount=sdiscount
FROM custsetting3rd WITH (nolock)
WHERE custid=@custid and bettype = @bettype and sporttype=253

-- Insert transaction into bettransm
DECLARE @eventdate SMALLDATETIME
SET @eventdate=CONVERT(varchar(10), CURRENT_TIMESTAMP, 120)

INSERT INTO dbo.bettransm
	(custid, oddsid, hdp1, hdp2, odds, stake, status,
	livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus,
	winlostdate, betfrom, matchid, matchdate, statuswinlost, ruben, bettype,
	apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, oddsspread,
	playerdiscount, discount, adiscount, sdiscount,
	winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, finalodds, -- keep bet 43, win source odds
	statusID
	) VALUES
	(
	@custid, 0, 0, 0, 0, 0, N'running',
	0, 0, 0, '', @custid, @refno, @refno,
	Null, 'i', @tableId, @eventdate, 0, 0, @bettype,
	0, 0, 0, 0, 0, @playerdiscount, @adiscount, @mdiscount, @sdiscount,
	0, 0, 0, 0, 0, 0, 0, 0, 0, --win odds
	0)

IF (@@rowcount =0 or @@error <> 0)
BEGIN
	SELECT @ErrMsg = 'Insert game transaction fail', @ErrCode = 106	
	RETURN
END

SELECT @P2P_playerdiscount = @playerdiscount
			
-- write log for transaction
DECLARE @LogData nvarchar(300)

SELECT @LogData = 'P2P Betting custid = ' + convert(nvarchar(20), @custid) + ', bettype = '+ @bettype  
					 + ', refNo = ' + convert(nvarchar(20),@refno)  +', '+ 'playerdiscount = ' + convert(nvarchar(10),@playerdiscount) 
					 + 'Super discount = ' + convert(nvarchar(10),@sdiscount) 
					 + 'Master discount = ' + convert(nvarchar(10),@mdiscount) 
					 + 'Agent discount = ' + convert(nvarchar(10),@adiscount) 
					 + ', IP = '+ @ip 

BEGIN TRY
	EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData
END TRY
BEGIN CATCH
	-- if write log error: not return error code
END CATCH
			
GO
GRANT EXECUTE ON [dbo].[Dot_P2P_GamesIns] TO [Dot_Member]
--GO
--GRANT EXECUTE ON [dbo].[Dot_P2P_GamesIns] TO [Dot_P2P]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_P2P_GamesIns] TO [vnteam]