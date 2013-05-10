 USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Casino_TransactionSel]    Script Date: 05/20/2011 00:16:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Dot_Casino_TransactionSel]

		@username varchar(20),
		@fromdate datetime=null,
		@todate datetime=null,
		@refno bigint=null
AS
/*
Creator :
Date :
Task : Get member's bet credit for Casino site using
DB: DB02.bodb02

History:
    - 20110520@Amy: Re-arrange bettype
	- 20120405@Hurri: Exclude bettype 72 (P2P bet ticket) and 23101 (transfer to P2P) in the calculation of Casino  
*/
declare @custid int

select @custid = custid from custinfo(nolock) where username = @username
if @custid is null
begin
	RAISERROR('username does not exist',16,1)
end


select transdate, refno, betid, transid, custid, actual_stake, winlost, playercomm, bettype,
case when bettype = 23001 then 'transfer to casino' when bettype = 23002 then 'pending' when bettype = 71 then 'winloss sum' end as bettypename,
status, awinlost, comm, mwinlost, acomm, swinlost, scomm
from bettrans with (nolock)
where custid=@custid
and bettype in (23001,23002,71)
and (isnull(@refno,0) = 0 or refno = isnull(@refno,0))
and winlostdate >= @fromdate and winlostdate <=@todate

union

select transdate, refno, betid, transid, custid, actual_stake, winlost, playercomm, bettype,
case when bettype = 23001 then 'transfer to casino' when bettype = 23002 then 'pending' when bettype = 71 then 'winloss sum' end as bettypename,
status, awinlost, comm, mwinlost, acomm, swinlost, scomm
from bettrans14 with (nolock)
where custid=@custid
and bettype in (23001,23002,71)
and (isnull(@refno,0) = 0 or refno = isnull(@refno,0))
and winlostdate >= @fromdate and winlostdate <=@todate

order by transdate

GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Casino_TransactionSel] TO [vnteam]