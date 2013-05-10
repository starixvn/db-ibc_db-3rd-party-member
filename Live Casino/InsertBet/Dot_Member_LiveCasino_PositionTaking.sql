USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Member_LiveCasino_PositionTaking]    Script Date: 09/17/2012 22:57:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Dot_Member_LiveCasino_PositionTaking] 
	@custid	int, 	
	@sporttype int=162,
	@bettype int=1101
AS
BEGIN
/*
Creator : Joe Huang
Date : 2011-12-05
Task : Get CustUserSeting to Casino
DB: transDB.bodb02

History:
	--20110513@TWJoe: Create SP
	--20120907@vivi:1102 using 1101 PT
*/

SET NOCOUNT ON

	DECLARE @CustSettingBettype int
	
	SET @CustSettingBettype = case
		when @bettype = 1102 then 1101 --20120907@vivi: Get Baccarat(1101) for Roulette(1102)
		else @bettype end
		
	SELECT  o.currency as currency,
			o.srecommend as srecommend,
			o.mrecommend as mrecommend,
			o.recommend as recommend,
			e.actualrate as actualrate,
			s.apositiontaking as apositiontaking,
			s.mpositiontaking as mpositiontaking,
			s.spositiontaking as spositiontaking,
			s.playerdiscount as playerdiscount,
			s.discount as discount,
			s.adiscount as adiscount,
			s.sdiscount as sdiscount,
			o.ugroup as ugroup
	from CustSettingGame s with (nolock) 
		inner join Customer o with (nolock) on  s.custid = o.custid
		inner join exchange e with (nolock) on o.currency = e.exchangeid
	where s.custid = @custid
		and s.sporttype = @sporttype
		and s.bettype = @CustSettingBettype
END
