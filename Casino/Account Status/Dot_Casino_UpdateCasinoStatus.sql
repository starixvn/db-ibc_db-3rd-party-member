 USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Dot_Casino_UpdateCasinoStatus]    Script Date: 11/22/2012 23:58:14 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.Dot_Casino_UpdateCasinoStatus    Script Date: 11/9/2012 1:09:09 PM ******/
ALTER PROCEDURE [dbo].[Dot_Casino_UpdateCasinoStatus]
	@custid int,
	@disabledCS bit,
	@enableDownline bit=0,
	@CSAdminID varchar(30),
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT,
	@IP varchar(15)=''
AS
/*
Created: 20090421@PhuongDoan
Task: Update casino status
DB: DB02.bodb02
Original:

History:
    - 20121026@Elodie: Modify to write log update into our Customer_Log DB instead of Userlog table.
 
*/
SET NOCOUNT ON
declare @startRun datetime, @endRun datetime, @duration int
set @startRun = getdate()

declare @Allow2Udpate bit, @SyncCasino bit ,@RoleID tinyint, @Old_DisabledCS bit
select @SyncCasino=SyncCasino,@RoleID=RoleID, @Old_DisabledCS=DisableCasino from custinfo(nolock) where custid=@custid
if(@RoleID is null or @roleid > 4) 
begin
	select @ErrCode=101,@ErrMsg='Unexisting or invalid customer account'
	return
end

if @SyncCasino = 0
begin
	select @ErrCode=102,@ErrMsg='Account hasn''t been set casino setting, no need to change Enable Status'
	return
end

if(@roleid = 4)
	select @Allow2Udpate=1
else
	select @Allow2Udpate= IsNull((SyncCasino & ~DisableCasino),0)
	from custinfo(nolock)
	where
	custid = (select case roleid when 1 then recommend
								when 2 then mrecommend
								when 3 then srecommend end
		  from custinfo(nolock) where custid=@custid)

if @Allow2Udpate = 0
begin
	select @ErrCode=103,@ErrMsg='This account''s parent hasn''t been set casino setting or is disabled'
	return
end

BEGIN TRANSACTION
	-- Update itself
	UPDATE CustInfo SET
		DisableCasino = @disabledCS
	WHERE custid=@custid
	if (@@error <> 0)
	begin
		ROLLBACK TRANSACTION
		Select @ErrMsg ='Update process is unsuccessful !', @ErrCode = 104
		return
	end

	-- Update downline
	IF @disabledCS = 1 OR @enableDownline = 1
	BEGIN
	UPDATE CustInfo SET
		DisableCasino = @disabledCS
	WHERE SyncCasino=1 and (srecommend=@custid or mrecommend=@custid or recommend=@custid)
	END 
	if (@@error <> 0)
	begin
		ROLLBACK TRANSACTION
		Select @ErrMsg ='Update process is unsuccessful !', @ErrCode = 104
		return
	end

COMMIT TRANSACTION

------------------write log------------------ 
DECLARE @LogData NVARCHAR(200)
DECLARE @TrackingValue2 NVARCHAR(200)
---------------------------
select @LogData ='<Dot_Casino_UpdateCasinoStatus custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +
'disabledCS="'+ coalesce(cast(@disabledCS as varchar(50)),space(1)) + '" ' +
'enableDownline="'+ coalesce(cast(@enableDownline as varchar(50)),space(1)) + '" ' +
'FromSite="Casino Admin" ' +
'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(200)),space(1))+'" ' +
'IP="'+ coalesce(cast(@IP as varchar(15)),space(1))+'" />'

select @TrackingValue2 ='<Dot_Casino_UpdateCasinoStatus custid="'+ coalesce(cast(@custid as varchar(50)),space(1)) + '" ' +
'disabledCS="'+ coalesce(cast(@Old_disabledCS as varchar(50)),space(1)) + '" ' +
'enableDownline="'+ coalesce(cast(@enableDownline as varchar(50)),space(1)) + '" ' +
'FromSite="Casino Admin" ' +
'ErrCode="'+ coalesce(cast(@ErrCode as varchar(50)),space(1)) + '" ' +
'ErrMsg="'+ coalesce(cast(@ErrMsg as varchar(200)),space(1))+'" ' +
'IP="'+ coalesce(cast(@IP as varchar(15)),space(1))+'" />'

set @endRun = getdate()
set @duration  = datediff (millisecond,@startRun,@endRun)

EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
	@UserID = @CsAdminID, 
	@CustID = @custid,
	@ActionID = 1143,
	@TrackingValue = @LogData,
	@TrackingValue2 = @TrackingValue2,
	@duration = @duration