﻿/* Document */
------------------------------------------------
create or alter procedure doc.[Document.Stock.Index]
@TenantId int = 1,
@UserId bigint,
@Menu nvarchar(255),
@Offset int = 0,
@PageSize int = 20,
@Order nvarchar(255) = N'date',
@Dir nvarchar(20) = N'asc',
@Operation bigint = -1
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	set @Order = lower(@Order);
	set @Dir = lower(@Dir);

	declare @docs table(rowno int identity(1, 1), id bigint, op bigint, agent bigint, 
		comp bigint, rowcnt int);

	insert into @docs(id, op, agent, comp, rowcnt)
	select d.Id, d.Operation, d.Agent, d.Company, 
		count(*) over()
	from doc.Documents d
		inner join doc.Operations o on d.TenantId = o.TenantId and d.Operation = o.Id
	where d.TenantId = @TenantId and o.Menu = @Menu
		and (@Operation = -1 or d.Operation = @Operation)
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

	select [Documents!TDocument!Array] = null, [Id!!Id] = d.Id, d.[Date], d.[Sum], d.[Memo],
		[Operation!TOperation!RefId] = d.Operation, 
		[Agent!TAgent!RefId] = d.Agent, [Company!TCompany!RefId] = d.Company,
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

	with T as (select comp from @docs group by comp)
	select [!TCompany!Map] = null, [Id!!Id] = c.Id, [Name!!Name] = c.[Name]
	from cat.Companies c 
		inner join T t on c.TenantId = @TenantId and c.Id = comp;

	-- filters
	select [Forms!TForm!Array] = null, [Id!!Id] = f.Id, [Name!!Name] = f.[Name]
	from doc.Operations o
		inner join doc.Forms f on o.TenantId = f.TenantId and o.Form = f.Id
	where o.TenantId = @TenantId and o.Menu = @Menu
	group by f.Id, f.[Name]
	order by f.Id desc;

	-- filters
	select [Operations!TOperation!Array] = null, [Id!!Id] = -1, [Name!!Name] = N'@[Filter.AllOperations]', null, [!Order] = -1
	union all
	select [Operations!TOperation!Array] = null, [Id!!Id] = o.Id, [Name!!Name] = o.[Name], o.[Form], [!Order] = o.Id
	from doc.Operations o
	where o.TenantId = @TenantId and o.Menu = @Menu
	order by [!Order];


	select [!$System!] = null, [!Documents!Offset] = @Offset, [!Documents!PageSize] = @PageSize, 
		[!Documents!SortOrder] = @Order, [!Documents!SortDir] = @Dir,
		[!Documents.Operation!Filter] = @Operation;
end
go
------------------------------------------------
create or alter procedure doc.[Document.Stock.Load]
@TenantId int = 1,
@UserId bigint,
@Id bigint = null,
@Form nvarchar(16) = null
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @docform nvarchar(16);
	if @Id is not null
		select @docform = o.Form 
		from doc.Documents d inner join doc.Operations o on d.TenantId = o.TenantId and d.Operation = o.Id
		where d.TenantId = @TenantId and d.Id = @Id;

	select [Document!TDocument!Object] = null, [Id!!Id] = d.Id, [Date], d.Memo, d.[Sum],
		[Operation!TOperation!RefId] = d.Operation, [Agent!TAgent!RefId] = d.Agent,
		[Company!TCompany!RefId] = d.Company,
		[Rows!TRow!Array] = null
	from doc.Documents d
	where d.TenantId = @TenantId and d.Id = @Id;

	declare @rows table(id bigint, item bigint);
	insert into @rows (id, item)
	select Id, Item from doc.DocDetails dd
	where dd.TenantId = @TenantId and dd.Document = @Id;

	select [!TRow!Array] = null, [Id!!Id] = dd.Id, [Qty], Price, [Sum], 
		[Item!TItem!RefId] = Item, [Unit!TUnit!RefId] = Unit,
		[!TDocument.Rows!ParentId] = dd.Document, [RowNo!!RowNumber] = RowNo
	from doc.DocDetails dd
	where dd.TenantId=@TenantId and dd.Document = @Id;

	select [!TOperation!Map] = null, [Id!!Id] = o.Id, [Name!!Name] = o.[Name], o.Form
	from doc.Operations o 
		left join doc.Documents d on d.TenantId = o.TenantId and d.Operation = o.Id
	where d.Id = @Id and d.TenantId = @TenantId;

	select [!TAgent!Map] = null, [Id!!Id] = a.Id, [Name!!Name] = a.[Name]
	from cat.Agents a inner join doc.Documents d on d.TenantId = a.TenantId and d.Agent = a.Id
	where d.Id = @Id and d.TenantId = @TenantId;

	select [!TCompany!Map] = null, [Id!!Id] = c.Id, [Name!!Name] = c.[Name]
	from cat.Companies c inner join doc.Documents d on d.TenantId = c.TenantId and d.Company = c.Id
	where d.Id = @Id and d.TenantId = @TenantId;

	with T as (select item from @rows group by item)
	select [!TItem!Map] = null, [Id!!Id] = i.Id, [Name!!Name] = [Name]
	from cat.Items i inner join T on i.Id = T.item and i.TenantId = @TenantId
	where i.TenantId = @TenantId;

	select [Operations!TOperation!Array] = null, [Id!!Id] = Id, [Name!!Name] = [Name], [Form]
	from doc.Operations where Form = @Form or Form=@docform
	order by Id;
end
go
------------------------------------------------
drop procedure if exists doc.[Document.Stock.Metadata];
drop procedure if exists doc.[Document.Stock.Update];
drop type if exists cat.[Document.Stock.TableType];
drop type if exists cat.[Document.Stock.Row.TableType];
go
------------------------------------------------
create type cat.[Document.Stock.TableType]
as table(
	Id bigint null,
	[Date] datetime,
	[Sum] money,
	Operation bigint,
	Agent bigint,
	Company bigint,
	Memo nvarchar(255)
)
go
------------------------------------------------
create type cat.[Document.Stock.Row.TableType]
as table(
	Id bigint null,
	ParentId bigint,
	RowNo int,
	Item bigint,
	[Qty] float,
	[Price] money,
	[Sum] money,
	Memo nvarchar(255)
)
go
------------------------------------------------
create or alter procedure doc.[Document.Stock.Metadata]
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	declare @Document cat.[Document.Stock.TableType];
	declare @Rows cat.[Document.Stock.Row.TableType]
	select [Document!Document!Metadata] = null, * from @Document;
	select [Rows!Document.Rows!Metadata] = null, * from @Rows;
end
go
------------------------------------------------
create or alter procedure doc.[Document.Stock.Update]
@TenantId int = 1,
@UserId bigint,
@Document cat.[Document.Stock.TableType] readonly,
@Rows cat.[Document.Stock.Row.TableType] readonly
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
		t.Memo = s.Memo
	when not matched by target then insert
		(TenantId, Operation, [Date], [Sum], Company, Agent, Memo) values
		(@TenantId, s.Operation, s.[Date], s.[Sum], s.Company, s.Agent, s.Memo)
	output inserted.Id into @rtable(id);
	select top(1) @id = id from @rtable;

	with DD as (select * from doc.DocDetails where TenantId = @TenantId and Document = @id)
	merge DD as t
	using @Rows as s on t.Id = s.Id
	when matched then update set
		t.RowNo = s.RowNo,
		t.Item = s.Item,
		t.Qty = s.Qty,
		t.Price = s.Price,
		t.[Sum] = s.[Sum]
	when not matched by target then insert
		(TenantId, Document, RowNo, Item, Qty, Price, [Sum]) values
		(@TenantId, @id, s.RowNo, s.Item, s.Qty, s.Price, s.[Sum])
	when not matched by source and t.TenantId = @TenantId and t.Document = @id then delete;

	exec doc.[Document.Stock.Load] @TenantId = @TenantId, 
	@UserId = @UserId, @Id = @id;
end
go