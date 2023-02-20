USE [dev]
GO
/****** Object:  Table [dbo].[scope_info]    Script Date: 2/20/2023 2:58:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[scope_info](
	[sync_scope_name] [nvarchar](100) NOT NULL,
	[sync_scope_schema] [nvarchar](max) NULL,
	[sync_scope_setup] [nvarchar](max) NULL,
	[sync_scope_version] [nvarchar](10) NULL,
	[sync_scope_last_clean_timestamp] [bigint] NULL,
	[sync_scope_properties] [nvarchar](max) NULL,
 CONSTRAINT [PKey_scope_info_server] PRIMARY KEY CLUSTERED 
(
	[sync_scope_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[scope_info_client]    Script Date: 2/20/2023 2:58:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[scope_info_client](
	[sync_scope_id] [uniqueidentifier] NOT NULL,
	[sync_scope_name] [nvarchar](100) NOT NULL,
	[sync_scope_hash] [nvarchar](100) NOT NULL,
	[sync_scope_parameters] [nvarchar](max) NULL,
	[scope_last_sync_timestamp] [bigint] NULL,
	[scope_last_server_sync_timestamp] [bigint] NULL,
	[scope_last_sync_duration] [bigint] NULL,
	[scope_last_sync] [datetime] NULL,
	[sync_scope_errors] [nvarchar](max) NULL,
	[sync_scope_properties] [nvarchar](max) NULL,
 CONSTRAINT [PKey_scope_info_client] PRIMARY KEY CLUSTERED 
(
	[sync_scope_id] ASC,
	[sync_scope_name] ASC,
	[sync_scope_hash] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[users]    Script Date: 2/20/2023 2:58:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[users](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[name] [nchar](10) NULL,
 CONSTRAINT [PK_users] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  StoredProcedure [dbo].[users_devpreprod_bulkdelete]    Script Date: 2/20/2023 2:58:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[users_devpreprod_bulkdelete]
	@sync_min_timestamp bigint,
	@sync_scope_id uniqueidentifier,
	@changeTable [dbo].[users_devpreprod_BulkType] READONLY
AS
BEGIN
-- use a temp table to store the list of PKs that successfully got deleted
declare @dms_changed TABLE ([id] int,  PRIMARY KEY ( [id]));

DECLARE @var_sync_scope_id varbinary(128) = cast(@sync_scope_id as varbinary(128));

;WITH 
  CHANGE_TRACKING_CONTEXT(@var_sync_scope_id),
  [users_tracking] AS (
	SELECT [p].[id], 
	CAST([CT].[SYS_CHANGE_CONTEXT] as uniqueidentifier) AS [sync_update_scope_id], 
	[CT].[SYS_CHANGE_VERSION] as [sync_timestamp],
	CASE WHEN [CT].[SYS_CHANGE_OPERATION] = 'D' THEN 1 ELSE 0 END AS [sync_row_is_tombstone]
	FROM @changeTable AS [p] 
	LEFT JOIN CHANGETABLE(CHANGES [dbo].[users], @sync_min_timestamp) AS [CT] ON [p].[id] = [CT].[id]
	)
DELETE [dbo].[users]
OUTPUT  DELETED.[id]
INTO @dms_changed 
FROM [users] [base]
JOIN [users_tracking] [changes] ON [changes].[id] = [base].[id]
WHERE [changes].[sync_timestamp] <= @sync_min_timestamp OR [changes].[sync_timestamp] IS NULL OR [changes].[sync_update_scope_id] = @sync_scope_id;



--Select all ids not inserted / deleted / updated as conflict
SELECT  [t].[id] ,[t].[name]
FROM @changeTable [t]
WHERE NOT EXISTS (
	 SELECT  [id]	 FROM @dms_changed [i]
	 WHERE  [t].[id] = [i].[id]	)

END
GO
/****** Object:  StoredProcedure [dbo].[users_devpreprod_bulkupdate]    Script Date: 2/20/2023 2:58:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[users_devpreprod_bulkupdate]
	@sync_min_timestamp bigint,
	@sync_scope_id uniqueidentifier,
	@changeTable [dbo].[users_devpreprod_BulkType] READONLY
AS
BEGIN
-- use a temp table to store the list of PKs that successfully got updated/inserted
declare @dms_changed TABLE ([id] int,  PRIMARY KEY ( [id]));


SET IDENTITY_INSERT [dbo].[users] ON;

DECLARE @var_sync_scope_id varbinary(128) = cast(@sync_scope_id as varbinary(128));

;WITH 
  CHANGE_TRACKING_CONTEXT(@var_sync_scope_id),
  [users_tracking] AS (
	SELECT [p].[id], [p].[name], 
	CAST([CT].[SYS_CHANGE_CONTEXT] AS uniqueidentifier) AS [sync_update_scope_id],
	[CT].[SYS_CHANGE_VERSION] AS [sync_timestamp],
	CASE WHEN [CT].[SYS_CHANGE_OPERATION] = 'D' THEN 1 ELSE 0 END AS [sync_row_is_tombstone]
	FROM @changeTable AS [p]
	LEFT JOIN CHANGETABLE(CHANGES [dbo].[users], @sync_min_timestamp) AS [CT] ON [CT].[id] = [p].[id]
	)
MERGE [dbo].[users] AS [base]
USING [users_tracking] as [changes] ON [changes].[id] = [base].[id]
WHEN MATCHED AND (
	[changes].[sync_timestamp] <= @sync_min_timestamp
	OR [changes].[sync_timestamp] IS NULL
	OR [changes].[sync_update_scope_id] = @sync_scope_id
) THEN
	UPDATE SET
	[name] = [changes].[name]
WHEN NOT MATCHED BY TARGET AND ([changes].[sync_timestamp] <= @sync_min_timestamp OR [changes].[sync_timestamp] IS NULL) THEN

	INSERT
	([id], [name])
	VALUES ([changes].[id], [changes].[name])

OUTPUT  INSERTED.[id]
	INTO @dms_changed; -- populates the temp table with successful PKs


SET IDENTITY_INSERT [dbo].[users] OFF;

--Select all ids not inserted / deleted / updated as conflict
SELECT  [t].[id] ,[t].[name]
FROM @changeTable [t]
WHERE NOT EXISTS (
	 SELECT  [id]	 FROM @dms_changed [i]
	 WHERE  [t].[id] = [i].[id]	)

END
GO
/****** Object:  StoredProcedure [dbo].[users_devpreprod_changes]    Script Date: 2/20/2023 2:58:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[users_devpreprod_changes]
	@sync_min_timestamp bigint,
	@sync_scope_id uniqueidentifier
AS
BEGIN
;WITH 
  [users_tracking] AS (
	SELECT [CT].[id], 
	CAST([CT].[SYS_CHANGE_CONTEXT] AS uniqueidentifier) AS [sync_update_scope_id],
	[CT].[SYS_CHANGE_VERSION] AS [sync_timestamp],
	CASE WHEN [CT].[SYS_CHANGE_OPERATION] = 'D' THEN 1 ELSE 0 END AS [sync_row_is_tombstone]
	FROM CHANGETABLE(CHANGES [dbo].[users], @sync_min_timestamp) AS [CT]
	)
SELECT DISTINCT
	[side].[id], 
	[base].[name], 
	[side].[sync_row_is_tombstone],
	[side].[sync_update_scope_id]
FROM [dbo].[users] [base]
RIGHT JOIN [users_tracking] [side]ON [base].[id] = [side].[id]
WHERE (
	[side].[sync_timestamp] > @sync_min_timestamp
	AND ([side].[sync_update_scope_id] <> @sync_scope_id OR [side].[sync_update_scope_id] IS NULL)
)

END
GO
/****** Object:  StoredProcedure [dbo].[users_devpreprod_delete]    Script Date: 2/20/2023 2:58:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[users_devpreprod_delete]
	@id int,
	@sync_force_write int,
	@sync_min_timestamp bigint,
	@sync_scope_id uniqueidentifier,
	@sync_row_count int OUTPUT
AS
BEGIN
SET @sync_row_count = 0;

DECLARE @var_sync_scope_id varbinary(128) = cast(@sync_scope_id as varbinary(128));

;WITH 
  CHANGE_TRACKING_CONTEXT(@var_sync_scope_id),
  [users_tracking] AS (
	SELECT [p].[id], 
	CAST([CT].[SYS_CHANGE_CONTEXT] as uniqueidentifier) AS [sync_update_scope_id],
	[CT].[SYS_CHANGE_VERSION] as [sync_timestamp],
	CASE WHEN [CT].[SYS_CHANGE_OPERATION] = 'D' THEN 1 ELSE 0 END AS [sync_row_is_tombstone]
	FROM (SELECT @id as [id]) AS [p]
	LEFT JOIN CHANGETABLE(CHANGES [dbo].[users], @sync_min_timestamp) AS [CT] ON [CT].[id] = [p].[id]	)
DELETE [dbo].[users]
FROM [dbo].[users] [base]
JOIN [users_tracking] [side] ON [base].[id] = [side].[id]
WHERE ([side].[sync_timestamp] <= @sync_min_timestamp OR [side].[sync_timestamp] IS NULL OR [side].[sync_update_scope_id] = @sync_scope_id OR @sync_force_write = 1)
AND ([base].[id] = @id);

SET @sync_row_count = @@ROWCOUNT;

END
GO
/****** Object:  StoredProcedure [dbo].[users_devpreprod_initialize]    Script Date: 2/20/2023 2:58:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[users_devpreprod_initialize]
	@sync_min_timestamp bigint = NULL
AS
BEGIN
;WITH 
  [users_tracking] AS (
	SELECT [CT].[id], 
	CAST([CT].[SYS_CHANGE_CONTEXT] as uniqueidentifier) AS [sync_update_scope_id], 
	[CT].[SYS_CHANGE_VERSION] as [sync_timestamp],
	CASE WHEN [CT].[SYS_CHANGE_OPERATION] = 'D' THEN 1 ELSE 0 END AS [sync_row_is_tombstone]
	FROM CHANGETABLE(CHANGES [dbo].[users], @sync_min_timestamp) AS [CT]
	)
SELECT 
	  [base].[id]
	, [base].[name]
	, [side].[sync_row_is_tombstone] as [sync_row_is_tombstone]
FROM [dbo].[users] [base]
LEFT JOIN [users_tracking] [side] ON [base].[id] = [side].[id]
WHERE (
	([side].[sync_timestamp] > @sync_min_timestamp OR @sync_min_timestamp IS NULL)
)
UNION
SELECT
	  [side].[id]
	, [base].[name]
	, [side].[sync_row_is_tombstone] as [sync_row_is_tombstone]
FROM [dbo].[users] [base]
RIGHT JOIN [users_tracking] [side] ON [base].[id] = [side].[id]
WHERE ([side].[sync_timestamp] > @sync_min_timestamp AND [side].[sync_row_is_tombstone] = 1);

END
GO
/****** Object:  StoredProcedure [dbo].[users_devpreprod_update]    Script Date: 2/20/2023 2:58:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[users_devpreprod_update]
	@id int,
	@name nchar (10) = NULL,
	@sync_min_timestamp bigint,
	@sync_scope_id uniqueidentifier,
	@sync_force_write int,
	@sync_row_count int OUTPUT
AS
BEGIN

SET IDENTITY_INSERT [dbo].[users] ON;

DECLARE @var_sync_scope_id varbinary(128) = cast(@sync_scope_id as varbinary(128));

SET @sync_row_count = 0;

;WITH 
  CHANGE_TRACKING_CONTEXT(@var_sync_scope_id),
  [users_tracking] AS (
	SELECT [p].[id], [p].[name], 
	CAST([CT].[SYS_CHANGE_CONTEXT] as uniqueidentifier) AS [sync_update_scope_id],
	[CT].[SYS_CHANGE_VERSION] AS [sync_timestamp],
	CASE WHEN [CT].[SYS_CHANGE_OPERATION] = 'D' THEN 1 ELSE 0 END AS [sync_row_is_tombstone]
	FROM (SELECT 
		 @id as [id], @name as [name]) AS [p]
	LEFT JOIN CHANGETABLE(CHANGES [dbo].[users], @sync_min_timestamp) AS [CT] ON [CT].[id] = [p].[id]	)
MERGE [dbo].[users] AS [base]
USING [users_tracking] as [changes] ON [changes].[id] = [base].[id]
WHEN MATCHED AND (
	[changes].[sync_timestamp] <= @sync_min_timestamp
	OR [changes].[sync_timestamp] IS NULL
	OR [changes].[sync_update_scope_id] = @sync_scope_id
	OR @sync_force_write = 1
) THEN
	UPDATE SET
	[name] = [changes].[name]
WHEN NOT MATCHED BY TARGET AND ([changes].[sync_timestamp] <= @sync_min_timestamp OR [changes].[sync_timestamp] IS NULL OR @sync_force_write = 1) THEN

	INSERT
	([id], [name])
	VALUES ([changes].[id], [changes].[name]);

SET @sync_row_count = @@ROWCOUNT;

SET IDENTITY_INSERT [dbo].[users] OFF;


END
GO
