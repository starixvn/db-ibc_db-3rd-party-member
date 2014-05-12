ALTER PROCEDURE [dbo].[Dot_Member_InsertBet_LiveCasino_cust]
	@custid int,			-- Customer ID
	-- BetInfo ------------------------------------------
	@matchIdInfo varchar(2000),
	@oddsIdInfo varchar(2000),
	@oddValueInfo varchar(2000),
	@betTeamInfo varchar(2000),
	@StakeInfo varchar(2000),
	-----------------------------------------------------
	@stake money,                   --Total Stake
	@creator nvarchar(50),
	@NumOfBet int, 			
	@BetFrom nvarchar(1)='i',
	@BET_IP nvarchar(20),
	@oddstype tinyint = 2,
	@bettype smallint = 1101,
	@betteam nvarchar(10) = N'',
	@matchId int,  
	@fail bit=0 output,
	@creditcheck nvarchar(10)='',
	@ErrMsg nvarchar(500)='',
	@result nvarchar(50)='',
	@refno bigint=0,
	@transid bigint = 0,
	@transid2 bigint = 0,
	@currency int,
	@actualrate float,
	@recommend int,
	@mrecommend int,
	@srecommend int,
	@oapositiontaking float,
	@ompositiontaking float,
	@ospositiontaking float,
	@sdiscount float,
	@discount float,
	@adiscount float,
	@playerdiscount float,
	@HTTP_REF nvarchar(150),
	@site nvarchar(50),
	@siteid int = 0,
	@ugroup nvarchar(12),
	@matchdate datetime, -- pass from Dot_Member_MathcCheck_LiveCasino
	@DoubleCommLosing bit =0,
	@username nvarchar(50),	--Dot_Member_CustCreditInfo_cust
	@credit Money , 	--Dot_Member_CustCreditInfo_cust
	@MaxWinLiveCasino smallMoney,	--Dot_Member_CustCreditInfo_cust
	@CurrencyName nvarchar(50)	    --Dot_Member_CustCreditInfo_cust
AS
/*	
Task: main SP for Place Bet Live Casino

History:
	--20111209@TWJoe(DBTRANS): Live Casino InsertBet
	--20120309@Victor(DBTRANS): call update balance table SPs
	--20120410@TWJoe(DBTRANS): return (@finalbalance - @stake) or @finalbalance
	--20120515@TWJoe(DBTRANS): rollback return @finalbalance
	--20120618@Victor(DBTRANS): remove check match
	--20121012@TWJoe(DBTRANS):add DoubleCommLosing
	--20121022@Victor(DBTRANS):add MaxWinLimit Check
	--20130808@Victor(DBTrans): virtualrate change store @actualrate
	--20130909@TWJoe(DBTRANS): check @StakeInfo and @stake
	--20130926@TWJoe(DBTRANS): remove custinfo,exchange for custdb
	--20131225@TWJoe(DBTRANS): hotfix sum betstake convert money
	--20140510@Thien: hot fix, amend the SP to include @translogCredit (for Keno product)
*/
SET NOCOUNT ON
BEGIN

----------------------------------------------------------------------------------------------------------
-- Get Customer Info   --   DECLARE @ParlayMatchSetting TABLE (MatchID int, BetType smallint, enable bit, DisplayMode tinyint,OddsID bigint)
----------------------------------------------------------------------------------------------------------
	declare 
		@otpositiontaking float,
		--@custid_get int,
		@eventstatus nvarchar(50),
		@checktime datetime,
		@sumstake money              
		--@virtualrate float				
    set @transid = 0
	set @otpositiontaking = @oapositiontaking + @ompositiontaking + @ospositiontaking

----------------------------------------------------------------------------------------------------------
-- Credit check
----------------------------------------------------------------------------------------------------------
	declare @finalbalance float, @latestbettime datetime , 
			@BCGBalance Money ,@BDGBalance Money, @translogCredit money
	select 	@creditcheck = '', @finalbalance = 0
	Set @BCGBalance = 0
	Set @BDGBalance = 0	

	select @finalbalance = isnull(sum(isnull(b.winlost, 0) - isnull(b.actual_stake, 0) + isnull(b.playercomm, 0)), 0) + isnull(@credit, 0)
	from 
		bettrans as b with (nolock) 
	where b.custid=  @custid
	
	-----------
	--Thien@20140510: include @translogCredit into @FinalBalance
	select @translogCredit = isnull(sum(isnull(actual_stake,0)) ,0)
	from translog with (nolock) 
	where custid=@custid and statusID=0
	
	select @finalbalance = @finalbalance - @translogCredit
	-----------
	
	select @BCGBalance = isnull(sum(isnull(Balance,0)),0) from BalanceCreditGame with (nolock) where custid = @custid 
	select @BDGBalance = isnull(sum(isnull(Balance,0)),0) from BalanceDebitGame with (nolock) where custid = @custid 	
	
	select  @sumstake =sum(convert(money,val)) from dbo.strsplit(@StakeInfo,',')
	if (@sumstake <> @stake)
	begin
	
		select @ErrMsg = 'Sorry, You are having Stake problem. sumstake and stake are different. sumstake=' + CONVERT(nvarchar(15),isnull(@sumstake,0)) + ',stake=' + CONVERT(nvarchar(15),isnull(@stake,0)) + ',StakeInfo' + @StakeInfo
		set @creditcheck = 'failed'	
		set @fail = 1 
		set @result = 'stakeproblem'
		select @ErrMsg as ErrMsg,@result as result ,@finalbalance as finalbalance
		return
	end

	if (@finalbalance - @stake >= 0)
		set @creditcheck = 'ok'
	else
	begin
		select @ErrMsg = 'Sorry, You are having credit problem. This is due to insufficient fund or you have exceeded your credit limit.'
		set @creditcheck = 'failed'	
		set @fail = 1 
		set @result = 'creditproblem'
		select @ErrMsg as ErrMsg,@result as result ,@finalbalance as finalbalance
		return
	end

	IF @MaxWinLiveCasino <> 0 and ((@BCGBalance - @BDGBalance) >= (@credit * @MaxWinLiveCasino))
	Begin
		set @ErrMsg = 'Over MaxWinbet.'
		set @fail = 1 
		set @result = 'OverMaxWinLimit'
		select @ErrMsg as ErrMsg,@result as result ,@finalbalance as finalbalance
		return 
	End

	Declare @rowcnt int, @err int

---------------------- Check for odd value changed ----------------------------------------------------
set @checktime = CURRENT_TIMESTAMP
BEGIN TRANSACTION
	declare @refn int
	UPDATE ref with (rowlock,updlock) SET @refn=refno=refno+1  WHERE  refid='refno'
	set @refno = @refn + 100000000000
COMMIT TRANSACTION

set @matchdate = convert(varchar(10), @matchdate, 120)
BEGIN TRANSACTION
	----------------------- Insert Bet Infomation into table BettransG ---------------------------------

	insert INTO bettransG (custid, oddsid, odds, betteam, stake,
		status, statusID, refno, creator, betfrom, tpositiontaking, apositiontaking, mpositiontaking,spositiontaking,
		discount, playerdiscount, adiscount,sdiscount, actualrate, virtualrate, matchid, matchdate, winlostdate,
		bettype,checktime,siteid) 
	select @custid, o.val as oddsid, convert(smallmoney,ov.val) as odds, replace(lower(b.val),'''',''), 
		convert(float,s.val), 'running', 0, @refno, @creator,@BetFrom, @otpositiontaking, @oapositiontaking, @ompositiontaking,@ospositiontaking,
		@discount , @playerdiscount , @adiscount,@sdiscount , @actualrate, @actualrate, m.val, @matchdate, @matchdate,
		@bettype,@checktime,@siteid

	from dbo.strsplit(@matchIdInfo,',') as m
	inner join dbo.strsplit(@oddsIdInfo,',') as o on m.rank=o.rank
	inner join dbo.strsplit(@oddValueInfo,',') as ov on m.rank=ov.rank
	inner join dbo.strsplit(@betteamInfo,',') as b on m.rank=b.rank
	inner join dbo.strsplit(@StakeInfo,',') as s on m.rank=s.rank

	SELECT @rowcnt = @@ROWCOUNT, @err = @@ERROR

	-------------------------------------- Check Error -----------------------------------------------

	if (@rowcnt=0 or @err<>0)
	begin
		select @fail = 1
		set @ErrMsg = 'Betting transaction is failed. Please try again...' + convert(varchar(10),@@error)
		rollback tran
		set @result = 'Insert bettransG failed'
		select @ErrMsg as ErrMsg,@result as result ,@finalbalance as finalbalance
		return
	end

	if (@NumOfBet > 0 )
	begin

		----------------- Insert into table Bettrans --------------------------------------	
			
		-- update debitbal 
		exec Dot_BalanceUpdDebit @custid, @stake, 1

		--Victor@2012-10-17:other products so DoubleCommLosing set null
		Set @DoubleCommLosing = NULL
	
		insert bettrans (custid,oddsid,hdp1,hdp2,odds,betteam,stake,[status],
			refno,creator,betfrom, tpositiontaking,apositiontaking,mpositiontaking,
			discount,playerdiscount,adiscount,actualrate,matchid,
			winlostdate,recommend,mrecommend,bettype, currency, currencyName, username, srecommend, sdiscount, spositiontaking, actual_stake,transdesc,ip,  oddstype, statusID, balance,transid2,checktime,virtualrate,comstatus)  		
		select @custid, @matchId, 0.0, 0.0,
			0, '', @stake, 'running',
			@refno, @creator,@BetFrom, @otpositiontaking, @oapositiontaking, @ompositiontaking,
			@discount ,@playerdiscount ,@adiscount ,@actualrate ,@matchId,
			@matchdate,@recommend ,@mrecommend ,@bettype, @currency, @currencyName, @username,  @srecommend, @sdiscount, @ospositiontaking, @stake,@HTTP_REF, @BET_IP, @oddstype, 0, @finalbalance,@transid2,@checktime,@actualrate,@DoubleCommLosing
	
		SELECT @rowcnt = @@ROWCOUNT, @err = @@ERROR
		------------------------ Check Error -----------------------------------------------

		if (@rowcnt =0 or @err <> 0)
		begin
			select @fail = 1
			set @ErrMsg = 'Betting transaction is failed. Please try again...'
			rollback transaction
			set @result = 'Insert bettrans failed'
			select @ErrMsg as ErrMsg,@result as result ,@finalbalance as finalbalance
			return
		end
		else
		begin
            select @transid = scope_identity()
		end

	end
	else	
	begin
		select @fail = 1
	end
	if (@fail = 1)
	begin
		rollback tran	
	end
	else
	begin
		commit tran
	end
END

------------------------ 20081117 write log ------------------------ 
Declare @spname varchar(100)
Declare @hostname varchar(100)
SET @spname = OBJECT_NAME(@@PROCID)
SET @hostname = HOST_NAME()

declare @from nvarchar(50), @str nvarchar(500)
SELECT @from = CASE @betfrom 
	WHEN 'p' THEN 'phone'
	WHEN 'h' THEN 'mobile'
	when 'd' THEN 'deposit'
	WHEN 'w' THEN 'wap'
	WHEN 'm' THEN 'dep-wap'
	WHEN 'i' THEN 'internet'
	WHEN 't' THEN 'test'
	WHEN 'e' THEN 'Europe'
	WHEN 's' THEN 'smartphone'
	ELSE 'unknown (' + isnull(@betfrom,'') + ')' END

SELECT @str=left(
	@from + N' CASINO'
	+ N' oddsid:' +  isnull( @oddsIdInfo,'x')  
	+ N' at ' + isnull(@oddValueInfo,'x') + ' bet ' + isnull(@betTeamInfo,'x')
	+ N' stake:' + CONVERT(nvarchar(15),isnull(@stake,0)) 
	+ N' stakeinfo:' + CONVERT(nvarchar(100),isnull(@StakeInfo,0)) 
	+ N' refno:' +cast(isnull( @refno,'x') as nvarchar(12)) 
	+ N' ip:' + cast(isnull(@BET_IP,'x') as nvarchar(16))
	+ N' (' + CAST(DATEDIFF(millisecond, @checktime, CURRENT_TIMESTAMP) as nvarchar(50)) + ' ms) ' + @site
	+ N' (call ' + ISNULL(@spname, '--') + ' via ' + ISNULL(@hostname, '--') + ')'
	+ N' transid2:' +cast(isnull( @transid2,0) as nvarchar(20)) 
	, 300)
exec logfile @custid, @str

select @transid as TransID,
		@fail as fail,
		@creditcheck as creditcheck,
		@ErrMsg as ErrMsg,
		@result as result,
		@refno as refno,
		@checktime as checktime,
		@finalbalance - @stake as finalbalance 