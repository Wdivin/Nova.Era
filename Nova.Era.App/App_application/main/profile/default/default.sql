﻿/* Profile.Default */
------------------------------------------------
create or alter procedure usr.[Default.Load]
@TenantId int = 1,
@UserId bigint
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	select [Default!TDefault!Object] = null,
		[Company.Id!TCompany!Id] = d.Company, [Company.Name!TCompany!Name] = c.[Name],
		[Warehouse.Id!TWarehouse!Id] = d.Warehouse, [Warehouse.Name!TWarehouse!Name] = w.[Name],
		[RespCenter.Id!TRespCenter!Id] = d.RespCenter, [RespCenter.Name!TRespCenter!Name] = rc.[Name],
		[Period.From!TPeriod!] = isnull(d.PeriodFrom, getdate()), [Period.To!TPeriod!] = isnull(d.PeriodTo, getdate())
	from usr.Defaults d
		left join cat.Companies c on d.TenantId = c.TenantId and d.Company = c.Id
		left join cat.Warehouses w on d.TenantId = w.TenantId and d.Warehouse = w.Id
		left join cat.RespCenters rc on d.TenantId = rc.TenantId and d.RespCenter =rc.Id
	where d.TenantId = @TenantId and d.UserId = @UserId;
end
go
------------------------------------------------
create or alter procedure usr.[Default.Ensure] 
@TenantId int = 1, 
@UserId bigint
as
begin
	set nocount on;
	set transaction isolation level read committed;
	if not exists(select * from usr.Defaults where TenantId = @TenantId and UserId = @UserId)
		insert into usr.Defaults(TenantId, UserId) values (@TenantId, @UserId);
end
go
------------------------------------------------
create or alter procedure usr.[Default.SetCompany]
@TenantId int = 1,
@UserId bigint,
@Id bigint
as
begin
	set nocount on;
	set transaction isolation level read committed;

	exec usr.[Default.Ensure] @TenantId = @TenantId, @UserId = @UserId;
	update usr.Defaults set Company = @Id where TenantId = @TenantId and UserId = @UserId;
end
go
------------------------------------------------
create or alter procedure usr.[Default.SetWarehouse]
@TenantId int = 1,
@UserId bigint,
@Id bigint
as
begin
	set nocount on;
	set transaction isolation level read committed;

	exec usr.[Default.Ensure] @TenantId = @TenantId, @UserId = @UserId;
	update usr.Defaults set Warehouse = @Id where TenantId = @TenantId and UserId = @UserId;
end
go
------------------------------------------------
create or alter procedure usr.[Default.SetRespCenter]
@TenantId int = 1,
@UserId bigint,
@Id bigint
as
begin
	set nocount on;
	set transaction isolation level read committed;

	exec usr.[Default.Ensure] @TenantId = @TenantId, @UserId = @UserId;
	update usr.Defaults set RespCenter = @Id where TenantId = @TenantId and UserId = @UserId;
end
go
------------------------------------------------
create or alter procedure usr.[Default.SetPeriod]
@TenantId int = 1,
@UserId bigint,
@From date,
@To date
as
begin
	set nocount on;
	set transaction isolation level read committed;

	exec usr.[Default.Ensure] @TenantId = @TenantId, @UserId = @UserId;
	update usr.Defaults set PeriodFrom = @From, PeriodTo=@To where TenantId = @TenantId and UserId = @UserId;
end
go
------------------------------------------------
create or alter procedure usr.[Default.GetUserPeriod]
@TenantId int = 1,
@UserId bigint,
@From date output,
@To date output
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	if @From is not null and @To is not null
		return;
	exec usr.[Default.Ensure] @TenantId = @TenantId, @UserId = @UserId;
	select @From = [PeriodFrom], @To = [PeriodTo] from usr.Defaults where TenantId = @TenantId and UserId = @UserId;
	if @From is null or @To is null
	begin
		update usr.Defaults set PeriodFrom = getdate(), PeriodTo = getdate() where TenantId = @TenantId and UserId = @UserId;
		select @From = [PeriodFrom], @To = [PeriodTo] from usr.Defaults where TenantId = @TenantId and UserId = @UserId;
	end
end
go
