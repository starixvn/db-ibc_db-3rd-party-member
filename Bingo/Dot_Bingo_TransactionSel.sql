USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Bingo_TransactionSel]    Script Date: 05/23/2011 06:40:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Dot_Bingo_TransactionSel]

		@username varchar(20),
		@fromdate datetime=null,
		@todate datetime=null,
		@refno bigint=null
AS
/*
Created by:[]
Date:
Task: 
DB: DB02.BODB02
Revisions:
    - 20110523@Henry: change bettype to new range
    
 */
declare @custid int

select @custid = custid from custinfo (nolock) where username = @username
if @custid is null
begin
	RAISERROR('username does not exist',16,1)
end


select transdate, refno, betid, transid, custid, actual_stake, winlost, playercomm, bettype,
case when bettype = 23201 then 'transfer to casino bingo' 
     when bettype = 23202 then 'pending' 
     when bettype = 73 then 'winloss sum' 
end as bettypename,
status,awinlost,comm,mwinlost,acomm,swinlost,scomm
from bettrans with (nolock)
where custid=@custid
and bettype in (23201,23202,73)
and (isnull(@refno,0) = 0 or refno = isnull(@refno,0))
and winlostdate >= @fromdate and winlostdate <=@todate

union

select transdate, refno, betid, transid, custid, actual_stake, winlost, playercomm, bettype,
case when bettype = 23201 then 'transfer to casino bingo' 
     when bettype = 23202 then 'pending' 
     when bettype = 73 then 'winloss sum' 
end as bettypename,
status,awinlost,comm,mwinlost,acomm,swinlost,scomm
from bettrans14 with (nolock)
where custid=@custid
and bettype in (23201,23202,73)
and (isnull(@refno,0) = 0 or refno = isnull(@refno,0))
and winlostdate >= @fromdate and winlostdate <=@todate

order by transdate

GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Bingo_TransactionSel] TO [vnteam]