 USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Process_Login]    Script Date: 12/28/2012 00:24:15 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Dot_Process_Login]
	@site varchar(50),
	@username varchar(50),
	@userpwd varchar(50)
AS

-- 20110707@Austin(DBTRANS): add return Disable151_AU field
-- 20110927@Tony Yu(DBTRANS):Add return c.Disable152_UK,c.Disable152_AU
-- 20111227@Jack Chang(DBTRANS):Add c.DisableLiveCasino & c.SyncLiveCasino
-- 20120522@Tony Yu(DBTRANS):Add c.Disable153_AU
-- 20120821@TWJoe(DBTRANS):Add c.disableVirtualSoccer,c.hideVirtualSoccer
-- 20121004@Austin(DBTRANS):Add return c.reject
IF @site = 'IBC'
SELECT
	c.custid FROM customer c with (nolock)
		INNER JOIN customer a with (nolock) ON c.recommend = a.custid 
		INNER JOIN custinfo i (nolock) ON c.custid = i.custid
	WHERE c.roleid=1 and i.closed = 0 and a.roleid=2
	and ((A.site = 'BEST-ODDS' and c.currency not IN (15,22,33,34)) OR (A.site = 'IBSBET' and IsNull(c.site,'') <> 'INDO')) and c.username = @username AND c.userpwd = @userpwd

ELSE IF @site = 'INDO'
SELECT
	c.custid FROM customer c with (nolock)
		INNER JOIN customer a with (nolock) ON c.recommend = a.custid 
		INNER JOIN custinfo i (nolock) ON c.custid = i.custid
	WHERE c.roleid=1 and i.closed = 0 and a.roleid=2
	and ((A.site = 'BEST-ODDS' and c.ugroup IN ('a','b','c','d','e','f') and c.currency IN (15,20,22,33,34)) OR
	(A.site = 'IBSBET' and IsNull(c.site,'') = 'INDO')) and c.username = @username AND c.userpwd = @userpwd

ELSE IF @site = '789y'
SELECT
	c.custid FROM customer c with (nolock)
		INNER JOIN customer a with (nolock) ON c.recommend = a.custid 
		INNER JOIN custinfo i (nolock) ON c.custid = i.custid
	WHERE c.roleid=1 and i.closed = 0 and a.roleid=2
	and A.site = '789y' and c.username = @username AND c.userpwd = @userpwd

ELSE IF @site IN ('TROJAN', 'TITAN')
SELECT
	customer.recommend,customer.mrecommend,customer.firstname,customer.username,customer.username2 AS nickname,customer.custid, 'hke' ugroup,
	exchange.minbet minbet,
	exchange.minbetlive minbetlive,
	exchange.currency, exchange.exchangeid,
	CASE WHEN exchange.currency in ('M','H','C','S','TBS') THEN (exchange.actualrate * 2) ELSE exchange.actualrate END actualrate,exchange.commaxpayout
	FROM customer (nolock), exchange,customer A (nolock),custinfo i (nolock) WHERE customer.roleid=1 AND A.roleid = 2 AND i.closed = 0 AND customer.custid = i.custid
	and exchange.exchangeid=customer.currency and  A.site = @site and  A.custid=customer.recommend and   customer.username = @username AND customer.userpwd = @userpwd

ELSE IF @site IN ('BSA','XYZBET','KING119','S33BET','611111','822222','933333','722222','733333','755555','222223','222225','222227','222229')
SELECT
	c.custid FROM customer c with (nolock)
		INNER JOIN customer a with (nolock) ON c.recommend = a.custid 
		INNER JOIN custinfo i (nolock) ON c.custid = i.custid
	WHERE c.roleid=1 and i.closed = 0 and a.roleid=2
	and A.site = @site and c.username = @username AND c.userpwd = @userpwd


ELSE IF @site LIKE 'load%'
SELECT --top 1 -- 20120826@vivi: request by maggie, wap user can't login becasue return more then one row
	c.DisableOpenTote,c.DisableHorseRacing,c.DisableNumber, c.DisableFinancial, c.DisableCasino, c.SyncCasino, c.DisableBingo, c.SyncBingo, c.DisableOutright, customer.recommend,customer.mrecommend,customer.srecommend,
	customer.firstname,customer.username,customer.username2 AS nickname,customer.custid,customer.ugroup,
	IsNull(refcode1, '') refcode1, IsNull(phone, '') phone, IsNull(mobilephone, '') mobilephone, IsNull(fax, '') fax,
	exchange.minbet minbet,
	exchange.minbetlive minbetlive,
	exchange.currency, exchange.exchangeid,
	CASE WHEN exchange.currency in ('M','H','C','S','TBS') THEN (exchange.actualrate * 2) ELSE exchange.actualrate END actualrate,
	exchange.commaxpayout,customer.site,
	CASE WHEN IsNull(acgs.custid,0)=0 THEN 0 ELSE 1 END ACG,
	CASE WHEN IsNull(Casinoa.custid,0)=0 and IsNull(Casinob.custid,0)=0 and IsNull(Casinoc.custid,0)=0 THEN 1 ELSE 0 END Casino,
    c.Disable151_AU,c.Disable152_UK,c.Disable152_AU,c.Disable153_AU,
    CASE WHEN isNull(OTBRL.custid, 0)=0 THEN 0 ELSE 1 END OTBR ,-- operation temp banner request 0/1 
    c.DisableLiveCasino, c.SyncLiveCasino,c.disableVirtualSports as disableVirtualSoccer,c.hideVirtualSports as hideVirtualSoccer,c.reject
	FROM customer with (nolock) 
		inner join exchange with (nolock) on customer.currency = exchange.exchangeid
		left outer join dbo.custinfo acgs (nolock) on customer.srecommend = acgs.custid and acgs.DisableCasino=0 and acgs.SyncCasino=1
		left outer join dbo.Cust_Casino_Agent Casinoa (nolock) on customer.mrecommend = Casinoa.custid
		left outer join dbo.Cust_Casino_Agent Casinob (nolock) on customer.srecommend = Casinob.custid
		left outer join dbo.Cust_Casino_Agent Casinoc (nolock) on customer.recommend = Casinoc.custid
		left outer join dbo.custinfo c (nolock) on customer.custid = c.custid
		left outer join dbo.OpTempReqBannerList  OTBRL (nolock) on (customer.srecommend = OTBRL.custid OR customer.mrecommend = OTBRL.custid OR customer.recommend = OTBRL.custid OR customer.custid = OTBRL.custid) -- OTBRL = Operation Temp Banner Request List
	WHERE customer.roleid=1 and customer.custid = @username


