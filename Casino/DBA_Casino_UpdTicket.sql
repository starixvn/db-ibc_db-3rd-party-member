ALTER PROCEDURE [dbo].[DBA_Casino_UpdTicket]
    @CustID INT = 0,--IBCcustID
    @refno BIGINT,
    @sessionID BIGINT,

    @CS_Turnover            MONEY = 0,
    @CS_winlost                MONEY = 0,
    @CS_swinlost            MONEY = 0,
    @CS_mwinlost            MONEY = 0,
    @CS_awinlost            MONEY = 0,
    @CS_scomm                MONEY = 0,
    @CS_mcomm                MONEY = 0,
    @CS_acomm                MONEY = 0,
    @CS_playercomm            MONEY = 0,
    
    @CS_sposition			SMALLMONEY =0,
    @CS_mposition			SMALLMONEY =0,
    @CS_aposition			SMALLMONEY =0,

    @transdesc            NVARCHAR(300)='',   
    @IP                    NVARCHAR(15)='',
    @ErrCode            INT = 0 OUTPUT,
    @ErrMsg                NVARCHAR(200) = '' OUTPUT
AS
/*
Creator : Tommy
Date : 2009-11-17
Task : Update winlost/Comm for casino Ticket.
DB: DBTRANS.bodb02

History:
	- 20100507@Henry: Update Column StatusID of bettrans table
	- 20110916@Amy: Modify SP to correct Casino Position taking
	- 20110628@Sophia: Update credit/debit balance 
	- 20120412@Sophia: Revise credit/debit balance
	- 20120521@Lukas: modify SP to calculate adjusment amounts correctly
	- 20120523@Lukas: including update dummy balance transaction in bettrans2
	- 20120927@Elodie: No need to add dummy transaction into bettrans and backup table (bettrans2)
Param's Explanation:

• @ErrCode:
    = 0: Transaction recorded successfully.
    > 0: Specific Error.
   
• @ErrMsg: Error description.

*/
SET NOCOUNT ON

--Check exists bettrans14
IF EXISTS(SELECT 1 FROM dbo.bettrans14 (NOLOCK) WHERE refno = @refno AND bettype IN (71,72) AND matchid = 0 AND custid = @CustID)
BEGIN
    IF Exists(SELECT 1 FROM dbo.bettrans (NOLOCK) WHERE refno = @refno AND bettype IN (71,72) AND matchid = 0 AND custid = @CustID)
    BEGIN
        SELECT @ErrCode = 108, @ErrMsg = 'Existing transactions in both bettrans and bettrans14!'
        SELECT @ErrCode AS ErrCode, @ErrMsg AS ErrMsg
        RETURN
    END

    DECLARE @Username VARCHAR(30), @bf_balance MONEY, @at_balance MONEY, @balance MONEY
    SELECT @Username = username FROM custinfo (NOLOCK) WHERE custid = @custid
    SELECT
        @CS_Turnover = @CS_Turnover - stake,
        @CS_winlost = @CS_winlost - winlost,
        @CS_swinlost = @CS_swinlost - swinlost,
        @CS_mwinlost = @CS_mwinlost - mwinlost,
        @CS_awinlost = @CS_awinlost - awinlost,
        @CS_scomm = @CS_scomm - scomm,
        @CS_mcomm = @CS_mcomm - acomm,
        @CS_acomm = @CS_acomm - comm,
        @CS_playercomm = @CS_playercomm - playercomm,
        @transdesc = transdesc + 'Correction - ' + CAST(@username AS VARCHAR(30)) + ' transfer Credit back to Sportsbook.'
    FROM dbo.bettrans14 (NOLOCK)
    WHERE refno = @refno AND bettype IN (71,72) AND matchid = 0 AND custid = @CustID
   
    --Call sp insert ticket(correct data)
        EXEC dbo.DOT_Casino_BetIns_Adjustment
        @custid = @custid,
        @CS_Turnover = @CS_Turnover,
        @CS_Winlost = @CS_winlost,
        @CS_swinlost = @CS_swinlost,
        @CS_mwinlost = @CS_mwinlost,
        @CS_awinlost = @CS_awinlost,
        @CS_scomm = @CS_scomm,
        @CS_mcomm = @CS_mcomm,
        @CS_acomm = @CS_acomm,
        @CS_playercomm = @CS_playercomm,

        @refno = @refno,
        @sessionId = @sessionId,
        @transdesc = @transdesc,
        @ErrCode = @ErrCode OUTPUT,
        @ErrMsg = @ErrMsg OUTPUT
        ---------------------------------
        SELECT
        @ErrCode AS ErrCode,
        @ErrMsg AS ErrMsg

    RETURN
END--Check exists bettraNS
ELSE IF EXISTS(SELECT 1 FROM dbo.bettrans(NOLOCK) WHERE refno = @refno AND bettype IN (71,72) AND matchid = 0 AND custid = @custid)
BEGIN
    CREATE TABLE #tmp_casino(
        [sessionID] [INT] NULL,
        [refno] [BIGINT] NULL,
        [ibccustid] [INT] NULL,
        [turnover] [MONEY] NULL,
        [totalWL] [MONEY] NULL,
        [winlost] [MONEY] NULL,
        [housewinlost] [MONEY] NULL,
        [swinlost] [MONEY] NULL,
        [mwinlost] [MONEY] NULL,
        [awinlost] [MONEY] NULL,
        [scomm] [MONEY] NULL,
        [acomm] [MONEY] NULL,
        [comm] [MONEY] NULL,
        [playercomm] [MONEY] NULL,
        [pendingcount] [INT] NULL,
        [sposition] [SMALLMONEY] NULL,
        [mposition] [SMALLMONEY] NULL,
        [aposition] [SMALLMONEY] NULL,
        [tposition] [SMALLMONEY] NULL
        
    )

    INSERT INTO #tmp_casino(
        [sessionID],
        [refno],
        [ibccustid],
        [turnover],
        [winlost],
        [swinlost],
        [mwinlost],
        [awinlost],
        [scomm],
        [acomm],
        [comm],
        [playercomm],
		[sposition],
		[mposition],
		[aposition],          
		[tposition]
        )
    SELECT @sessionID,
        @refno,
        @custid,
        @CS_Turnover,   
        @CS_winlost,
        @CS_swinlost,
        @CS_mwinlost,
        @CS_awinlost,
        @CS_scomm,
        @CS_mcomm,
        @CS_acomm,
        @CS_playercomm,
		@CS_sposition,
		@CS_mposition,
		@CS_aposition,
		@CS_sposition + @CS_mposition + @CS_aposition		       
 
   
 
	--Get data before update
	SELECT	@bf_balance =  SUM (b.winlost - b.actual_stake + b.playercomm) 
	FROM	dbo.bettrans b WITH (NOLOCK)
	WHERE	b.refno =@refno AND b.matchid = 0 AND b.bettype IN (71,72) AND b.CustID = @CustID     

	
	---get data after update
	SELECT	@at_balance =  SUM ( CASE WHEN b.custid = cs.[ibccustid] THEN cs.winlost ELSE cs.turnover END
						   - CASE WHEN b.custid = cs.[ibccustid] THEN cs.turnover ELSE cs.winlost END
						   + (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.playercomm )
	 FROM dbo.bettrans b WITH (NOLOCK)
        INNER JOIN #tmp_casino cs WITH (NOLOCK) ON b.refno = cs.refno AND b.matchid = 0 AND b.bettype IN (71,72) and b.custid = @custid
		
	---update debit balance
	SELECT @balance = @bf_balance - @at_balance
	IF @balance > 0
	BEGIN 
		EXEC Dot_BalanceUpdDebit @CustID = @CustID, @balance = @balance 
	END 
	
    --Update exitsting ticket
    UPDATE b
    SET stake = CASE WHEN b.custid = cs.[ibccustid] THEN cs.turnover ELSE cs.winlost END,
        winlost = CASE WHEN b.custid = cs.[ibccustid] THEN cs.winlost ELSE cs.turnover END,
        actual_stake = CASE WHEN b.custid = cs.[ibccustid] THEN cs.turnover ELSE cs.winlost END,
        status = CASE WHEN b.custid = cs.[ibccustid] THEN 
                            CASE WHEN cs.winlost - cs.turnover > 0 THEN 'WON'
                                 WHEN cs.winlost - cs.turnover < 0 THEN 'LOSE'
                                 ELSE 'DRAW' END
                 ELSE 'DONE' END,
        statusID = CASE WHEN b.custid = cs.[ibccustid] THEN 
                            CASE WHEN cs.winlost - cs.turnover > 0 THEN 112
                                 WHEN cs.winlost - cs.turnover < 0 THEN 113
                                 ELSE 111 END
                 ELSE 121 END,
        transdesc = transdesc + @transdesc,
        swinlost = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.swinlost,
        mwinlost = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.mwinlost,
        awinlost = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.awinlost,
        scomm = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.scomm,
        acomm = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.acomm,
        comm = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.comm,
        playercomm = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.playercomm,
        spositiontaking = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE 0 END) * cs.sposition,
        mpositiontaking = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE 0 END) * cs.mposition,
        apositiontaking = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE 0 END) * cs.aposition,
        tpositiontaking = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE 0 END) * cs.tposition    
        
    FROM dbo.bettrans b WITH(ROWLOCK,UPDLOCK)
        INNER JOIN #tmp_casino (NOLOCK) cs ON b.refno = cs.refno AND b.matchid = 0 AND b.bettype IN (71,72)
        
    IF @@ERROR <> 0
    BEGIN
        SELECT @ErrCode = 106,   
            @ErrMsg    = 'Error occurs.Update unsuccessfully.'
        --revert balance
        IF @balance > 0
		BEGIN 
			EXEC Dot_BalanceUpdCredit @CustID = @CustID, @balance = @balance 
		END   
    END
    ELSE
    BEGIN
  
        SELECT @ErrCode = 0,
            @ErrMsg    = 'Update successfully!'
    END
---- 20120927@Elodie: No need to add dummy transaction into bettrans and backup table (bettrans2)
/*
	--Update exitsting dummy balance transaction in bettrans2
    UPDATE b
    SET stake = CASE WHEN b.custid = cs.[ibccustid] THEN cs.turnover ELSE cs.winlost END,
        winlost = CASE WHEN b.custid = cs.[ibccustid] THEN cs.winlost ELSE cs.turnover END,
        actual_stake = CASE WHEN b.custid = cs.[ibccustid] THEN cs.turnover ELSE cs.winlost END,
        status = CASE WHEN b.custid = cs.[ibccustid] THEN 
                            CASE WHEN cs.winlost - cs.turnover > 0 THEN 'WON'
                                 WHEN cs.winlost - cs.turnover < 0 THEN 'LOSE'
                                 ELSE 'DRAW' END
                 ELSE 'DONE' END,
        statusID = CASE WHEN b.custid = cs.[ibccustid] THEN 
                            CASE WHEN cs.winlost - cs.turnover > 0 THEN 112
                                 WHEN cs.winlost - cs.turnover < 0 THEN 113
                                 ELSE 111 END
                 ELSE 121 END,
        transdesc = transdesc + @transdesc,
        swinlost = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.swinlost,
        mwinlost = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.mwinlost,
        awinlost = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.awinlost,
        scomm = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.scomm,
        acomm = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.acomm,
        comm = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.comm,
        playercomm = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.playercomm,
        spositiontaking = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE 0 END) * cs.sposition,
        mpositiontaking = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE 0 END) * cs.mposition,
        apositiontaking = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE 0 END) * cs.aposition,
        tpositiontaking = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE 0 END) * cs.tposition    
        
    FROM dbo.bettrans2 b WITH(ROWLOCK,UPDLOCK)
        INNER JOIN #tmp_casino (NOLOCK) cs ON b.refno = cs.refno AND b.matchid = 0 AND b.bettype IN (71,72)
*/    
 
 ---update credit balance
    IF @balance < 0
	BEGIN 
		SET @balance =  ABS(@balance)
		EXEC Dot_BalanceUpdCredit @CustID = @CustID, @balance = @balance 
	END 
	    
END
ELSE
BEGIN
    SELECT @ErrCode = 106,
        @ErrMsg    = 'Transaction does not exists!'
        
END

GO
GRANT VIEW DEFINITION ON [dbo].[DBA_Casino_UpdTicket] TO [vnteam]