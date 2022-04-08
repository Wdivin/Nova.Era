﻿/*
version: 10.1.1012
generated: 08.04.2022 08:02:18
*/


/* SqlScripts/catalog.sql */

if not exists(select * from INFORMATION_SCHEMA.SCHEMATA where SCHEMA_NAME=N'a2sys')
	exec sp_executesql N'create schema a2sys';
go
grant execute on schema ::a2sys to public;
go
------------------------------------------------
if not exists(select * from INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA=N'a2sys' and TABLE_NAME=N'SysParams')
create table a2sys.SysParams
(
	Name sysname not null constraint PK_SysParams primary key,
	StringValue nvarchar(255) null,
	IntValue int null,
	DateValue datetime null
);
go

-- security schema
------------------------------------------------
if not exists(select * from INFORMATION_SCHEMA.SCHEMATA where SCHEMA_NAME=N'appsec')
	exec sp_executesql N'create schema appsec';
go
------------------------------------------------
if not exists(select * from INFORMATION_SCHEMA.SCHEMATA where SCHEMA_NAME=N'a2security')
	exec sp_executesql N'create schema a2security';
go
grant execute on schema::appsec to public;
grant execute on schema::a2security to public;
go
------------------------------------------------
if not exists(select * from INFORMATION_SCHEMA.SEQUENCES where SEQUENCE_SCHEMA=N'appsec' and SEQUENCE_NAME=N'SQ_Tenants')
	create sequence appsec.SQ_Tenants as bigint start with 100 increment by 1;
go
------------------------------------------------
if not exists(select * from INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA=N'appsec' and TABLE_NAME=N'Tenants')
begin
	create table appsec.Tenants
	(
		Id	int not null constraint PK_Tenants primary key
			constraint DF_Tenants_PK default(next value for appsec.SQ_Tenants),
		[Admin] bigint null, -- admin user ID
		[Source] nvarchar(255) null,
		[TransactionCount] bigint not null constraint DF_Tenants_TransactionCount default(0),
		LastTransactionDate datetime null,
		UtcDateCreated datetime not null constraint DF_Tenants_UtcDateCreated default(getutcdate()),
		TrialPeriodExpired datetime null,
		DataSize float null,
		[State] nvarchar(128) null,
		UserSince datetime null,
		LastPaymentDate datetime null,
		[Locale] nvarchar(32) not null constraint DF_Tenants_Locale default('uk-UA')
	);
end
go
------------------------------------------------
if not exists(select * from INFORMATION_SCHEMA.SEQUENCES where SEQUENCE_SCHEMA=N'appsec' and SEQUENCE_NAME=N'SQ_Users')
	create sequence appsec.SQ_Users as bigint start with 100 increment by 1;
go
------------------------------------------------
if not exists(select * from INFORMATION_SCHEMA.TABLES where TABLE_SCHEMA=N'appsec' and TABLE_NAME=N'Users')
create table appsec.Users
(
	Id	bigint not null
		constraint DF_Users_PK default(next value for appsec.SQ_Users),
	Tenant int not null 
		constraint FK_Users_Tenant_Tenants foreign key references appsec.Tenants(Id),
	UserName nvarchar(255) not null constraint UNQ_Users_UserName unique,
	DomainUser nvarchar(255) null,
	Void bit not null constraint DF_Users_Void default(0),
	SecurityStamp nvarchar(max) not null,
	PasswordHash nvarchar(max) null,
	/*for .net core compatibility*/
	SecurityStamp2 nvarchar(max) null,
	PasswordHash2 nvarchar(max) null,
	TwoFactorEnabled bit not null constraint DF_Users_TwoFactorEnabled default(0),
	Email nvarchar(255) null,
	EmailConfirmed bit not null constraint DF_Users_EmailConfirmed default(0),
	PhoneNumber nvarchar(255) null,
	PhoneNumberConfirmed bit not null constraint DF_Users_PhoneNumberConfirmed default(0),
	LockoutEnabled	bit	not null constraint DF_Users_LockoutEnabled default(1),
	LockoutEndDateUtc datetimeoffset null,
	AccessFailedCount int not null constraint DF_Users_AccessFailedCount default(0),
	[Locale] nvarchar(32) not null constraint DF_Users_Locale2 default('uk-UA'),
	PersonName nvarchar(255) null,
	LastLoginDate datetime null, /*UTC*/
	LastLoginHost nvarchar(255) null,
	Memo nvarchar(255) null,
	ChangePasswordEnabled bit not null constraint DF_Users_ChangePasswordEnabled default(1),
	RegisterHost nvarchar(255) null,
	Segment nvarchar(32) null,
	UtcDateCreated datetime not null constraint DF_Users_UtcDateCreated default(getutcdate()),
	constraint PK_Users primary key (Tenant, Id)
);
go
------------------------------------------------
create or alter view appsec.ViewUsers
as
	select Id, UserName, DomainUser, PasswordHash, SecurityStamp, Email, PhoneNumber,
		LockoutEnabled, AccessFailedCount, LockoutEndDateUtc, TwoFactorEnabled, [Locale],
		PersonName, Memo, Void, LastLoginDate, LastLoginHost, Tenant, EmailConfirmed,
		PhoneNumberConfirmed, RegisterHost, ChangePasswordEnabled, Segment,
		SecurityStamp2, PasswordHash2
	from appsec.Users u
	where Void=0 and Id <> 0;
go
------------------------------------------------
create or alter procedure appsec.FindUserById
@Id bigint
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	select * from appsec.ViewUsers where Id=@Id;
end
go
------------------------------------------------
create or alter procedure appsec.FindUserByEmail
@Email nvarchar(255)
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	select * from appsec.ViewUsers where Email=@Email;
end
go
------------------------------------------------
create or alter procedure appsec.FindUserByName
@UserName nvarchar(255)
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	select * from appsec.ViewUsers where UserName=@UserName;
end
go
------------------------------------------------
create or alter procedure appsec.GetUserGroups
@UserId bigint
as
begin
	set nocount on;
	-- do nothing
end
go
------------------------------------------------
create or alter procedure appsec.UpdateUserLogin
@Id bigint,
@LastLoginDate datetime,
@LastLoginHost nvarchar(255)
as
begin
	set nocount on;
	set transaction isolation level read committed;
	update appsec.ViewUsers set LastLoginDate = @LastLoginDate, LastLoginHost = @LastLoginHost where Id=@Id;
end
go
------------------------------------------------
create or alter procedure appsec.CreateUser
@UserName nvarchar(255),
@PasswordHash nvarchar(max) = null,
@SecurityStamp nvarchar(max),
@Email nvarchar(255) = null,
@PhoneNumber nvarchar(255) = null,
@Tenant int = null,
@PersonName nvarchar(255) = null,
@RegisterHost nvarchar(255) = null,
@Memo nvarchar(255) = null,
@TariffPlan nvarchar(255) = null,
@Locale nvarchar(255) = null,
@RetId bigint output
as
begin
	-- from account/register only
	set nocount on;
	set transaction isolation level read committed;
	set xact_abort on;
	
	set @Locale = isnull(@Locale, N'uk-UA')

	declare @userId bigint; 

	declare @tenants table(id int);
	declare @users table(id bigint);
	declare @tenantId int;

	begin tran;
	insert into appsec.Tenants([Admin], Locale)
		output inserted.Id into @tenants(id)
	values (null, @Locale);

	select top(1) @tenantId = id from @tenants;

	insert into appsec.ViewUsers(UserName, PasswordHash, SecurityStamp, Email, PhoneNumber, Tenant, PersonName, 
		RegisterHost, Memo, Segment, Locale)
		output inserted.Id into @users(id)
		values (@UserName, @PasswordHash, @SecurityStamp, @Email, @PhoneNumber, @tenantId, @PersonName, 
			@RegisterHost, @Memo, a2security.fn_GetCurrentSegment(), @Locale);
	select top(1) @userId = id from @users;

	update appsec.Tenants set [Admin] = @userId where Id=@tenantId;

	commit tran;
	set @RetId = @userId;
end
go
------------------------------------------------
if exists (select * from INFORMATION_SCHEMA.ROUTINES where ROUTINE_SCHEMA=N'appsec' and ROUTINE_NAME=N'ConfirmEmail')
	drop procedure appsec.ConfirmEmail
go
------------------------------------------------
create procedure appsec.ConfirmEmail
@Id bigint
as
begin
	set nocount on;
	set transaction isolation level read committed;
	set xact_abort on;

	update appsec.ViewUsers set EmailConfirmed = 1 where Id=@Id;
end
go
------------------------------------------------
create or alter procedure a2security.[User.CheckRegister]
@UserName nvarchar(255)
as
begin
	set nocount on;
	set transaction isolation level read committed;
	set xact_abort on;

	declare @Id bigint;

	select @Id = Id from appsec.Users where UserName=@UserName and EmailConfirmed = 0 and PhoneNumberConfirmed = 0;

	if @Id is not null
	begin
		declare @uid nvarchar(255);
		set @uid = N'_' + convert(nvarchar(255), newid());
		update appsec.Users set Void=1, UserName = UserName + @uid, 
			Email = Email + @uid, PhoneNumber = PhoneNumber + @uid, PasswordHash = null, SecurityStamp = N''
		where Id=@Id and EmailConfirmed = 0  and PhoneNumberConfirmed = 0 and UserName=@UserName;
	end
end
go

------------------------------------------------
if not exists(select * from INFORMATION_SCHEMA.SCHEMATA where SCHEMA_NAME=N'a2ui')
	exec sp_executesql N'create schema a2ui';
go
grant execute on schema ::a2ui to public;
go
------------------------------------------------
create or alter procedure a2ui.[AppTitle.Load]
as
begin
	set nocount on;
	select [AppTitle], [AppSubTitle]
	from (select Name, Value=StringValue from a2sys.SysParams) as s
		pivot (min(Value) for Name in ([AppTitle], [AppSubTitle])) as p;
end
go
