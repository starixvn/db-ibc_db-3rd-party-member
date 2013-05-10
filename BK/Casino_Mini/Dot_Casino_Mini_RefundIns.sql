 ALTER Procedure [dbo].[Dot_Casino_Mini_RefundIns]
	@custid			int,  	
	@bettype		tinyint = 73,
	@turnover		money,
	@winlost		money,
	@swinlost		money = 0,
	@mwinlost		money = 0,
	@awinlost		money = 0,
	@scomm			money = 0,
	@mcomm			money = 0,
	@acomm			money = 0,
	@playercomm		money = 0,

	@refno			bigint = 0 output,
	@transdesc		nvarchar(300)='',	
	@ip				nvarchar(15)='',
	@sessionId      bigint = 0,
	@ErrCode		int = 0 OUTPUT,
	@ErrMsg			nvarchar(200) = '' OUTPUT
AS
/*
Creator : Thien Pham
Date : 2010-03-06
Task : insert refund transaction for casino mini games player
DB: DBTRANS.bodb02

History:
    - 20111028@Sophia: Update credit/debit balance
    - 20120412@Sophia: Revise credit/debit balance
    
Param's Explanation:

	• Full structure of Dummy accounts:
		--ACC Super		3rdSuperUUS		3rdSuperEURO    other currencies...
		--ACC Master	CasUS$			CasEURO
		--ACC Agent		CasUS$01		CasEURO01
		--ACC Member	CasBetUS$		CasBetEURO

	• @amount: amount to adjust(>0: increase; <0: deduct)
	• @bettype: 73-->casino mini games
	• @swinlost: super win/loss: must be 0 for superid < 100
	• @mwinlost: master win/loss must be equal awinlost for superid < 100
	• @awinlost: agent win/loss
	• @scomm: super commission must be equal master commission for super id < 100
	• @mcomm: master commission
	• @acomm: agent commission
	• @playercomm: player commission
	• @refno: 0->adjustment transaction only, not relating to any other sessions
			  >0 -> refund for a pending amount of a session
	• @transdesc:
	• @ip: IP of the one who do the adjustment
	• @ErrCode:
		= 0: Transaction recorded successfully.
		> 0: Specific Error.
	• @ErrMsg: Error description.

*/

SET NOCOUNT ON

if @bettype not in (73)
begin
	select @ErrMsg = 'Unsupported bettype', @ErrCode = 101
	return 
end

DECLARE	@roleid				tinyint,
		@username			varchar(30),
		@recommend			int, 
		@mrecommend			int, 
		@srecommend			int, 
		@actualrate			float, 
		@mem_status			nvarchar(10),
		@casinoCredit		money,
		@db_custid			int,
		@currency			tinyint, 
		@currencyName		nvarchar(5), 
		@transdate			datetime, 
		@winlostdate		datetime,
		@dummy_username		nvarchar(15),
		@dummy_custid		int,
		@dummy_recommend	int,
		@dummy_mrecommend	int,
		@dummy_srecommend	int,
		@RefNo_New			bigint,
		@balance			money,
		@balance_ABS		money

SELECT  @ErrCode = 0, @ErrMsg = '' 

IF @turnover = 0 and @winlost = 0
BEGIN
	SELECT @ErrMsg = 'Adjusting value is 0', @ErrCode = 101	
	RETURN		
END

SELECT	@username= ci.username,
		@roleid = isnull(ci.roleid,0), 
		@recommend = ci.recommend,
		@mrecommend = ci.mrecommend, 
		@srecommend = ci.srecommend,
		@currency = ci.currency, 
		@currencyName = e.currency, 
		@actualrate = e.actualrate

FROM	custinfo ci WITH (NOLOCK) 
		INNER JOIN exchange e WITH (NOLOCK) on ci.currency = e.exchangeid
WHERE   ci.custid = @custid 

IF @roleid <> 1
BEGIN
	SELECT @ErrMsg = 'Invalid Role ID.', @ErrCode = 102		
	RETURN
END
--20090219@PhuongDoan: check if srecommend < 100 and scomm <> mcomm and swinlost <>0
--member of direct master can not have supercomm<>scomm or swinlost <>0
if @srecommend<100 and (@scomm <> @mcomm or @swinlost <>0)
begin
	SELECT @ErrMsg = 'Invalid super/master comm or super winloss for member of direct master!', @ErrCode = 103		
	RETURN
end

if @turnover < @winlost
	select @mem_status='WON'
else if @turnover > @winlost
	select @mem_status='LOSE'
else
	select @mem_status='DRAW'


SELECT	@dummy_custid = c.custid,
		@dummy_username = c.username,
		@dummy_recommend = c.recommend,
		@dummy_mrecommend = c.mrecommend,
		@dummy_srecommend = c.srecommend
FROM	custinfo c WITH (NOLOCK) 
WHERE	c.username = 'CasBet' + @currencyName AND c.roleid = 1 

IF isnull(@dummy_custid, 0) = 0
BEGIN
	SELECT @ErrMsg = 'Invalid Dummy account or Account is not existed!', @ErrCode = 106		
	RETURN
END

------------------Insert trans into DB---------------------------------------------------------------
SELECT	@transdesc = 'Casino Mini Games Betting (from Pending):' + CASE WHEN @transdesc <> '' THEN ' - ' + @transdesc ELSE '' END

SELECT @transdate = CURRENT_TIMESTAMP , @winlostdate = CONVERT(nvarchar(10), CURRENT_TIMESTAMP, 120)

if @refno <> 0 
begin
	if not exists (select 1 from bettrans(nolock) 
					where custid = @custid and ruben = 0 and refno = @refno
						and bettype = 118)
	begin
		SELECT @ErrMsg = 'There no exists pending transaction', @ErrCode = 107
		return
	end
end
EXEC dbo.Acc_SelRefNo @RefNo = @RefNo_New OUTPUT
SELECT @RefNo_New = @RefNo_New + 100000000000	


----------------INSERT CASINO BET TICKET 
---update debit balance 
	SELECT @balance = @winlost - @turnover + @playercomm
	IF 	@balance < 0 
	BEGIN 
		SELECT @balance_ABS = ABS(@balance)
		EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance_ABS
	END  
	
	INSERT INTO bettrans 
	(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
	 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
	 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
	 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, currency, actualrate, currencyName, 
	 ruben, status,ip,betid)
	VALUES 
	(@CustID, @username, @RefNo_New, @transdate, 0, @bettype, @transdesc, @winlost, @turnover, @turnover,
	 @awinlost, @mwinlost, @swinlost, @playercomm, @acomm, @mcomm, @scomm, @winlostdate, 
	 @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
	 @Currency, @actualrate, @currencyName, 1, @mem_status, @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 108	
		--rollback balance
		IF 	@balance < 0 
		BEGIN 
			SELECT @balance_ABS = ABS(@balance)
			EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance_ABS
		END  
		RETURN
	END	

---update credit balance 
	IF  @balance > 0 
	BEGIN 
		EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
	END
	
-----------INSERT CASINO DUMMY TICKET
	INSERT INTO bettrans 
		(custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake, 
		 awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator, 
		 recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount, 
		 apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,
		 currency, actualrate, currencyName, ruben, status,ip,betid)
	VALUES 
		(@dummy_custID, @dummy_username, @RefNo_New, @transdate, 0, @bettype, @transdesc, @turnover, @winlost,@winlost,
		 -@awinlost, -@mwinlost, -@swinlost, -@playercomm, -@acomm, -@mcomm, -@scomm, @winlostdate, @dummy_custID, 
		 @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 0, 0, 0, 0, 
		 @Currency, @actualrate, @currencyName, 1, 'DONE', @ip,@sessionId)

	IF @@ERROR <> 0
	BEGIN			
		SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 108	
		DELETE FROM bettrans WHERE custid=@custid and matchid = 0 and refno=@RefNo_New
		RETURN
	END
	
---------------------------	
	if @refno <> 0 
	begin
		SELECT  @balance = sum(winlost - actual_stake)
		FROM	bettrans WITH (NOLOCK)
		WHERE	custid = @custid and bettype = 118 and ruben = 0 and refno=@refno
	
		--update debit balance	
		IF 	@balance > 0 
		BEGIN 
			EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance
		END 
	
		update	bettrans with(rowlock,updlock)
		set		ruben = 1, status = 'Completed', winlost = actual_stake
		where	custid = @custid and bettype = 118 and ruben = 0 and refno=@refno
			
		if @@ERROR <> 0
		begin
			SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 109
			delete from bettrans where custid in (@custid,@dummy_custID) and bettype = @bettype and refno = @RefNo_New and matchid = 0
			--rollback balance
			IF 	@balance > 0 
			BEGIN 
				EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
			END 
		return
		end	
			
		---update credit balance 
		IF  @balance < 0 
		BEGIN 
			SELECT @balance = ABS(@balance)
			EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance
		END
	end
	
---------------------------------------------------------------------------------------------------

DECLARE @LogData nvarchar(300)

SELECT @LogData = 'Casino Mini Games Betting (from Pending) custid = ' + convert(nvarchar(20), @custid) + ', bettype = '+convert(varchar(20), @bettype)+', stake = ' + convert(nvarchar(20), @turnover) 
					 + ', Winlost = ' + convert(nvarchar(20), @Winlost)
					 + ', refNo = ' + convert(nvarchar(20),@refno) 
					 + ', New_refNo = ' + convert(nvarchar(20),@refno_new)
					 + ', currency = ' + convert(nvarchar(10),@currency) 
					 + ', Playercomm = ' + convert(nvarchar(10),@playercomm) + ', IP = '+ @ip 

EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData

select @refno=@RefNo_New
GO
GRANT EXECUTE ON [dbo].[Dot_Casino_Mini_RefundIns] TO [Dot_Casino]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Casino_Mini_RefundIns] TO [vnteam]