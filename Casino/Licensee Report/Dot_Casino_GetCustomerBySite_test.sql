USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Casino_GetCustomerBySite_test]    Script Date: 01/25/2013 00:06:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Dot_Casino_GetCustomerBySite_test]  
	@Sitename	Varchar(50)
AS
-- 2013/01/04@Victor(DB06): Create SP for RNG get Custid,Username By Site

SET NOCOUNT ON

If @Sitename = '1b88'
	Begin 
		select CM.Custid,CM.Username,CM.roleid from customer CM with(nolock) join custinfo Cu with(nolock)
		on CM.custid = Cu.Custid
		where CM.site ='789y' and ((CM.roleid =4 and CM.srecommend>100)  or (CM.roleid =3 and CM.srecommend < 100))
		and Cu.SyncCasino=1
	End
If @Sitename = 'ibcbet'
	Begin 
		select CM.Custid,CM.Username,CM.roleid from customer CM with(nolock) join custinfo Cu with(nolock)
		on CM.custid = Cu.Custid
		where CM.site in ('BEST-ODDS','INDO','XYZBET','611111','722222','733333','755555','222223','222225','222227','spotico','33333','KORIBC') 
		and ((CM.roleid =4 and CM.srecommend>100)  or (CM.roleid =3 and CM.srecommend < 100))
		and Cu.SyncCasino=1
	End

