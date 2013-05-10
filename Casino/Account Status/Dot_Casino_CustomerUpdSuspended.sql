 USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Casino_CustomerUpdSuspended]    Script Date: 11/23/2012 00:00:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Dot_Casino_CustomerUpdSuspended    Script Date: 11/9/2012 1:09:09 PM ******/
 ALTER PROCEDURE [dbo].[Dot_Casino_CustomerUpdSuspended]
	@CustID int,
	@Suspended bit,
	@CsAdminID varchar(30),
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@IP varchar(15)=''
AS
/*
Creator : Phuong Doan
Date : 2009-02-25
Task : Update Suspended status
DB: DB02.bodb02

History:
    - 20121026@Elodie: Modify to write log update into our Customer_Log DB instead of Userlog table.
    
Param's Explanation:
	• @CustID: affected user 
	• @CSAdminID: ID of casino admin who does this action  
	• @ErrCode:
		= 0: Transaction recorded successfully.
		> 0: Specific Error.
	• @ErrMsg: Error description.
	• @IP: IP of reseter

*/
SET NOCOUNT ON
declare @startRun datetime, @endRun datetime, @duration int
set @startRun = getdate()

Declare @RoleID tinyint , @UplineSuspended bit ,@UplineClosed bit, @Old_Suspended bit, @parentID int
select @RoleID = RoleID, @Old_Suspended = isnull(reject,0),
@parentID = case RoleID when 1 then recommend when 2 then mrecommend when 3 then srecommend else 0 end 

from Custinfo with (nolock)
where CustID = @CustID
select @roleid = isnull(@roleid, 0)
--Do not allow casino admin update status of users other than member, agent, master, super
if @RoleID not in (1,2,3,4)
begin
	SELECT @ErrMsg =  'Invalid account', @ErrCode = 101
	return
end

select @UplineSuspended = isnull(reject,0),@UplineClosed = isnull(closed,0) from custinfo where custid = @parentID 

IF @UplineClosed = 1 
BEGIN
	SELECT @ErrMsg =  'Parent account was closed. Cannot edit member.', @ErrCode = 102
	return
END 

IF @UplineSuspended = 1 and @Old_Suspended <> @Suspended
BEGIN
	SELECT @ErrMsg = 'Parent account was suspended. Cannot edit member.', @ErrCode = 103
	return
END 

select @RoleID = isnull(@RoleID, 0)

IF @Old_Suspended = @Suspended RETURN 
-------------

update CustInfo with (ROWLOCK, UPDLOCK) set Reject = @Suspended
where CustID = @CustID
if (@@error <> 0)
begin
	
	Select @ErrMsg ='Update process is unsuccessful !', @ErrCode = 104
	return
end

if @RoleID = 4 
BEGIN
	update CustInfo with (ROWLOCK, UPDLOCK) set Reject = @Suspended where SRecommend = @CustID
	if (@@error <> 0)
	begin
		
		Select @ErrMsg = 'Update process is unsuccessful !', @ErrCode = 104
	return
	end
END

if @RoleID = 3 
BEGIN
	update CustInfo with (ROWLOCK, UPDLOCK) set Reject = @Suspended where MRecommend = @CustID
	if (@@error <> 0)
	begin
		
		Select @ErrMsg ='Update process is unsuccessful !', @ErrCode = 104
	return
	end
END

if @RoleID = 2 
BEGIN
	update CustInfo with (ROWLOCK, UPDLOCK) set Reject = @Suspended where Recommend = @CustID
	if (@@error <> 0)
	begin
		
		Select @ErrMsg = 'Update process is unsuccessful !', @ErrCode = 104
	return
	end
END
---------------
	
DECLARE @LogData NVARCHAR(200)
DECLARE @TrackingValue2 NVARCHAR(200)
---------------------------
select @LogData ='<Dot_Casino_CustomerUpdSuspended custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +
'Suspended="'+ coalesce(cast(@Suspended as varchar(50)),space(1)) + '" ' +
'FromSite="Casino Admin" ' +
'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(200)),space(1))+'" ' +
'IP="'+ coalesce(cast(@IP as varchar(15)),space(1))+'" />'

select @TrackingValue2 ='<Dot_Casino_CustomerUpdSuspended custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +
'Suspended="'+ coalesce(cast(@Old_Suspended as varchar(50)),space(1)) + '" ' +
'FromSite="Casino Admin" ' +
'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(200)),space(1))+'" ' +
'IP="'+ coalesce(cast(@IP as varchar(15)),space(1))+'" />'

set @endRun = getdate()
set @duration  = datediff (millisecond,@startRun,@endRun)

EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
	@UserID = @CsAdminID, 
	@CustID = @custid,
	@ActionID = 1144,
	@TrackingValue = @LogData,
	@TrackingValue2 = @TrackingValue2,
	@duration = @duration
-------------------------------

---WRITE TO LOG ON DB06 HERE---
-------------------------------