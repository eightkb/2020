/*============================================================================
  File:     01_ViewingStats.sql 

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

EXEC sp_helpindex 'Sales.Orders';
GO

EXEC sp_SQLskills_helpindex 'Sales.Orders';
GO


/*
	check stats
*/
SELECT 
	OBJECT_NAME(object_id) AS [Table], 
	name, 
	stats_id, 
	auto_created, 
	user_created
FROM sys.stats
WHERE object_id = OBJECT_ID(N'Sales.Orders');
GO


/*
	deprecated...
*/
EXEC sp_helpstats 'Sales.Orders', 'ALL';
GO


/*
	look at statistics specific to the CustomerID index
*/
DBCC SHOW_STATISTICS ('Sales.Orders', FK_Sales_Orders_CustomerID);
GO


/*
	alternatives in SQL 2016+
*/
SELECT *
FROM sys.dm_db_stats_properties(OBJECT_ID('Sales.Orders'), 2);
GO

SELECT *
FROM sys.dm_db_stats_histogram(OBJECT_ID('Sales.Orders'), 2);
GO


/*
	Enable Execution Plan + runtime stats
	Histogram lists 5295 values for CustomerID 42
*/
SELECT CustomerID, OrderDate
FROM Sales.Orders
WHERE CustomerID = 42;
GO

/*
	look at statistics specific to the CustomerID index
*/
DBCC SHOW_STATISTICS ('Sales.Orders', FK_Sales_Orders_CustomerID);
GO


/*
	Try a value that's *NOT* in the histogram
	Histogram estimates 5404 values for CustomerIDs between 50 and 55
*/
SELECT CustomerID, OrderDate
FROM Sales.Orders
WHERE CustomerID = 52;
GO


/*
	What if use a local variable?
*/
DECLARE @CustomerID INT
SET @CustomerID = 42

SELECT CustomerID, OrderDate
FROM Sales.Orders
WHERE CustomerID = @CustomerID;
GO


/*
	Value for CustomerID not know at optimization time, uses density instead
	Estimate here is 5845
	Density vector is 0.001587302

*/
SELECT 3682507*0.001587302


/******************************************

	BACK TO SLIDES FOR A QUICK MINUTE

******************************************/


/*
	What if use a local variable but no equality?
*/
DECLARE @CustomerID INT
SET @CustomerID = 42

SELECT CustomerID, OrderDate
FROM Sales.Orders
WHERE CustomerID < @CustomerID;
GO

/*
	Estimate here is 1104750
*/
SELECT 3682507*0.30



/*
	Put this into a SP
*/

CREATE OR ALTER PROCEDURE Sales.CustomerInfo 
	@CustomerID INT
AS
BEGIN
	SELECT CustomerID, OrderDate
	FROM Sales.Orders
	WHERE CustomerID = @CustomerID;
END
GO

SET STATISTICS IO, TIME ON;
GO

EXEC Sales.CustomerInfo @CustomerID = 42;
GO

EXEC Sales.CustomerInfo @CustomerID = 823;
GO


/*
	Declare and set the variable after the fact - 
	estimate goes back to density vector
*/
CREATE OR ALTER PROCEDURE Sales.CustomerInfo 
	@OrderID INT
AS
BEGIN

	DECLARE @CustomerID INT

	SELECT @CustomerID = CustomerID
	FROM Sales.Orders
	WHERE OrderID = @OrderID

	SELECT CustomerID, OrderDate
	FROM Sales.Orders
	WHERE CustomerID = @CustomerID;
END
GO

EXEC Sales.CustomerInfo @OrderID = 3571311;
GO

EXEC Sales.CustomerInfo @OrderID = 12930;

GO


/*
	Let's look at a range of data
*/
SELECT
	o.[CustomerID],
	o.[OrderDate],
	o.ExpectedDeliveryDate,
	o.[ContactPersonID],
	ol.StockItemID,
	ol.PickedQuantity
FROM [Sales].[Orders] o
JOIN [Sales].[OrderLines] ol
	ON o.OrderID = ol.OrderID
WHERE [OrderDate] >= '2016-01-01 00:00:00.000' 
	AND OrderDate <= '2016-01-30 23:59:59.997'
ORDER BY [OrderDate]
OPTION (RECOMPILE);
GO

SELECT
	o.[CustomerID],
	o.[OrderDate],
	o.ExpectedDeliveryDate,
	o.[ContactPersonID],
	ol.StockItemID,
	ol.PickedQuantity
FROM [Sales].[Orders] o
JOIN [Sales].[OrderLines] ol
	ON o.OrderID = ol.OrderID
WHERE [OrderDate] >= '2016-01-01 00:00:00.000' 
	AND OrderDate <= '2016-06-30 23:59:59.997'
ORDER BY [OrderDate]
OPTION (RECOMPILE);
GO

DBCC SHOW_STATISTICS ('Sales.Orders', _WA_Sys_00000007_44CA3770);
GO

/*
	Check out row and page count
*/
SELECT 
	OBJECT_NAME([p].[object_id]) [TableName], 
	[si].[name] [IndexName], 
	[au].[type_desc] [Type], 
	[p].[rows] [RowCount], 
	[au].total_pages [PageCount]
FROM [sys].[partitions] [p]
JOIN [sys].[allocation_units] [au] ON [p].[partition_id] = [au].[container_id]
JOIN [sys].[indexes] [si] 
	ON [p].[object_id] = [si].object_id 
	AND [p].[index_id] = [si].[index_id]
WHERE [p].[object_id] = OBJECT_ID(N'Sales.Orders');
GO

SELECT *
FROM sys.partitions
WHERE object_id = object_id('Sales.Orders') AND index_id = 1;

SELECT in_row_data_page_count, row_count
FROM sys.dm_db_partition_stats
WHERE object_id = object_id('Sales.Orders') AND index_id = 1;


/*
	Trick the optimize a bit here and change row count
	**Don't try this at home!!**
*/
UPDATE STATISTICS  [Sales].[Orders] PK_Sales_Orders
	WITH ROWCOUNT = 1000000, PAGECOUNT = 9383;
GO

/*
	re-run
*/

SELECT
	o.[CustomerID],
	o.[OrderDate],
	o.ExpectedDeliveryDate,
	o.[ContactPersonID],
	ol.StockItemID,
	ol.PickedQuantity
FROM [Sales].[Orders] o
JOIN [Sales].[OrderLines] ol
	ON o.OrderID = ol.OrderID
WHERE [OrderDate] >= '2016-01-01 00:00:00.000' 
	AND OrderDate <= '2016-01-30 23:59:59.997'
ORDER BY [OrderDate]
OPTION (RECOMPILE);
GO

GO
SELECT
	o.[CustomerID],
	o.[OrderDate],
	o.ExpectedDeliveryDate,
	o.[ContactPersonID],
	ol.StockItemID,
	ol.PickedQuantity
FROM [Sales].[Orders] o
JOIN [Sales].[OrderLines] ol
	ON o.OrderID = ol.OrderID
WHERE [OrderDate] >= '2016-01-01 00:00:00.000' 
	AND OrderDate <= '2016-06-30 23:59:59.997'
ORDER BY [OrderDate]
OPTION (RECOMPILE);
GO

/*
	clean up stats
*/
DBCC UPDATEUSAGE
    (WideWorldImportersB, 'Sales.Orders', PK_Sales_Orders)


/*
	Disable memory grant feedback
*/
ALTER DATABASE SCOPED CONFIGURATION 
	SET ROW_MODE_MEMORY_GRANT_FEEDBACK = OFF;
GO

DROP PROCEDURE IF EXISTS [Sales].[usp_OrderInfo_OrderDate];
GO

CREATE PROCEDURE [Sales].[usp_OrderInfo_OrderDate]
	@StartDate DATETIME,
	@EndDate DATETIME
AS
SELECT
	o.[CustomerID],
	o.[OrderDate],
	o.ExpectedDeliveryDate,
	o.[ContactPersonID],
	ol.StockItemID,
	ol.PickedQuantity
FROM [Sales].[Orders] o
JOIN [Sales].[OrderLines] ol
	ON [o].[OrderID] = [ol].[OrderID]
WHERE [OrderDate] >= @StartDate 
	AND [OrderDate] <= @EndDate
ORDER BY [OrderDate];
GO

/*
	Run each of these a few times and check memory grant
*/
DECLARE @StartDate DATETIME = '2016-01-01'
DECLARE @EndDate DATETIME = '2016-01-08'

EXEC [Sales].[usp_OrderInfo_OrderDate] @StartDate, @EndDate;
GO

DECLARE @StartDate DATETIME = '2016-01-01'
DECLARE @EndDate DATETIME = '2016-06-30'

EXEC [Sales].[usp_OrderInfo_OrderDate] @StartDate, @EndDate;
GO

DECLARE @StartDate DATETIME = '2016-01-01'
DECLARE @EndDate DATETIME = '2016-12-31'

EXEC [Sales].[usp_OrderInfo_OrderDate] @StartDate, @EndDate;
GO



/*
	Enable memory grant feedback
*/
ALTER DATABASE SCOPED CONFIGURATION SET ROW_MODE_MEMORY_GRANT_FEEDBACK = ON;
GO


/*
	Run again
*/
DECLARE @StartDate DATETIME = '2016-01-01'
DECLARE @EndDate DATETIME = '2016-01-08'

EXEC [Sales].[usp_OrderInfo_OrderDate] @StartDate, @EndDate;
GO

DECLARE @StartDate DATETIME = '2016-01-01'
DECLARE @EndDate DATETIME = '2016-06-30'

EXEC [Sales].[usp_OrderInfo_OrderDate] @StartDate, @EndDate;
GO

DECLARE @StartDate DATETIME = '2016-01-01'
DECLARE @EndDate DATETIME = '2016-12-31'

EXEC [Sales].[usp_OrderInfo_OrderDate] @StartDate, @EndDate;
GO


/*
	end...run next prep script
*/




/*
	Bonus query - viewing columns in a statistic
*/
SELECT  
	[sch].[name] + '.' + [so].[name] AS [TableName] ,
	[ss].[name] AS [Statistic] ,
	STUFF(( SELECT  ', ' + [c].[name]
        FROM [sys].[stats_columns] [sc]
		JOIN [sys].[columns] [c] 
			ON [c].[column_id] = [sc].[column_id]
            AND [c].[object_id] = [sc].[OBJECT_ID]
        WHERE [sc].[object_id] = [ss].[object_id]
			AND [sc].[stats_id] = [ss].[stats_id]
        ORDER BY [sc].[stats_column_id]
        FOR XML PATH('')), 1, 2, '') AS [ColumnsInStatistic] ,
	[ss].[auto_Created] AS [WasAutoCreated] ,
	[ss].[user_created] AS [WasUserCreated] ,
	[ss].[has_filter] AS [IsFiltered] ,
	[ss].[filter_definition] AS [FilterDefinition] ,
	[ss].[is_temporary] AS [IsTemporary] ,
	[sp].[last_updated] AS [StatsLastUpdated] ,
	[sp].[rows] AS [RowsInTable] ,
	[sp].[rows_sampled] AS [RowsSampled] ,
	[sp].[unfiltered_rows] AS [UnfilteredRows] ,
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
