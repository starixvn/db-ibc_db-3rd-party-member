

ALTER PROCEDURE [dbo].[Task_DailyDummyTransfer_s253]
	@date smalldatetime
AS

/*
	Created: 20120405@Lukas	
	Task: Transfer Dummy for P2P (daily) 
	DB: DBTRANS.BODB02
	
	Revisions: 
		- 20120601@Lukas: from 2012-06-01 insert dummy transaction into bettrans2 instead of bettrans
*/
BEGIN 
	SET NOCOUNT ON 
	
	IF @date < '2012-06-01'
	BEGIN
		DELETE b
		FROM dbo.bettrans b WITH (INDEX=CIX_matchid_bettype)		
		WHERE b.statusid = 121 AND b.winlostdate = @date
			AND matchid = 1000 AND bettype = 1000
			--AND b.custid IN ()
	END

	DELETE b
	FROM dbo.bettrans2 b WITH (ROWLOCK,UPDLOCK)		
	WHERE b.statusid = 121 AND b.winlostdate = @date
		AND matchid = 1000 AND bettype = 1000
		--AND b.custid IN ()


	DECLARE @sum TABLE (
			currency INT PRIMARY KEY, 
			CurrencyName NVARCHAR(50),
			oddsspread SMALLMONEY, 
			odds SMALLMONEY,
			actual_stake MONEY,
			winlost MONEY, 
			scomm MONEY,
			acomm MONEY,
			comm MONEY,
			playercomm MONEY,
			actualrate FLOAT
)  

	INSERT INTO @sum(currency, currencyname, oddsspread, odds, actual_stake, winlost, scomm, 
				acomm, comm, playercomm, actualrate)
	SELECT currency, currencyname,
		ISNULL(SUM(oddsspread),0) AS oddsspread,
		ISNULL(SUM(odds),0) AS odds,
		ISNULL(SUM(actual_stake),0) AS actual_stake,
		ISNULL(SUM(winlost),0) AS winlost,
		ISNULL(SUM(scomm),0) AS scomm,
		ISNULL(SUM(acomm),0) AS acomm,
		ISNULL(SUM(comm),0) AS comm,
		ISNULL(SUM(playercomm),0) AS playercomm,
		actualrate
	FROM dbo.bettrans b WITH(ROWLOCK, INDEX=CIX_matchid_bettype) 
	WHERE b.[statusID] IN (111,112,113)
		AND b.winlostdate = @date
		AND b.bettype = 1000
		AND b.matchid = 1000
	GROUP BY b.currency, actualrate, currencyname

	IF @date < '2012-06-01'
	BEGIN
		-- dummy bet
		-- Record Transfer Value  (gain -> winlost, paid -> actual_stake)  	
		INSERT INTO bettrans (  
			custid, creator, recommend, mrecommend, srecommend, matchid, bettype, winlostdate, ruben, [status], statusID,  
			actual_stake,  
			stake,  
			winlost,  
			awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm,  
			tpositiontaking, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount, adiscount, sdiscount,  
			oddsid, betteam, hdp1, hdp2, odds, modds, betfrom, transdesc,  
			actualrate, virtualrate, currency, refno, username, currencyName  
			)

		SELECT  
			c.custid, c.custid, c.recommend, c.mrecommend, c.srecommend, 1000, 1000, @date, 1, 'done', 121,  
			s.winlost,
			s.winlost,  
			s.actual_stake,
			0, 0, 0, -s.playercomm, -s.comm, -s.acomm, -s.scomm,
			0, 0, 0, 0, 0, 0, 0, 0,
			1000, '0', 0, 0, 0, 0, 'i', 'P2P-Dummy transfer',
			s.actualrate, s.actualrate, s.currency, 100000000000, c.username, s.currencyName
		FROM @sum s 
			INNER JOIN custinfo c WITH(NOLOCK) ON s.currency = c.currency
		WHERE c.username like 'P2PBet' + currencyname

		--- dummy comm income
		INSERT INTO bettrans (  
			custid, creator, recommend, mrecommend, srecommend, matchid, bettype, winlostdate, ruben, [status], statusID,  
			actual_stake,  
			stake,  
			winlost,  
			awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm,  
			tpositiontaking, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount, adiscount, sdiscount,  
			oddsid, betteam, hdp1, hdp2, odds, modds, betfrom, transdesc,  
			actualrate, virtualrate, currency, refno, username, currencyName  
			)

		SELECT  
			c.custid, c.custid, c.recommend, c.mrecommend, c.srecommend, 1000, 1000, @date, 1, 'done', 121,  
			s.odds, --- total ibc income
			s.odds,  
			s.scomm, -- total agency's comm
			0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0,
			1000, '0', 0, 0, 0, 0, 'i', 'P2P Dummy - IBC Comm Income',
			s.actualrate, s.actualrate, s.currency, 100000000000, c.username, s.currencyName
		FROM @sum s 
			INNER JOIN custinfo c WITH(NOLOCK) ON s.currency = c.currency
		WHERE c.username like 'P2PCommInc' + currencyname

		--- dummy comm expense
		INSERT INTO bettrans (  
			custid, creator, recommend, mrecommend, srecommend, matchid, bettype, winlostdate, ruben, [status], statusID,  
			actual_stake,  
			stake,  
			winlost,  
			awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm,  
			tpositiontaking, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount, adiscount, sdiscount,  
			oddsid, betteam, hdp1, hdp2, odds, modds, betfrom, transdesc,  
			actualrate, virtualrate, currency, refno, username, currencyName  
			)

		SELECT  
			c.custid, c.custid, c.recommend, c.mrecommend, c.srecommend, 1000, 1000, @date, 1, 'done', 121,  
			s.scomm,
			s.scomm,  
			0,
			0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0,
			1000, '0', 0, 0, 0, 0, 'i', 'P2P Dummy - IBC Comm Expense',
			s.actualrate, s.actualrate, s.currency, 100000000000, c.username, s.currencyName
		FROM @sum s 
			INNER JOIN custinfo c WITH(NOLOCK) ON s.currency = c.currency
		WHERE c.username like 'P2PCommExp' + currencyname

		--- dummy comm gross
		INSERT INTO bettrans (  
			custid, creator, recommend, mrecommend, srecommend, matchid, bettype, winlostdate, ruben, [status], statusID,  
			actual_stake,  
			stake,  
			winlost,  
			awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm,  
			tpositiontaking, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount, adiscount, sdiscount,  
			oddsid, betteam, hdp1, hdp2, odds, modds, betfrom, transdesc,  
			actualrate, virtualrate, currency, refno, username, currencyName  
			)

		SELECT  
			c.custid, c.custid, c.recommend, c.mrecommend, c.srecommend, 1000, 1000, @date, 1, 'done', 121,  
			0,
			0,  
			s.odds,
			0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0, 0,
			1000, '0', 0, 0, 0, 0, 'i', 'P2P Dummy - IBC Gross Comm',
			s.actualrate, s.actualrate, s.currency, 100000000000, c.username, s.currencyName
		FROM @sum s 
			INNER JOIN custinfo c WITH(NOLOCK) ON s.currency = c.currency
		WHERE c.username like 'P2PCommGross' + currencyname
	END

	-- dummy bet
	-- Record Transfer Value  (gain -> winlost, paid -> actual_stake)  	
	INSERT INTO bettrans2 (  
		custid, creator, recommend, mrecommend, srecommend, matchid, bettype, winlostdate, ruben, [status], statusID,  
		actual_stake,  
		stake,  
		winlost,  
		awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm,  
		tpositiontaking, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount, adiscount, sdiscount,  
		oddsid, betteam, hdp1, hdp2, odds, modds, betfrom, transdesc,  
		actualrate, virtualrate, currency, refno, username, currencyName  
		)

	SELECT  
		c.custid, c.custid, c.recommend, c.mrecommend, c.srecommend, 1000, 1000, @date, 1, 'done', 121,  
		s.winlost,
		s.winlost,  
		s.actual_stake,
		0, 0, 0, -s.playercomm, -s.comm, -s.acomm, -s.scomm,
		0, 0, 0, 0, 0, 0, 0, 0,
		1000, '0', 0, 0, 0, 0, 'i', 'P2P-Dummy transfer',
		s.actualrate, s.actualrate, s.currency, 100000000000, c.username, s.currencyName
	FROM @sum s 
		INNER JOIN custinfo c WITH(NOLOCK) ON s.currency = c.currency
	WHERE c.username like 'P2PBet' + currencyname

	--- dummy comm income
	INSERT INTO bettrans2 (  
		custid, creator, recommend, mrecommend, srecommend, matchid, bettype, winlostdate, ruben, [status], statusID,  
		actual_stake,  
		stake,  
		winlost,  
		awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm,  
		tpositiontaking, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount, adiscount, sdiscount,  
		oddsid, betteam, hdp1, hdp2, odds, modds, betfrom, transdesc,  
		actualrate, virtualrate, currency, refno, username, currencyName  
		)

	SELECT  
		c.custid, c.custid, c.recommend, c.mrecommend, c.srecommend, 1000, 1000, @date, 1, 'done', 121,  
		s.odds, --- total ibc income
		s.odds,  
		s.scomm, -- total agency's comm
		0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0,
		1000, '0', 0, 0, 0, 0, 'i', 'P2P Dummy - IBC Comm Income',
		s.actualrate, s.actualrate, s.currency, 100000000000, c.username, s.currencyName
	FROM @sum s 
		INNER JOIN custinfo c WITH(NOLOCK) ON s.currency = c.currency
	WHERE c.username like 'P2PCommInc' + currencyname

	--- dummy comm expense
	INSERT INTO bettrans2 (  
		custid, creator, recommend, mrecommend, srecommend, matchid, bettype, winlostdate, ruben, [status], statusID,  
		actual_stake,  
		stake,  
		winlost,  
		awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm,  
		tpositiontaking, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount, adiscount, sdiscount,  
		oddsid, betteam, hdp1, hdp2, odds, modds, betfrom, transdesc,  
		actualrate, virtualrate, currency, refno, username, currencyName  
		)

	SELECT  
		c.custid, c.custid, c.recommend, c.mrecommend, c.srecommend, 1000, 1000, @date, 1, 'done', 121,  
		s.scomm,
		s.scomm,  
		0,
		0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0,
		1000, '0', 0, 0, 0, 0, 'i', 'P2P Dummy - IBC Comm Expense',
		s.actualrate, s.actualrate, s.currency, 100000000000, c.username, s.currencyName
	FROM @sum s 
		INNER JOIN custinfo c WITH(NOLOCK) ON s.currency = c.currency
	WHERE c.username like 'P2PCommExp' + currencyname

	--- dummy comm gross
	INSERT INTO bettrans2 (  
		custid, creator, recommend, mrecommend, srecommend, matchid, bettype, winlostdate, ruben, [status], statusID,  
		actual_stake,  
		stake,  
		winlost,  
		awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm,  
		tpositiontaking, apositiontaking, mpositiontaking, spositiontaking, playerdiscount, discount, adiscount, sdiscount,  
		oddsid, betteam, hdp1, hdp2, odds, modds, betfrom, transdesc,  
		actualrate, virtualrate, currency, refno, username, currencyName  
		)

	SELECT  
		c.custid, c.custid, c.recommend, c.mrecommend, c.srecommend, 1000, 1000, @date, 1, 'done', 121,  
		0,
		0,  
		s.odds,
		0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0,
		1000, '0', 0, 0, 0, 0, 'i', 'P2P Dummy - IBC Gross Comm',
		s.actualrate, s.actualrate, s.currency, 100000000000, c.username, s.currencyName
	FROM @sum s 
		INNER JOIN custinfo c WITH(NOLOCK) ON s.currency = c.currency
	WHERE c.username like 'P2PCommGross' + currencyname

END

GO
GRANT VIEW DEFINITION ON [Task_DailyDummyTransfer_s253] TO vnteam