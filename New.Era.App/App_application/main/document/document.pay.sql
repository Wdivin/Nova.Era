﻿/* Document.Pay */
------------------------------------------------
create or alter procedure doc.[Document.Pay.Index]
@TenantId int = 1,
@UserId bigint,
@Menu nvarchar(255),
@Offset int = 0,
@PageSize int = 20,
@Order nvarchar(255) = N'date',
@Dir nvarchar(20) = N'asc',
@Operation bigint = -1,
@Agent bigint = null,
@CashAccount bigint = null,
@Company bigint = null,
@From date = null,
@To date = null
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	exec usr.[Default.GetUserPeriod] @TenantId = @TenantId, @UserId = @UserId, @From = @From output, @To = @To output;
	declare @end date;
	set @end = dateadd(day, 1, @To);

	set @Order = lower(@Order);
	set @Dir = lower(@Dir);

	declare @docs table(rowno int identity(1, 1), id bigint, op bigint, agent bigint, 
		comp bigint, bafrom bigint, bato bigint, cafrom bigint, cato bigint, rowcnt int);

	insert into @docs(id, op, agent, comp, cafrom, cato, rowcnt)
	select d.Id, d.Operation, d.Agent, d.Company, d.CashAccFrom, d.CashAccTo,
		count(*) over()
	from doc.Documents d
		inner join doc.Operations o on d.TenantId = o.TenantId and d.Operation = o.Id
		inner join ui.OpMenuLinks ml on o.TenantId = ml.TenantId and d.Operation = ml.Operation
	where d.TenantId = @TenantId and ml.Menu = @Menu
		and (d.[Date] >= @From and d.[Date] < @end)
		and (@Operation = -1 or d.Operation = @Operation)
		and (@Agent is null or d.Agent = @Agent)
		and (@Company is null or d.Company = @Company)
		and (@CashAccount is null or d.CashAccFrom = @CashAccount or d.CashAccTo = @CashAccount)
	order by 
		case when @Dir = N'asc' then
			case @Order 
				when N'date' then d.[Date]
			end
		end asc,
		case when @Dir = N'asc' then
			case @Order 
				when N'sum' then d.[Sum]
			end
		end asc,
		case when @Dir = N'desc' then
			case @Order
				when N'date' then d.[Date]
			end
		end desc,
		case when @Dir = N'desc' then
			case @Order
				when N'sum' then d.[Sum]
			end
		end desc
	offset @Offset rows fetch next @PageSize rows only
	option (recompile);

	select [Documents!TDocument!Array] = null, [Id!!Id] = d.Id, d.[Date], d.[Sum], d.[Memo], d.[Notice], d.Done,
		[Operation!TOperation!RefId] = d.Operation, 
		[Agent!TAgent!RefId] = d.Agent, [Company!TCompany!RefId] = d.Company,
		[CashAccFrom!TCashAccount!RefId] = d.CashAccFrom, [CashAccTo!TCashAccount!RefId] = d.CashAccTo,
		[!!RowCount] = t.rowcnt
	from @docs t inner join 
		doc.Documents d on d.TenantId = @TenantId and d.Id = t.id
	order by t.rowno;

	-- maps
	with T as (select op from @docs group by op)
	select [!TOperation!Map] = null, [Id!!Id] = o.Id, [Name!!Name] = o.[Name], o.Form
	from doc.Operations o 
		inner join T t on o.TenantId = @TenantId and o.Id = op;

	with T as (select agent from @docs group by agent)
	select [!TAgent!Map] = null, [Id!!Id] = a.Id, [Name!!Name] = a.[Name]
	from cat.Agents a 
		inner join T t on a.TenantId = @TenantId and a.Id = agent;

	with C as (select ca = cafrom from @docs union all select cato from @docs),
	T as (select ca from C group by ca)
	select [!TCashAccount!Map] = null, [Id!!Id] = ca.Id, [Name!!Name] = ca.[Name], ca.[AccountNo]
	from cat.CashAccounts ca 
		inner join T t on ca.TenantId = @TenantId and ca.Id = ca;

	with T as (select comp from @docs group by comp)
	select [!TCompany!Map] = null, [Id!!Id] = c.Id, [Name!!Name] = c.[Name]
	from cat.Companies c 
		inner join T t on c.TenantId = @TenantId and c.Id = comp;

	-- menu
	select [Menu!TMenu!Array] = null, [Id!!Id] = o.Id, [Name!!Name] = o.[Name], FormId = f.Id, FormName = f.[Name]
	from doc.Operations o
		inner join doc.Forms f on o.TenantId = f.TenantId and o.Form = f.Id
		inner join ui.OpMenuLinks ml on o.TenantId = ml.TenantId and o.Id = ml.Operation
	where o.TenantId = @TenantId and ml.Menu = @Menu
	order by f.[Order] desc;

	-- filters
	select [Operations!TOperation!Array] = null, [Id!!Id] = -1, [Name!!Name] = N'@[Filter.AllOperations]', null, [!Order] = -1
	union all
	select [Operations!TOperation!Array] = null, [Id!!Id] = o.Id, [Name!!Name] = o.[Name], o.[Form], [!Order] = o.Id
	from doc.Operations o
		inner join ui.OpMenuLinks ml on o.TenantId = ml.TenantId and o.Id = ml.Operation
	where o.TenantId = @TenantId and ml.Menu = @Menu
	order by [!Order];

	select [!$System!] = null, [!Documents!Offset] = @Offset, [!Documents!PageSize] = @PageSize, 
		[!Documents!SortOrder] = @Order, [!Documents!SortDir] = @Dir,
		[!Documents.Period.From!Filter] = @From, [!Documents.Period.To!Filter] = @To,
		[!Documents.Operation!Filter] = @Operation, 
		[!Documents.Agent.Id!Filter] = @Agent, [!Documents.Agent.Name!Filter] = cat.fn_GetAgentName(@TenantId, @Agent),
		[!Documents.Company.Id!Filter] = @Company, [!Documents.Company.Name!Filter] = cat.fn_GetCompanyName(@TenantId, @Company),
		[!Documents.CashAccount.Id!Filter] = @CashAccount, [!Documents.CashAccount.Name!Filter] = cat.fn_GetCashAccountName(@TenantId, @CashAccount);
end
go
------------------------------------------------
create or alter procedure doc.[Document.Pay.Load]
@TenantId int = 1,
@UserId bigint,
@Id bigint = null,
@Operation bigint = null
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @docform nvarchar(16);
	declare @done bit;

	if @Operation is null
		select @Operation = d.Operation from doc.Documents d where d.TenantId = @TenantId and d.Id = @Id;

	select @docform = o.Form from doc.Operations o where o.TenantId = @TenantId and o.Id = @Operation;

	select [Document!TDocument!Object] = null, [Id!!Id] = d.Id, [Date], d.Memo, d.Notice, d.[Sum], d.Done,
		[Operation!TOperation!RefId] = d.Operation, [Agent!TAgent!RefId] = d.Agent,
		[Company!TCompany!RefId] = d.Company, 
		[CashAccFrom!TCashAccount!RefId] = d.CashAccFrom, [CashAccTo!TCashAccount!RefId] = d.CashAccTo,
		[Contract!TContract!RefId] = d.[Contract], [CashFlowItem!TCashFlowItem!RefId] = d.CashFlowItem,
		[Rows!TRow!Array] = null
	from doc.Documents d
	where d.TenantId = @TenantId and d.Id = @Id;

	select [!TOperation!Map] = null, [Id!!Id] = o.Id, [Name!!Name] = o.[Name], o.Form
	from doc.Operations o 
		left join doc.Documents d on d.TenantId = o.TenantId and d.Operation = o.Id
	where d.Id = @Id and d.TenantId = @TenantId;

	select [!TAgent!Map] = null, [Id!!Id] = a.Id, [Name!!Name] = a.[Name]
	from cat.Agents a inner join doc.Documents d on d.TenantId = a.TenantId and d.Agent = a.Id
	where d.Id = @Id and d.TenantId = @TenantId;

	select [!TCashAccount!Map] = null, [Id!!Id] = ca.Id, [Name!!Name] = ca.[Name], ca.AccountNo
	from cat.CashAccounts ca inner join doc.Documents d on d.TenantId = ca.TenantId and ca.Id in (d.CashAccFrom, d.CashAccTo)
	where d.Id = @Id and d.TenantId = @TenantId
	group by ca.Id, ca.[Name], ca.AccountNo;

	select [!TCashFlowItem!Map] = null, [Id!!Id] = cf.Id, [Name!!Name] = cf.[Name]
	from cat.CashFlowItems cf inner join doc.Documents d on d.TenantId = cf.TenantId and cf.Id = d.CashFlowItem
	where d.Id = @Id and d.TenantId = @TenantId
	group by cf.Id, cf.[Name];

	select [!TCompany!Map] = null, [Id!!Id] = c.Id, [Name!!Name] = c.[Name]
	from cat.Companies c inner join doc.Documents d on d.TenantId = c.TenantId and d.Company = c.Id
	where d.Id = @Id and d.TenantId = @TenantId;

	select [Operations!TOperation!Array] = null, [Id!!Id] = Id, [Name!!Name] = [Name], [Form]
	from doc.Operations where TenantId = @TenantId and Form=@docform
	order by Id;

	select [!TContract!Map] = null, [Id!!Id] = c.Id, [Name!!Name] = c.[Name], c.[Date], c.[SNo]
	from doc.Contracts c inner join doc.Documents d on d.TenantId = c.TenantId and d.[Contract] = c.Id
	where d.Id = @Id and d.TenantId = @TenantId;

	select [Params!TParam!Object] = null, [Operation] = @Operation;

	exec usr.[Default.Load] @TenantId = @TenantId, @UserId = @UserId;

	select [!$System!] = null, [!!ReadOnly] = d.Done
	from doc.Documents d where TenantId = @TenantId and Id = @Id;
end
go
------------------------------------------------
drop procedure if exists doc.[Document.Pay.Metadata];
drop procedure if exists doc.[Document.Pay.Update];
drop type if exists doc.[Document.Pay.TableType];
go
------------------------------------------------
create type doc.[Document.Pay.TableType]
as table(
	Id bigint null,
	[Date] datetime,
	[Sum] money,
	Operation bigint,
	Agent bigint,
	Company bigint,
	CashAccFrom bigint,
	CashAccTo bigint,
	[Contract] bigint,
	[CashFlowItem] bigint,
	Memo nvarchar(255),
	Notice nvarchar(255)
)
go
------------------------------------------------
create or alter procedure doc.[Document.Pay.Metadata]
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	declare @Document doc.[Document.Pay.TableType];
	select [Document!Document!Metadata] = null, * from @Document;
end
go
------------------------------------------------
create or alter procedure doc.[Document.Pay.Update]
@TenantId int = 1,
@UserId bigint,
@Document doc.[Document.Pay.TableType] readonly
as
begin
	set nocount on;
	set transaction isolation level read committed;

	declare @rtable table(id bigint);
	declare @id bigint;

	merge doc.Documents as t
	using @Document as s
	on t.TenantId = @TenantId and t.Id = s.Id
	when matched then update set
		t.Operation = s.Operation,
		t.[Date] = s.[Date],
		t.[Sum] = s.[Sum],
		t.Company = s.Company,
		t.Agent = s.Agent,
		t.CashAccFrom = s.CashAccFrom,
		t.CashAccTo = s.CashAccTo,
		t.[Contract] = s.[Contract],
		t.CashFlowItem = s.CashFlowItem,
		t.Memo = s.Memo,
		t.Notice = s.Notice
	when not matched by target then insert
		(TenantId, Operation, [Date], [Sum], Company, Agent, 
			CashAccFrom, CashAccTo, [Contract], CashFlowItem, Memo, Notice, UserCreated) values
		(@TenantId, s.Operation, s.[Date], s.[Sum], s.Company, s.Agent, 
			s.CashAccFrom, s.CashAccTo, s.[Contract], s.CashFlowItem, s.Memo, s.Notice, @UserId)
	output inserted.Id into @rtable(id);
	select top(1) @id = id from @rtable;

	exec doc.[Document.Pay.Load] @TenantId = @TenantId, 
	@UserId = @UserId, @Id = @id;
end
go

