﻿/*
common
*/
------------------------------------------------
create or alter function cat.fn_GetAgentName(@TenantId int, @Id bigint)
returns nvarchar(255)
as
begin
	declare @name nvarchar(255);
	if @Id is not null
		select @name = [Name] from cat.Agents where TenantId=@TenantId and Id=@Id;
	return @name;
end
go
------------------------------------------------
create or alter function cat.fn_GetWarehouseName(@TenantId int, @Id bigint)
returns nvarchar(255)
as
begin
	declare @name nvarchar(255);
	if @Id is not null
		select @name = [Name] from cat.Warehouses where TenantId=@TenantId and Id=@Id;
	return @name;
end
go
------------------------------------------------
create or alter function cat.fn_GetCompanyName(@TenantId int, @Id bigint)
returns nvarchar(255)
as
begin
	declare @name nvarchar(255);
	if @Id is not null
		select @name = [Name] from cat.Companies where TenantId=@TenantId and Id=@Id;
	return @name;
end
go
------------------------------------------------
create or alter function cat.fn_GetBankAccountName(@TenantId int, @Id bigint)
returns nvarchar(255)
as
begin
	declare @name nvarchar(255);
	if @Id is not null
		select @name = isnull([Name], AccountNo) from cat.BankAccounts where TenantId=@TenantId and Id=@Id;
	return @name;
end
go
------------------------------------------------
create or alter function cat.fn_GetCashAccountName(@TenantId int, @Id bigint)
returns nvarchar(255)
as
begin
	declare @name nvarchar(255);
	if @Id is not null
		select @name = [Name] from cat.CashAccounts where TenantId=@TenantId and Id=@Id;
	return @name;
end
go
------------------------------------------------
create or alter function a2sys.fn_GetCurrentTenant(@TenantId int)
returns int
as
begin
	if @TenantId is null
		set @TenantId = isnull(cast(session_context(N'TenantId') as int), 1);
	return @TenantId;
end
go
