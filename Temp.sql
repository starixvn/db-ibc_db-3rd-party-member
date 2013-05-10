USE [bodb_dwrs]
GO
/****** Object:  StoredProcedure [dbo].[Acc_Rpt_LiveCasinoFinance]    Script Date: 04/29/2013 03:20:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Acc_Rpt_LiveCasinoFinance]  
 @datestart datetime,  
 @dateend datetime,  
 @licensee VARCHAR(100)= '',  
 @currency VARCHAR(100)= '',  
 @gametype VARCHAR(100)= '',  
 @gametable VARCHAR(100)= '',  
 @TotalPlayers bigint = 0 Output,  
 @TotalGames bigint = 0 Output,  
 @GamingLevy money = 0.02 output,  
 @ProRated money = 5000 output  
AS  

/*
Created by: Dom.Cao
Date: 2013-02-26
Task : IRP #894 - AccSite - Implement Live Casino Finance report.
DB: DBDW2.bodb_dwrs
Original:

Revisions:
	20130409@Dom.Cao:fix bug SiteID
	20130412@Dom.Cao display more 4 currencies DDD, IDD, IN, IND (the exchange IDs are 47,33,15,22)
	20130423@Dom.Cao: include IDR currency
*/


set nocount on

DECLARE @max_exchangedate DATETIME

SELECT @max_exchangedate =MAX(exchangedate) FROM bodb02.dbo.ExchangeDailyOanda ex WITH(NOLOCK)
WHERE MONTH(exchangedate) = MONTH(@dateend)
AND YEAR(exchangedate)= YEAR(@dateend) 

SELECT *
INTO #exchange 
FROM bodb02.dbo.ExchangeDailyOanda ex WITH(NOLOCK)
WHERE ex.ExchangeDate = @max_exchangedate

--PRINT  @max_exchangedate

SELECT siteid 
INTO #site
FROM bodb_Account.dbo.tbl_Site(nolock)
WHERE [site] IN (
	select labelname 
	from db054.bodb_Licensee.dbo.Labels with(nolock)
	where LicenseeID IN (SELECT val FROM dbo.strSplit(@licensee,',') ss)
)

	SELECT * 
	into #TempData
	FROM bodb_account.dbo.mcCustLiveCasinoDaily b with(NOLOCK) 
	WHERE rptdate BETWEEN @datestart AND @dateend
	and b.SiteID IN(SELECT siteid FROM #site ss)  
	and b.bettype IN (SELECT val FROM dbo.strSplit(@gametype,',') ss)
	and b.leagueid IN(SELECT val FROM dbo.strSplit(@gametable,',') ss) 
	and (
			(
				b.currency IN(SELECT val FROM dbo.strSplit(@currency,',') ss)
				AND @dateend < '20130401'
				AND b.currency IN(3,4,6,43,44,45)
			)
			OR 
			(
				b.currency IN(SELECT val FROM dbo.strSplit(@currency,',') ss)
				AND @dateend >= '20130401'
				AND b.currency IN(3,4,6,43,44,45,47,33,15,22,34)
			)
		)
--select * from bodb_account.dbo.tbl_currency
;WITH total as 
( 
 SELECT leagueid, 
   SUM(TurnoverIBC*USD) totalbets,  
   SUM((TurnoverIBC-WinlossIBC)*USD) TotalWins,  
   -SUM((CommissionS+WinlossIBC)*USD) NetIncome,  
   -SUM(CommissionS*USD) Comm,  
   -SUM(WinlossIBC*USD) GrossIncome
 from #TempData b
	INNER JOIN #exchange ex on currency = ExchangeId   
 GROUP BY  leagueid  
),Players AS  
(  
 select leagueid,  
  COUNT(DISTINCT b.custid) players,  
  0 games,  
  0 totalbets,  
  0 TotalWins,  
  0 GrossIncome,  
  0 Comm,  
  0 NetIncome  
 from #TempData b
 GROUP BY leagueid  
), Games AS  
(  
 select leagueid,  
  0 players,  
  count(DISTINCT b.matchid) games,  
  0 totalbets,  
  0 TotalWins,  
  0 GrossIncome,  
  0 Comm,  
  0 NetIncome  
 FROM #TempData b
 GROUP BY leagueid  
) 

SELECT leaguename tablename, SUM(players) players,SUM(games) games,SUM(totalbets) totalbets,SUM(totalwins) totalwins,SUM(GrossIncome) GrossIncome,SUM(Comm) Comm,SUM(NetIncome) NetIncome  
FROM (  
 SELECT leagueid,0 players,0 games,totalbets,TotalWins,GrossIncome,Comm,NetIncome from total  
 UNION ALL  
 SELECT leagueid,players,0 games,0 totalbets,0 TotalWins,0 GrossIncome,0 Comm,0 NetIncome from players  
 UNION ALL  
 SELECT leagueid,0 players,games,0 totalbets,0 TotalWins,0 GrossIncome,0 Comm,0 NetIncome from games  
) data  LEFT JOIN bodb_Account.dbo.League l WITH (NOLOCK) ON l.leagueid = data.leagueid
GROUP BY leaguename
  
select @TotalPlayers=COUNT(DISTINCT b.custid),@TotalGames=COUNT(DISTINCT b.matchid)  
from #TempData b  



SELECT @GamingLevy = 0.02, @ProRated = 5000

DROP TABLE #site
DROP TABLE #TempData