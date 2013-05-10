set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE  [dbo].[TP_Game_UserBet_TSTWinLossBySite]
	@DateStart		datetime = null,		--Input TABLE's field
	@DateEnd		datetime = null,		--Input TABLE's field
	@Sitename		varchar(50) = null,
	@GameTypeID		varchar(200) = null,
	@ErrCode		varchar(5)	= '' OUTPUT,	--Return ErrCode
	@ErrMsg			nvarchar(500)= '' OUTPUT	--Return Exception Message
AS
/*
Purpose:	Casino WinLoss Report
Used By:	Admin System,SBAgent_Report.cs
Used By:	OneWorks Admin Site
Add By:		Karen,2013/1/4

*/
SET NOCOUNT ON

DECLARE @SettleDate			datetime
DECLARE @DateStart1			datetime
DECLARE @DateEnd1			datetime
DECLARE @DailyUserBetFlag	bit
DECLARE @UserBetFlag		bit
DECLARE @CasinoID			int
DECLARE @SqlStr				varchar(1000)

DECLARE @temp_SuperList TABLE	(	IBCCustID	int, 
									CustID		int,
									Username	nvarchar(50),
									RoleID		tinyint									
								)
	
DECLARE @temp_ExchangeDailyOanda TABLE	(	ExchangeDate	DATETIME,
											IBCExchangeID	int, 
											ExchangeID		int,	
											EUR				FLOAT																		
										)	
											
SET @CasinoID = 1

--ONE DAY = TODAY 12:00:01 - TOMORROW 12:00:00
IF (rtrim(@DateStart) = '') or @DateStart is null
	SET @DateStart = NULL
ELSE
	--SET @DateStart = @DateStart + ' 12:00:00'
	SET @DateStart = @DateStart + ' 00:00:00'
		
IF (rtrim(@DateEnd) = '') or @DateEnd is null
	SET @DateEnd = NULL
ELSE
	--SET @DateEnd = CONVERT(NCHAR(10),DATEADD(d,1,@DateEnd),101) + ' 11:59:59'
	SET @DateEnd = @DateEnd + ' 23:59:59'

SELECT @SettleDate = SettleDate FROM Casino WITH (nolock) WHERE CasinoID = @CasinoID

IF CONVERT(varchar(10),@SettleDate,120) >= CONVERT(varchar(10),@DateStart,120) and CONVERT(varchar(10),@SettleDate,120) < CONVERT(varchar(10),@DateEnd,120)
BEGIN
	SET @DateEnd1 = @DateEnd
	SET @DateStart1 = dateadd(d,1,@SettleDate)
	SET @DateEnd = @SettleDate + ' 23:59:59'
	SET @DailyUserBetFlag = 1
	SET @UserBetFlag = 1
END
ELSE IF CONVERT(varchar(10),@SettleDate,120) < CONVERT(varchar(10),@DateStart,120)
BEGIN
	SET @DateStart1 = @DateStart
	SET @DateEnd1 = @DateEnd
	SET @DailyUserBetFlag = 0
	SET @UserBetFlag = 1
END
ELSE
BEGIN
	SET @DailyUserBetFlag = 1
	SET @UserBetFlag = 0
END

print @DateStart
print @DateEnd
print @DateStart1
print @DateEnd1
print @DailyUserBetFlag
print @UserBetFlag

BEGIN TRY

	--Get Super/Master list
	SET @SqlStr = 'select * from OPENQUERY(DB06,''exec [bodb02].[dbo].[Dot_Casino_GetCustomerBySite_test] @Sitename=''''' + @Sitename + ''''''')'											

	INSERT INTO @temp_SuperList(IBCCustID,Username,RoleID) Exec(@SqlStr)

	UPDATE	@temp_SuperList
	SET		CustID = Customer.CustID
	FROM	Customer(nolock),@temp_SuperList temp
	WHERE	temp.IBCCustID = Customer.IBCCustID
			
	DELETE FROM	@temp_SuperList WHERE CustID is null 	

	--Get dailyexchange
	SET @SqlStr = 'select exchangedate,exchangeid,eur from OPENQUERY(DB06,''select * from [bodb02].[dbo].[Lrf_f_GetExchangeDaily](''''' + convert(varchar(10),@DateStart,120) + ''''',''''' + convert(varchar(10),@DateEnd,120) + ''''')'')'
	INSERT INTO @temp_ExchangeDailyOanda(ExchangeDate,IBCExchangeID,EUR) Exec(@SqlStr)

	UPDATE	@temp_ExchangeDailyOanda
	SET		ExchangeID = Code.CodeID
	FROM	Code(nolock),@temp_ExchangeDailyOanda temp
	WHERE	temp.IBCExchangeID = convert(int,Code.CodeNo)
			AND Code.CodeTypeNo = '06'
								
	--Get data 
	IF @DailyUserBetFlag = 1 AND @UserBetFlag = 1
	BEGIN
		SELECT	SUM(Stake) Stake, SUM(MemberWinLoss) MemberWinLoss, SUM(BetCount) BetCount
		FROM	(
				SELECT	Sum(TotalTurnOver*ISNULL(tempExchange.EUR,0)) Stake,
						Sum(TotalWinLoss*ISNULL(tempExchange.EUR,0)) MemberWinLoss,
						Sum(GameCnt) BetCount
				FROM	dbo.DailyUserBet AS UB WITH (nolock) INNER JOIN
						dbo.Customer AS C WITH (nolock) ON UB.CustID = C.CustID INNER JOIN
						@temp_ExchangeDailyOanda tempExchange ON tempExchange.ExchangeID = UB.ExchangeID AND
						UB.Date = tempExchange.ExchangeDate INNER JOIN
						dbo.strSplit(@GameTypeID,',') AS GameType ON GameType.val = UB.GameTypeID
				WHERE	(UB.Date >= @DateStart)
						AND (UB.Date <= @DateEnd)
						AND ((UB.SAgentID in (SELECT CustID FROM @temp_SuperList WHERE RoleID = 4))
							OR (C.MAgentID in (SELECT CustID FROM @temp_SuperList WHERE RoleID = 3)))
						AND UB.ExchangeID <> 1
				HAVING	Sum(ISNULL(TotalTurnOver,0)*ISNULL(tempExchange.EUR,0)) is not null					
				UNION ALL
				SELECT	SUM(Stake*ISNULL(tempExchange.EUR,0)) Stake,
						SUM(MemberWinLoss*ISNULL(tempExchange.EUR,0)) MemberWinLoss,
						SUM(BetCount) BetCount
				FROM	(SELECT	UB.ExchangeID, CONVERT(varchar(10),UB.EndTime,101) EndTime, Sum(ISNULL(TotalTurnOver,0)) Stake,
								Sum(ISNULL(TotalWinLoss,0)) MemberWinLoss,
								Count(UserBetID) BetCount
						FROM	UserBet UB with (NOLOCK) INNER JOIN 
								Customer AS CS WITH (NOLOCK) ON UB.CustID = CS.CustID INNER JOIN
								dbo.strSplit(@GameTypeID,',') AS GameType ON GameType.val = UB.GameTypeID
						WHERE	(UB.EndTime >= @DateStart1)
								AND (UB.EndTime <= @DateEnd1)
								AND UB.Status in ('25','30','35')
								AND ((CS.SAgentID in (SELECT CustID FROM @temp_SuperList WHERE RoleID = 4))
									OR (CS.MAgentID in (SELECT CustID FROM @temp_SuperList WHERE RoleID = 3)))	
								AND UB.ExchangeID <> 1		
						GROUP BY UB.ExchangeID,CONVERT(varchar(10),UB.EndTime,101)	
						)UB INNER JOIN @temp_ExchangeDailyOanda tempExchange ON tempExchange.ExchangeID = UB.ExchangeID	AND
						UB.EndTime = tempExchange.ExchangeDate
				HAVING	SUM(Stake*ISNULL(tempExchange.EUR,0)) is not null					
				) UB			
		
	END
	ELSE IF @DailyUserBetFlag = 1 AND @UserBetFlag = 0
	BEGIN
		SELECT	Sum(ISNULL(TotalTurnOver,0)*ISNULL(tempExchange.EUR,0)) Stake,
				Sum(ISNULL(TotalWinLoss,0)*ISNULL(tempExchange.EUR,0)) MemberWinLoss,
				Sum(ISNULL(GameCnt,0)) BetCount
		FROM	dbo.DailyUserBet AS UB WITH (nolock) INNER JOIN
				dbo.Customer AS C WITH (nolock) ON UB.CustID = C.CustID INNER JOIN
				@temp_ExchangeDailyOanda tempExchange ON tempExchange.ExchangeID = UB.ExchangeID AND
				UB.Date = tempExchange.ExchangeDate INNER JOIN
				dbo.strSplit(@GameTypeID,',') AS GameType ON GameType.val = UB.GameTypeID
		WHERE	(UB.Date >= @DateStart)
				AND (UB.Date <= @DateEnd)
				AND ((UB.SAgentID in (SELECT CustID FROM @temp_SuperList WHERE RoleID = 4))
					OR (C.MAgentID in (SELECT CustID FROM @temp_SuperList WHERE RoleID = 3)))
				AND UB.ExchangeID <> 1
		HAVING	Sum(ISNULL(TotalTurnOver,0)*ISNULL(tempExchange.EUR,0)) is not null						
	END
	ELSE IF @DailyUserBetFlag = 0 AND @UserBetFlag = 1
	BEGIN
		SELECT	SUM(Stake*ISNULL(tempExchange.EUR,0)) Stake,
				SUM(MemberWinLoss*ISNULL(tempExchange.EUR,0)) MemberWinLoss,
				SUM(BetCount) BetCount
		FROM	(SELECT	UB.ExchangeID, CONVERT(varchar(10),UB.EndTime,101) EndTime, Sum(ISNULL(TotalTurnOver,0)) Stake,
						Sum(ISNULL(TotalWinLoss,0)) MemberWinLoss,
						Count(UserBetID) BetCount
				FROM	UserBet UB with (NOLOCK) INNER JOIN 
						Customer AS CS WITH (NOLOCK) ON UB.CustID = CS.CustID INNER JOIN
						dbo.strSplit(@GameTypeID,',') AS GameType ON GameType.val = UB.GameTypeID
				WHERE	(UB.EndTime >= @DateStart1)
						AND (UB.EndTime <= @DateEnd1)
						AND UB.Status in ('25','30','35')
						AND ((CS.SAgentID in (SELECT CustID FROM @temp_SuperList WHERE RoleID = 4))
							OR (CS.MAgentID in (SELECT CustID FROM @temp_SuperList WHERE RoleID = 3)))	
						AND UB.ExchangeID <> 1		
				GROUP BY UB.ExchangeID, CONVERT(varchar(10),UB.EndTime,101)	
				)UB INNER JOIN @temp_ExchangeDailyOanda tempExchange ON tempExchange.ExchangeID = UB.ExchangeID	AND
				UB.EndTime = tempExchange.ExchangeDate
		HAVING	SUM(Stake*ISNULL(tempExchange.EUR,0)) is not null							
	END
END TRY

BEGIN CATCH
	SELECT @ErrCode = 'E0004'
	SELECT @ErrMsg = left(Convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_PROCEDURE() + ' ' + Convert(varchar, ERROR_LINE()) + ' ' + ERROR_MESSAGE(),500)
END CATCH

