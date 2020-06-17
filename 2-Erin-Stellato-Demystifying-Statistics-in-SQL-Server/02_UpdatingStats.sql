/*============================================================================
  File:     02_UpdatingStats.sql

  SQL Server Versions: 2016, 2017
------------------------------------------------------------------------------
  Written by Erin Stellato, SQLskills.com
  
  (c) 2020, SQLskills.com. All rights reserved.

  For more scripts and sample code, check out 
    http://www.SQLskills.com

  You may alter this code for your own *non-commercial* purposes. You may
  republish altered code as long as you include this copyright and give due
  credit, but you must obtain prior permission before blogging this code.
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

USE WideWorldImportersB;
GO

/*
	look at statistics specific to the CustomerID index
*/
DBCC SHOW_STATISTICS ('Sales.Orders', FK_Sales_Orders_CustomerID);
GO


SET STATISTICS IO, TIME ON;
GO

SELECT 
	o.CustomerID,
	o.OrderDate,
	ol.StockItemID,
	ol.Quantity
FROM Sales.Orders o
JOIN Sales.OrderLines ol
	ON o.OrderID = ol.OrderID
WHERE CustomerID = 42

SELECT 
	o.CustomerID,
	o.OrderDate,
	ol.StockItemID,
	ol.Quantity
FROM Sales.Orders o
JOIN Sales.OrderLines ol
	ON o.OrderID = ol.OrderID
WHERE CustomerID = 823

SELECT 
	o.CustomerID,
	o.OrderDate,
	ol.StockItemID,
	ol.Quantity
FROM Sales.Orders o
JOIN Sales.OrderLines ol
	ON o.OrderID = ol.OrderID
WHERE CustomerID = 422

SET STATISTICS IO, TIME OFF;
GO

/*
	NOTE IO/TIME info:


*/

/*
	Check statistics
*/
DBCC SHOW_STATISTICS ('Sales.Orders', FK_Sales_Orders_CustomerID);
GO


/*
	Add A LOT of data to CustomerID 422
*/
UPDATE  Sales.Orders
SET CustomerID = 422
WHERE CustomerID < 110;
GO

/*
	Look at the LIVE execution plan
*/
SELECT 
	o.CustomerID,
	o.OrderDate,
	ol.StockItemID,
	ol.Quantity
FROM Sales.Orders o
JOIN Sales.OrderLines ol
	ON o.OrderID = ol.OrderID
WHERE CustomerID = 422;
GO





/*
	Enable auto update stats
	(turn OFF live execution plan)
*/
USE [master]
GO
ALTER DATABASE [WideWorldImportersB] SET AUTO_UPDATE_STATISTICS ON WITH NO_WAIT
GO

USE WideWorldImportersB;
GO

/*
	Enable actual execution plan
*/
SELECT 
	o.CustomerID,
	o.OrderDate,
	ol.StockItemID,
	ol.Quantity
FROM Sales.Orders o
JOIN Sales.OrderLines ol
	ON o.OrderID = ol.OrderID
WHERE CustomerID = 422;
GO

/*
	Check statistics again
*/
DBCC SHOW_STATISTICS ('Sales.Orders', FK_Sales_Orders_CustomerID);
GO


/******************************************

	BACK TO SLIDES FOR A MINUTE

******************************************/



/*
	Let's look a bit more at how stats updates affect procedures
*/
CREATE PROCEDURE Sales.OrderInfo @CustomerID INT
AS

SELECT 
	o.CustomerID,
	o.OrderDate,
	ol.StockItemID,
	ol.Quantity
FROM Sales.Orders o
JOIN Sales.OrderLines ol
	ON o.OrderID = ol.OrderID
WHERE CustomerID = @CustomerID;
GO

EXEC Sales.OrderInfo @CustomerID = 192
GO 10


SELECT 
	qs.execution_count, 
	qs.creation_time,
	qs.last_execution_time,
	qs.plan_generation_num,
	qs.query_hash, 
	qs.query_plan_hash, 
	qp.query_plan,
	s.text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_query_plan (qs.plan_handle) qp
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) s
WHERE s.text LIKE '%OrderLines%';


SELECT  
	[sch].[name] + '.' + [so].[name] AS [TableName] ,
	[ss].[name] AS [Statistic] ,
	[sp].[last_updated] AS [StatsLastUpdated] ,
	[sp].[rows] AS [RowsInTable] ,
	[sp].[rows_sampled] AS [RowsSampled] ,
	[sp].[modification_counter] AS [RowModifications] ,
	([sp].[rows]*.20) + 500 [OldThreshold],
	SQRT([sp].[rows]*1000) [NewThreshold]
FROM [sys].[stats] [ss]
JOIN [sys].[objects] [so] 
	ON [ss].[object_id] = [so].[object_id]
JOIN [sys].[schemas] [sch] 
	ON [so].[schema_id] = [sch].[schema_id]
LEFT OUTER JOIN [sys].[indexes] AS [si] 
	ON [so].[object_id] = [si].[object_id]
	AND [ss].[name] = [si].[name]
OUTER APPLY [sys].[dm_db_stats_properties]([so].[object_id], [ss].[stats_id]) sp
WHERE [so].[object_id] = OBJECT_ID(N'Sales.Orders')
ORDER BY [ss].[stats_id];
GO


/*
	Update > 60683 rows
*/
UPDATE Sales.Orders
	SET CustomerID = CustomerID + 1
WHERE CustomerID < 125


/*
	Validate the row modification counter
*/
SELECT  
	[sch].[name] + '.' + [so].[name] AS [TableName] ,
	[ss].[name] AS [Statistic] ,
	[sp].[last_updated] AS [StatsLastUpdated] ,
	[sp].[rows] AS [RowsInTable] ,
	[sp].[rows_sampled] AS [RowsSampled] ,
	[sp].[modification_counter] AS [RowModifications] ,
	([sp].[rows]*.20) + 500 [OldThreshold],
	SQRT([sp].[rows]*1000) [NewThreshold]
FROM [sys].[stats] [ss]
JOIN [sys].[objects] [so] 
	ON [ss].[object_id] = [so].[object_id]
JOIN [sys].[schemas] [sch] 
	ON [so].[schema_id] = [sch].[schema_id]
LEFT OUTER JOIN [sys].[indexes] AS [si] 
	ON [so].[object_id] = [si].[object_id]
	AND [ss].[name] = [si].[name]
OUTER APPLY [sys].[dm_db_stats_properties]([so].[object_id], [ss].[stats_id]) sp
WHERE [so].[object_id] = OBJECT_ID(N'Sales.Orders')
ORDER BY [ss].[stats_id];
GO


/*
	Run the SP
	Check the plan
*/
EXEC Sales.OrderInfo @CustomerID = 192


/*
	Stats updated?
*/
DBCC SHOW_STATISTICS ('Sales.Orders', FK_Sales_Orders_CustomerID);
GO

/*
	How do we know the stored procedure recompiled?
*/
SELECT 
	qs.execution_count, 
	qs.creation_time,
	qs.last_execution_time,
	qs.plan_generation_num,
	qs.query_hash, 
	qs.query_plan_hash, 
	qp.query_plan,
	s.text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_query_plan (qs.plan_handle) qp
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) s
WHERE s.text LIKE '%OrderLines%';


/*
	How to tie auto stats to recompiles (and potentially plan changes)?
*/
CREATE EVENT SESSION [Track_AutoStats] 
	ON SERVER 
ADD EVENT sqlserver.auto_stats(
    WHERE (
		[database_id]=(5)) /* it's always good to have a predicate */
		),
ADD EVENT sqlserver.sql_statement_recompile(
		SET collect_object_name=(1),collect_statement=(1)
    WHERE (
		[recompile_cause]=(2)
		)
	)
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,
MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,
TRACK_CAUSALITY=ON,STARTUP_STATE=OFF)
GO

ALTER EVENT SESSION [Track_AutoStats]
	ON SERVER
	STATE = START;
GO


/*
	Open XE Live Viewer
	Add more rows for CustomerID = 192
	(and modify some others)
*/
UPDATE Sales.Orders
	SET CustomerID = 192
WHERE CustomerID IN (138,139)

UPDATE Sales.Orders
	SET CustomerID = CustomerID + 1
WHERE CustomerID < 130


/*
	Verify how much data has changed
*/
SELECT  
	[sch].[name] + '.' + [so].[name] AS [TableName] ,
	[ss].[name] AS [Statistic] ,
	[sp].[last_updated] AS [StatsLastUpdated] ,
	[sp].[rows] AS [RowsInTable] ,
	[sp].[rows_sampled] AS [RowsSampled] ,
	[sp].[modification_counter] AS [RowModifications] ,
	[sp].[steps] AS [HistogramSteps],
	[ss].[no_recompute],
	([sp].[rows]*.20) + 500 [OldThreshold],
	SQRT([sp].[rows]*1000) [NewThreshold]
FROM [sys].[stats] [ss]
JOIN [sys].[objects] [so] 
	ON [ss].[object_id] = [so].[object_id]
JOIN [sys].[schemas] [sch] 
	ON [so].[schema_id] = [sch].[schema_id]
LEFT OUTER JOIN [sys].[indexes] AS [si] 
	ON [so].[object_id] = [si].[object_id]
	AND [ss].[name] = [si].[name]
OUTER APPLY [sys].[dm_db_stats_properties]([so].[object_id], [ss].[stats_id]) sp
WHERE [so].[object_id] = OBJECT_ID(N'Sales.Orders')
ORDER BY [ss].[stats_id];
GO

/*
	re-run the SP
*/
EXEC Sales.OrderInfo @CustomerID = 192


/*
	Stop the XE session
*/
ALTER EVENT SESSION [Track_AutoStats]
	ON SERVER
	STATE = STOP;
GO


/*
	Let's set up a potentially problematic scenario
*/
sp_recompile 'Sales.OrderInfo'

EXEC Sales.OrderInfo @CustomerID = 414  --907

UPDATE Sales.OrderLines
SET OrderID = OrderID + 0
WHERE OrderID >= 3600000
AND OrderID <=3620000


/*
	Verify we exceeded the threshold
*/
SELECT  
	[sch].[name] + '.' + [so].[name] AS [TableName] ,
	[ss].[name] AS [Statistic] ,
	[sp].[last_updated] AS [StatsLastUpdated] ,
	[sp].[rows] AS [RowsInTable] ,
	[sp].[rows_sampled] AS [RowsSampled] ,
	[sp].[modification_counter] AS [RowModifications] ,
	[sp].[steps] AS [HistogramSteps],
	[ss].[no_recompute],
	([sp].[rows]*.20) + 500 [OldThreshold],
	SQRT([sp].[rows]*1000) [NewThreshold]
FROM [sys].[stats] [ss]
JOIN [sys].[objects] [so] 
	ON [ss].[object_id] = [so].[object_id]
JOIN [sys].[schemas] [sch] 
	ON [so].[schema_id] = [sch].[schema_id]
LEFT OUTER JOIN [sys].[indexes] AS [si] 
	ON [so].[object_id] = [si].[object_id]
	AND [ss].[name] = [si].[name]
OUTER APPLY [sys].[dm_db_stats_properties]([so].[object_id], [ss].[stats_id]) sp
WHERE [so].[object_id] = OBJECT_ID(N'Sales.OrderLines')
ORDER BY [ss].[stats_id];
GO


/*
	Check the plan in cache
*/
SELECT 
	qs.execution_count, 
	qs.creation_time,
	qs.last_execution_time,
	qs.plan_generation_num,
	qs.query_hash, 
	qs.query_plan_hash, 
	qp.query_plan,
	s.text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_query_plan (qs.plan_handle) qp
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) s
WHERE s.text LIKE '%OrderLines%';

/*
	Run the query with a different input parameter
*/
EXEC Sales.OrderInfo @CustomerID = 907


/*
	Subsequent executions with unique parameters are slower...
	(can check Query Store)
*/
EXEC Sales.OrderInfo @CustomerID = 414 
EXEC Sales.OrderInfo @CustomerID = 441
EXEC Sales.OrderInfo @CustomerID = 467
EXEC Sales.OrderInfo @CustomerID = 190
EXEC Sales.OrderInfo @CustomerID = 194
EXEC Sales.OrderInfo @CustomerID = 967


/*
	Check cache
*/
SELECT 
	qs.execution_count, 
	qs.creation_time,
	qs.last_execution_time,
	qs.plan_generation_num,
	qs.query_hash, 
	qs.query_plan_hash, 
	qp.query_plan,
	s.text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_query_plan (qs.plan_handle) qp
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) s
WHERE s.text LIKE '%OrderLines%';

/*
	What's an initial troubleshooting response?
	Check stats...
*/
SELECT  
	[sch].[name] + '.' + [so].[name] AS [TableName] ,
	[ss].[name] AS [Statistic] ,
	[sp].[last_updated] AS [StatsLastUpdated] ,
	[sp].[rows] AS [RowsInTable] ,
	[sp].[rows_sampled] AS [RowsSampled] ,
	[sp].[modification_counter] AS [RowModifications] ,
	[sp].[steps] AS [HistogramSteps],
	[ss].[no_recompute]
FROM [sys].[stats] [ss]
JOIN [sys].[objects] [so] 
	ON [ss].[object_id] = [so].[object_id]
JOIN [sys].[schemas] [sch] 
	ON [so].[schema_id] = [sch].[schema_id]
LEFT OUTER JOIN [sys].[indexes] AS [si] 
	ON [so].[object_id] = [si].[object_id]
	AND [ss].[name] = [si].[name]
OUTER APPLY [sys].[dm_db_stats_properties]([so].[object_id], [ss].[stats_id]) sp
WHERE [so].[object_id] = OBJECT_ID(N'Sales.Orders')
ORDER BY [ss].[stats_id];
GO

/*
	"fix it"
*/
UPDATE STATISTICS Sales.Orders WITH FULLSCAN
GO

/*
	re-run SP
*/
EXEC Sales.OrderInfo @CustomerID = 414 


/*
	Why is the plan the same?
	Check cache and stats!
*/
SELECT  
	[sch].[name] + '.' + [so].[name] AS [TableName] ,
	[ss].[name] AS [Statistic] ,
	[sp].[last_updated] AS [StatsLastUpdated] ,
	[sp].[rows] AS [RowsInTable] ,
	[sp].[rows_sampled] AS [RowsSampled] ,
	[sp].[modification_counter] AS [RowModifications] ,
	[sp].[steps] AS [HistogramSteps],
	[ss].[no_recompute]
FROM [sys].[stats] [ss]
JOIN [sys].[objects] [so] 
	ON [ss].[object_id] = [so].[object_id]
JOIN [sys].[schemas] [sch] 
	ON [so].[schema_id] = [sch].[schema_id]
LEFT OUTER JOIN [sys].[indexes] AS [si] 
	ON [so].[object_id] = [si].[object_id]
	AND [ss].[name] = [si].[name]
OUTER APPLY [sys].[dm_db_stats_properties]([so].[object_id], [ss].[stats_id]) sp
WHERE [so].[object_id] = OBJECT_ID(N'Sales.Orders')
ORDER BY [ss].[stats_id];
GO

SELECT 
	qs.execution_count, 
	qs.creation_time,
	qs.last_execution_time,
	qs.plan_generation_num,
	qs.query_hash, 
	qs.query_plan_hash, 
	qp.query_plan,
	s.text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_query_plan (qs.plan_handle) qp
CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) s
WHERE s.text LIKE '%OrderLines%';
GO