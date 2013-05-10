ALTER PROCEDURE [dbo].[DBA_Bingo_UpdTicket]
    @CustID INT = 0,--IBCcustID
    @refno BIGINT,
    @sessionID BIGINT,

    @BI_Turnover            MONEY = 0,
    @BI_winlost             MONEY = 0,
    @BI_swinlost            MONEY = 0,
    @BI_mwinlost            MONEY = 0,
    @BI_awinlost            MONEY = 0,
    @BI_scomm               MONEY = 0,
    @BI_mcomm               MONEY = 0,
    @BI_acomm               MONEY = 0,
    @BI_playercomm          MONEY = 0,

    @transdesc				NVARCHAR(300)='',   
    @IP						NVARCHAR(15)='',
    @ErrCode				INT = 0 OUTPUT,
    @ErrMsg					NVARCHAR(200) = '' OUTPUT
AS
/*
Creator : Tommy
Date : 2009-11-17
Task : Update winlost/Comm for Bingo Ticket.
DB: DBTRANS.bodb02

History:
	- 20100507@Henry: Update Column StatusID of bettrans table
	- 20110628@Sophia: Update balance 
	- 20120412@Sophia: Revise credit/debit balance
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
IF EXISTS(SELECT 1 FROM dbo.bettrans14 (NOLOCK) WHERE refno = @refno AND bettype =73 AND matchid = 0 AND custid = @CustID)
BEGIN
    IF Exists(SELECT 1 FROM dbo.bettrans (NOLOCK) WHERE refno = @refno AND bettype =73 AND matchid = 0 AND custid = @CustID)
    BEGIN
        SELECT @ErrCode = 108, @ErrMsg = 'Existing transactions in both bettrans and bettrans14!'
        SELECT @ErrCode AS ErrCode, @ErrMsg AS ErrMsg
        RETURN
    END

    DECLARE @Username VARCHAR(30), @bf_balance MONEY, @at_balance MONEY, @balance MONEY
    SELECT @Username = username FROM custinfo (NOLOCK) WHERE custid = @custid
    SELECT
        @BI_Turnover = stake - @BI_Turnover,
        @BI_winlost = winlost - @BI_winlost,
        @BI_swinlost = swinlost - @BI_swinlost,
        @BI_mwinlost = mwinlost - @BI_mwinlost,
        @BI_awinlost = awinlost - @BI_awinlost,
        @BI_scomm = scomm - @BI_scomm,
        @BI_mcomm = acomm - @BI_mcomm,
        @BI_acomm = comm - @BI_acomm,
        @BI_playercomm = playercomm - @BI_playercomm,
        @transdesc = transdesc + 'Correction - ' + CAST(@username AS VARCHAR(30)) + ' transfer Credit back to Sportsbook.'
    FROM dbo.bettrans14 (NOLOCK)
    WHERE refno = @refno AND bettype =73 AND matchid = 0 AND custid = @CustID
   
    --Call sp insert ticket(correct data)
    EXEC dbo.Dot_Bingo_BetIns_Adjustment
        @custid = @custid,
        @BI_Turnover = @BI_Turnover,
        @BI_Winlost = @BI_winlost,
        @BI_swinlost = @BI_swinlost,
        @BI_mwinlost = @BI_mwinlost,
        @BI_awinlost = @BI_awinlost,
        @BI_scomm = @BI_scomm,
        @BI_mcomm = @BI_mcomm,
        @BI_acomm = @BI_acomm,
        @BI_playercomm = @BI_playercomm,

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
ELSE IF EXISTS(SELECT 1 FROM dbo.bettrans(NOLOCK) WHERE refno = @refno AND bettype =73 AND matchid = 0 AND custid = @custid)
BEGIN
    CREATE TABLE #tmp_Bingo(
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
        [pendingcount] [INT] NULL
    )

    INSERT INTO #tmp_Bingo(
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
        [playercomm])
    SELECT @sessionID,
        @refno,
        @custid,
        @BI_Turnover,   
        @BI_winlost,
        @BI_swinlost,
        @BI_mwinlost,
        @BI_awinlost,
        @BI_scomm,
        @BI_mcomm,
        @BI_acomm,
        @BI_playercomm

				
	--Get data before update 
	SELECT  @bf_balance = SUM (b.winlost - b.actual_stake + b.playercomm)
	FROM	dbo.bettrans b WITH (NOLOCK)
	WHERE	b.refno =@refno AND b.matchid = 0 AND b.bettype =73 AND b.CustID = @CustID
		
	---get data after update
	SELECT	@at_balance =  SUM ( CASE WHEN b.custid = cs.[ibccustid] THEN cs.winlost ELSE cs.turnover END  
						   - CASE WHEN b.custid = cs.[ibccustid] THEN cs.turnover ELSE cs.winlost END
						   + (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.playercomm )
	FROM	dbo.bettrans b WITH (NOLOCK)
	INNER JOIN	#tmp_Bingo cs WITH (NOLOCK)  
			ON b.refno = cs.refno AND b.matchid = 0 AND b.bettype =73 and b.custid = @custid
	
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
        playercomm = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.playercomm  
    FROM	dbo.bettrans b WITH(ROWLOCK,UPDLOCK)
	INNER JOIN	#tmp_Bingo (NOLOCK) cs ON b.refno = cs.refno AND b.matchid = 0 AND b.bettype =73

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
        playercomm = (CASE WHEN b.custid = cs.[ibccustid] THEN 1 ELSE -1 END) * cs.playercomm  
    FROM	dbo.bettrans2 b WITH(ROWLOCK,UPDLOCK)
	INNER JOIN	#tmp_Bingo (NOLOCK) cs ON b.refno = cs.refno AND b.matchid = 0 AND b.bettype =73
*/
END
ELSE
BEGIN
    SELECT @ErrCode = 106,
        @ErrMsg    = 'Transaction does not exists!'
        
END

SELECT @ErrCode AS ErrCode, @ErrMsg AS ErrMsg
 
GO
GRANT VIEW DEFINITION ON [dbo].[DBA_Bingo_UpdTicket] TO [vnteam]
