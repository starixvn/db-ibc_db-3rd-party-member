ALTER PROCEDURE [dbo].[Dot_Bingo_BetIns]   
	 @custid    int,     
	------------------------bingo  
	 @BI_Turnover   money = 0,  
	 @BI_Winlost    money = 0,  
	 @BI_swinlost   money = 0,  
	 @BI_mwinlost   money = 0,  
	 @BI_awinlost   money = 0,  
	 @BI_scomm    money = 0,  
	 @BI_mcomm    money = 0,  
	 @BI_acomm    money = 0,  
	 @BI_playercomm   money = 0,  
	 @BI_pendingAmount  money = 0,  
	 @BI_sposition   smallmoney = 0,  
	 @BI_mposition   smallmoney = 0,  
	 @BI_aposition   smallmoney = 0,  
	 @IsDailySettle   bit = 0,  
	   
	 @refno    bigint,   
	 @sessionId   bigint = 0,  
	 @transdesc   nvarchar(300)='',   
	 @ip     nvarchar(15)='',  
	 @ErrCode   int = 0 OUTPUT,  
	 @ErrMsg    nvarchar(200) = '' OUTPUT  
AS  
/*  
Creator : Jamie  
Date : 2010-09-11  
Task : Insert Bingo Bet tickets  
DB: DBTXN/bodb02  
  
Revisions:  
	 - 20110513@Henry: change bettype to new range  
	 - 20110609@Amy: Modify to not check running transfer for Daily Settlement  
	 - 20111026@Sophia: Update credit/debit balance for member  
	 - 20120412@sophia: Revise credit/debit balance for member  
	 - 20120523@Lukas: from 2012-06-01 insert dummy balance transaction into bettrans2 instead of bettrans  
	 - 20130828@Victor(DBTrans): virtualrate change store @actualrate  
	 - 20130913@Johnson: Check PT setting before insert back and remove dummy accounts tickets 
Param's Explanation:  
  
	• Full structure of Dummy accounts:  
	  --ACC Super  3rdSuperUUS  3rdSuperEURO    other currencies...  
	  --ACC Master BIUS$   BIEURO  
	  --ACC Agent  BIUS$01   BIEURO01  
	  --ACC Member BIBetUS$  BIBetEURO  
	  
	• @bingoTurnover: always positive   
	• @bingoWinlost: bingoWinlost = bingoTurnover + member's winlost   
	• @ErrCode:  
	 = 0: Transaction recorded successfully.  
	 > 0: Specific Error.  
	   
	• @ErrMsg: Error description.  
  
*/  
  
SET NOCOUNT ON  
  
	DECLARE @roleid    tinyint,  
	  @username   varchar(30),  
	  @recommend   int,   
	  @mrecommend   int,   
	  @srecommend   int,   
	  @actualrate   float,   
	  @BI_mem_status  nvarchar(10),  
	  @BI_mem_statusID int,  
	  @currency   tinyint,   
	  @currencyName  nvarchar(5),   
	  @transdate   datetime,   
	  @winlostdate  datetime,  
	  @dummy_username  nvarchar(15),  
	  @dummy_custid  int,  
	  @dummy_recommend int,  
	  @dummy_mrecommend int,  
	  @dummy_srecommend int,  
	  @balance   money,  
	  @balance_ABS  money  
  
	SELECT  @ErrCode = 0, @ErrMsg = ''   
	  
	IF @BI_Turnover < 0 OR @BI_Winlost < 0   
	BEGIN  
	 SELECT @ErrMsg = 'Sorry, amount is invalid.', @ErrCode = 101   
	 RETURN    
	END  

	IF @BI_aposition < 0 OR @BI_mposition < 0 OR @BI_sposition < 0
		OR @BI_aposition >= 1 OR @BI_aposition + @BI_mposition >= 1 OR @BI_aposition + @BI_mposition + @BI_sposition >= 1
	BEGIN 
	 SELECT @ErrMsg = 'Sorry, PT setting is invalid.', @ErrCode = 201   
	 RETURN   
	END
  
	SELECT @username= ci.username,  
	  @roleid = isnull(ci.roleid,0),   
	  @recommend = ci.recommend,  
	  @mrecommend = ci.mrecommend,   
	  @srecommend = ci.srecommend,  
	  @currency = ci.currency,   
	  @currencyName = e.currency,   
	  @actualrate = e.actualrate  
	  
	FROM custinfo ci WITH (NOLOCK)   
	  INNER JOIN exchange e WITH (NOLOCK) on ci.currency = e.exchangeid  
	WHERE   ci.custid = @custid   
  
	IF @roleid <> 1  
	BEGIN  
	 SELECT @ErrMsg = 'Invalid Role ID.', @ErrCode = 102    
	 RETURN  
	END  
	--check if srecommend < 100 and scomm <> mcomm and swinlost <>0  
	--member of direct master can not have supercomm<>scomm or swinlost <>0  
	if @srecommend<100 and (@BI_scomm <> @BI_mcomm or @BI_swinlost <>0 )  
	begin  
		 SELECT @ErrMsg = 'Invalid super/master comm or super winloss for member of direct master!', @ErrCode = 103    
		 RETURN  
	end  
	--check not allow to update when there is no RUNNING transfer transaction  
	IF @IsDailySettle=0  
	BEGIN  
	 if NOT exists (select 1 from bettrans with (nolock)  
		where matchid=0 and custid = @custid and bettype = 23201 and ruben = 0 and refno=@refno   
		)  
		 BEGIN  
			  SELECT @ErrMsg = 'There is NO running Bingo transfer transaction (match with the session/refno)!', @ErrCode = 104    
			  RETURN  
		 END  
	END  
  
  
	SELECT @BI_mem_status = CASE WHEN @BI_Winlost > @BI_Turnover THEN 'WON'  
			WHEN @BI_Winlost < @BI_Turnover THEN 'LOSE'  
			ELSE 'DRAW' END   
	          
	SELECT @BI_mem_statusID = CASE WHEN @BI_Winlost > @BI_Turnover THEN 112  
			WHEN @BI_Winlost < @BI_Turnover THEN 113  
			ELSE 111 END   

--20130916@Johnson remove dummy tickets  
/*
SELECT @dummy_custid = c.custid,  
  @dummy_username = c.username,  
  @dummy_recommend = c.recommend,  
  @dummy_mrecommend = c.mrecommend,  
  @dummy_srecommend = c.srecommend  
FROM custinfo c WITH (NOLOCK)   
WHERE c.username = 'BIBet' + @currencyName AND c.roleid = 1   
  
IF isnull(@dummy_custid, 0) = 0  
BEGIN  
 SELECT @ErrMsg = 'Invalid Dummy account or Account is not existed!', @ErrCode = 106    
 RETURN  
END  
 */ 
	------------------Insert trans into DB---------------------------------------------------------------  
	SELECT @transdesc = 'Bingo Betting' + CASE WHEN @transdesc <> '' THEN ' - ' + @transdesc ELSE '' END  
	  
	SELECT @transdate = CURRENT_TIMESTAMP , @winlostdate = CONVERT(nvarchar(10), CURRENT_TIMESTAMP, 120)  
	  
	IF (@BI_Turnover > 0 or @BI_Winlost > 0)  
	BEGIN  
		---update debit balance   
		 SELECT @balance = @BI_Winlost - @BI_Turnover + @BI_playercomm  
		 IF  @balance < 0   
		 BEGIN   
			  SELECT @balance_ABS = ABS(@balance)  
			  EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance_ABS  
		 END   
	    
		---INSERT bingo BET TICKET   
		 INSERT INTO bettrans   
		 (custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake,   
		  awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator,   
		  recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount,   
		  apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, currency, actualrate,virtualrate, currencyName,   
		  ruben, status,statusID,ip,betid)  
		 VALUES   
		 (@CustID, @username, @refno, @transdate, 0, 73, @transdesc, @BI_Winlost, @BI_Turnover, @BI_Turnover,  
		  @BI_awinlost, @BI_mwinlost, @BI_swinlost, @BI_playercomm, @BI_acomm, @BI_mcomm, @BI_scomm, @winlostdate,   
		  @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, @BI_aposition, @BI_mposition, @BI_sposition, @BI_aposition +@BI_mposition + @BI_sposition,   
		  @Currency, @actualrate,@actualrate, @currencyName, 1, @BI_mem_status,@BI_mem_statusID, @ip,@sessionId)  
		  
		 IF @@ERROR <> 0  
		 BEGIN     
			  SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107   
			  --rollback balance  
			  IF  @balance < 0   
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
	    
	END  
  
	---INSERT bingo PENDING BET TICKET   
	IF @BI_pendingAmount > 0  
	BEGIN  
	 ---update debit balance   
	 EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @BI_pendingAmount  
	  
	 INSERT INTO bettrans   
	  (custid, username, refno, transdate, matchid, bettype, transdesc, winlost, actual_stake, stake,  
	   awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator,   
	   recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount,   
	   apositiontaking, mpositiontaking, spositiontaking, tpositiontaking, currency, actualrate, currencyName,   
	   ruben, status,statusID,ip,betid)  
	 VALUES   
	  (@CustID, @username, @refno, @transdate, 0, 23202, @transdesc, 0, @BI_pendingAmount, @BI_pendingAmount,  
	   0, 0, 0, 0, 0, 0, 0, @winlostdate,   
	   @CustID, @Recommend, @MRecommend, @SRecommend, 0, 0, 0, 0, 0, 0, 0, 0,   
	   @Currency, @actualrate, @currencyName, 0, 'running',0, @ip,@sessionId)  
	  
	 IF @@ERROR <> 0  
	 BEGIN     
		  SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107   
		  DELETE FROM bettrans WHERE custid = @custid and refNo = @refno AND bettype =73 and matchid = 0  
		  --rollback balance  
		  EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @BI_pendingAmount  
		  RETURN  
	 END   
	END  
  

	--20130916@Johnson remove dummy tickets  
	/*  
	IF (@BI_Turnover > 0 or @BI_Winlost > 0)  
	BEGIN  
	 IF @winlostdate < '2012-06-01'  
	 BEGIN  
	  --INSERT bingo DUMMY TICKET  
	  INSERT INTO bettrans   
	   (custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake,   
		awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator,       recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount,   
		apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,  
		currency, actualrate,virtualrate, currencyName, ruben, status,statusID,ip,betid)  
	  VALUES   
	   (@dummy_custID, @dummy_username, @refno, @transdate, 0, 73, @transdesc, @BI_Turnover, @BI_Winlost,@BI_Winlost,  
		-@BI_awinlost, -@BI_mwinlost, -@BI_swinlost, -@BI_playercomm, -@BI_acomm, -@BI_mcomm, -@BI_scomm, @winlostdate, @dummy_custID,   
		@dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 0, 0, 0, 0,   
		@Currency, @actualrate,@actualrate, @currencyName, 1, 'DONE',121, @ip,@sessionId)  
	  
	  IF @@ERROR <> 0  
	  BEGIN     
	   SELECT @ErrMsg = 'Insert transaction failed.', @ErrCode = 107   
	   DELETE FROM bettrans WHERE refNo = @refno AND bettype in (73,23202) and matchid = 0  
	   RETURN  
	  END  
	 END  
	 --INSERT bingo DUMMY TICKET INTO bettrans2  
	 INSERT INTO bettrans2   
	  (custid, username, refno, transdate, matchid, bettype, transdesc, winlost, stake, actual_stake,   
	   awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate, creator,   
	   recommend, mrecommend, srecommend, playerdiscount, discount, adiscount, sdiscount,   
	   apositiontaking, mpositiontaking, spositiontaking, tpositiontaking,  
	   currency, actualrate,virtualrate, currencyName, ruben, status,statusID,ip,betid)  
	 VALUES   
	  (@dummy_custID, @dummy_username, @refno, @transdate, 0, 73, @transdesc, @BI_Turnover, @BI_Winlost,@BI_Winlost,  
	   -@BI_awinlost, -@BI_mwinlost, -@BI_swinlost, -@BI_playercomm, -@BI_acomm, -@BI_mcomm, -@BI_scomm, @winlostdate, @dummy_custID,   
	   @dummy_recommend, @dummy_mrecommend, @dummy_srecommend, 0, 0, 0, 0, 0, 0, 0, 0,   
	   @Currency, @actualrate,@actualrate, @currencyName, 1, 'DONE',121, @ip,@sessionId)  
	  
	   
	END  
	*/
  
	--UPDATE MEMBER TRANS   
	SELECT  @balance = sum(winlost - actual_stake)  
	FROM bettrans WITH (NOLOCK)  
	WHERE custid=@custid and refno = @refno and bettype = 23201 and matchid = 0   
	  
	--update debit balance  
	IF @balance > 0  
	 EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance  
	  
	UPDATE bettrans WITH (ROWLOCK, UPDLOCK)  
	SET  status = 'Completed',statusID=131, ruben = 1, winlost = actual_stake  
	WHERE custid=@custid and refno = @refno and bettype = 23201 and matchid = 0  
	  
	IF @@ERROR <> 0  
	BEGIN     
		 SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 108   
		 --delete all trans of current session  
		 DELETE FROM bettrans WHERE refNo = @refno AND bettype in (73,23202) and matchid = 0  
		 --rollback balance  
		 IF @balance > 0  
		  EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance  
		 RETURN  
	END  
  
	--update credit balance  
	IF @balance < 0  
	BEGIN  
		 SET @balance = ABS(@balance)  
		 EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance  
	END  
  
	--UPDATE MEMBER PENDING BINGO TRANS OF PREVIOUS SESSION  
	SELECT  @balance = sum(winlost - actual_stake)  
	FROM bettrans WITH (NOLOCK)  
	WHERE custid = @custid and bettype = 23202 and ruben = 0 and refno <> @refno and matchid = 0  
	  
	--update debit balance  
	IF @balance > 0  
	 EXEC Dot_BalanceUpdDebit @custid = @custid, @balance = @balance  
	   
	UPDATE bettrans WITH (ROWLOCK, UPDLOCK)   
	SET  status = 'Completed',statusID=131, ruben = 1, winlost = actual_stake   
	WHERE custid = @custid and bettype = 23202 and ruben = 0 and refno <> @refno and matchid = 0  
	  
	IF @@ERROR <> 0  
	BEGIN     
		 SELECT @ErrMsg = 'Update transaction failed.', @ErrCode = 108   
		 --revert transfer trans  
		 UPDATE bettrans WITH (ROWLOCK, UPDLOCK) SET status = 'running',statusID=0, ruben = 0, winlost = 0   
		 WHERE refno = @refno and bettype = 23201 and ruben = 1 and matchid = 0   
		 --delete all trans of current session  
		 DELETE FROM bettrans WHERE refNo = @refno AND bettype in (73,23202) and matchid = 0  
		 --rollback  
		 IF @balance > 0  
		  EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance  
		 RETURN  
	END  
  
	--update credit balance  
	IF @balance < 0  
	BEGIN  
		 SET @balance = ABS(@balance)  
		 EXEC Dot_BalanceUpdCredit @custid = @custid, @balance = @balance  
	END   
  
---------------------------------------------------------------------------------------------------  
  
DECLARE @LogData nvarchar(300)  
  
SELECT @LogData = 'Bingo Betting custid = ' + convert(nvarchar(20), @custid) + ', bettype = 73'  + ', bingoTurnover = ' + convert(nvarchar(20), @BI_Turnover)   
      + ', bingoWinlost = ' + convert(nvarchar(20), @BI_Winlost)   
      + case when @BI_pendingAmount > 0 then ', bingoPendingAmount = '+ convert(nvarchar(30),@BI_pendingAmount) else '' end  
      + ', refNo = ' + convert(nvarchar(20),@refno)  +', currency = ' + convert(nvarchar(10),@currency)   
      + ', bingoPlayercomm = ' + convert(nvarchar(10),@BI_playercomm) + ', IP = '+ @ip   
  
BEGIN TRY  
 EXEC dbo.WriteLog_UserLog @UserID = @custid, @Doing = @LogData  
END TRY  
BEGIN CATCH  
 -- if write log error: not return error code  
END CATCH  
  

GO
GRANT EXECUTE ON [dbo].[Dot_Bingo_BetIns] TO [Dot_Member]
GO
GRANT EXECUTE ON [dbo].[Dot_Bingo_BetIns] TO [Dot_Casino]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Bingo_BetIns] TO [vnteam]