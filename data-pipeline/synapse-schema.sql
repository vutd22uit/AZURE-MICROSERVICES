-- ================================================================
-- Azure Synapse Analytics - Data Warehouse Schema
-- ================================================================
-- E-Commerce Cloud-Native System
-- This script creates the data warehouse schema for analytics
--
-- Architecture: Star Schema
-- - Fact Tables: Orders, Daily Sales
-- - Dimension Tables: Date, Products, Users (future)
-- ================================================================

-- ================================================================
-- 1. CREATE SCHEMAS
-- ================================================================

-- Staging schema for raw data from Cosmos DB
CREATE SCHEMA staging;
GO

-- Data warehouse schema for transformed data
CREATE SCHEMA dw;
GO

-- ================================================================
-- 2. STAGING TABLES (Raw data from Cosmos DB)
-- ================================================================

-- Staging table for orders
DROP TABLE IF EXISTS staging.Orders;
CREATE TABLE staging.Orders
(
    id NVARCHAR(100) NOT NULL,
    userId NVARCHAR(100),
    items NVARCHAR(MAX),  -- JSON array
    totalAmount DECIMAL(18,2),
    status NVARCHAR(50),
    paymentMethod NVARCHAR(50),
    shippingAddress NVARCHAR(MAX),  -- JSON object
    transactionId NVARCHAR(100),
    createdAt DATETIME2,
    updatedAt DATETIME2,
    paidAt DATETIME2,
    LoadDate DATETIME2 DEFAULT GETDATE()
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    HEAP
);
GO

-- ================================================================
-- 3. DIMENSION TABLES
-- ================================================================

-- Dimension: Date (pre-populated for 3 years)
DROP TABLE IF EXISTS dw.DimDate;
CREATE TABLE dw.DimDate
(
    DateKey INT NOT NULL,
    Date DATE NOT NULL,
    Year INT NOT NULL,
    Quarter INT NOT NULL,
    Month INT NOT NULL,
    MonthName NVARCHAR(20) NOT NULL,
    Week INT NOT NULL,
    DayOfYear INT NOT NULL,
    DayOfMonth INT NOT NULL,
    DayOfWeek INT NOT NULL,
    DayName NVARCHAR(20) NOT NULL,
    IsWeekend BIT NOT NULL,
    IsHoliday BIT NOT NULL DEFAULT 0,
    FiscalYear INT NOT NULL,
    FiscalQuarter INT NOT NULL,
    CONSTRAINT PK_DimDate PRIMARY KEY NONCLUSTERED (DateKey) NOT ENFORCED
)
WITH
(
    DISTRIBUTION = REPLICATE,
    CLUSTERED COLUMNSTORE INDEX
);
GO

-- Dimension: Products
DROP TABLE IF EXISTS dw.DimProducts;
CREATE TABLE dw.DimProducts
(
    ProductKey INT IDENTITY(1,1) NOT NULL,
    ProductId NVARCHAR(100) NOT NULL,
    ProductName NVARCHAR(200),
    Category NVARCHAR(100),
    Price DECIMAL(18,2),
    Description NVARCHAR(MAX),
    ImageUrl NVARCHAR(500),
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2,
    UpdatedDate DATETIME2,
    CONSTRAINT PK_DimProducts PRIMARY KEY NONCLUSTERED (ProductKey) NOT ENFORCED
)
WITH
(
    DISTRIBUTION = REPLICATE,
    CLUSTERED COLUMNSTORE INDEX
);
GO

-- ================================================================
-- 4. FACT TABLES
-- ================================================================

-- Fact: Orders (detailed transactions)
DROP TABLE IF EXISTS dw.FactOrders;
CREATE TABLE dw.FactOrders
(
    OrderKey BIGINT IDENTITY(1,1) NOT NULL,
    OrderId NVARCHAR(100) NOT NULL,
    OrderDateKey INT NOT NULL,
    UserId NVARCHAR(100),
    TotalAmount DECIMAL(18,2),
    Status NVARCHAR(50),
    PaymentMethod NVARCHAR(50),
    TransactionId NVARCHAR(100),
    NumberOfItems INT,
    OrderDate DATETIME2,
    PaidDate DATETIME2,
    CreatedDate DATETIME2,
    UpdatedDate DATETIME2,
    LoadDate DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT PK_FactOrders PRIMARY KEY NONCLUSTERED (OrderKey) NOT ENFORCED
)
WITH
(
    DISTRIBUTION = HASH(OrderId),
    CLUSTERED COLUMNSTORE INDEX
);
GO

-- Fact: Daily Sales (aggregated metrics)
DROP TABLE IF EXISTS dw.FactDailySales;
CREATE TABLE dw.FactDailySales
(
    DateKey INT NOT NULL,
    TotalOrders INT NOT NULL,
    TotalRevenue DECIMAL(18,2) NOT NULL,
    AverageOrderValue DECIMAL(18,2) NOT NULL,
    UniqueCustomers INT NOT NULL,
    CompletedOrders INT NOT NULL,
    PendingOrders INT NOT NULL,
    CancelledOrders INT NOT NULL,
    TotalItems INT NOT NULL,
    LoadDate DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT PK_FactDailySales PRIMARY KEY NONCLUSTERED (DateKey) NOT ENFORCED
)
WITH
(
    DISTRIBUTION = REPLICATE,
    CLUSTERED COLUMNSTORE INDEX
);
GO

-- ================================================================
-- 5. POPULATE DATE DIMENSION
-- ================================================================

-- Populate DimDate for 3 years (2024-2026)
DECLARE @StartDate DATE = '2024-01-01';
DECLARE @EndDate DATE = '2026-12-31';

WITH DateRange AS
(
    SELECT @StartDate AS Date
    UNION ALL
    SELECT DATEADD(DAY, 1, Date)
    FROM DateRange
    WHERE DATEADD(DAY, 1, Date) <= @EndDate
)
INSERT INTO dw.DimDate (DateKey, Date, Year, Quarter, Month, MonthName, Week, DayOfYear, DayOfMonth, DayOfWeek, DayName, IsWeekend, FiscalYear, FiscalQuarter)
SELECT
    CAST(FORMAT(Date, 'yyyyMMdd') AS INT) AS DateKey,
    Date,
    YEAR(Date) AS Year,
    DATEPART(QUARTER, Date) AS Quarter,
    MONTH(Date) AS Month,
    DATENAME(MONTH, Date) AS MonthName,
    DATEPART(WEEK, Date) AS Week,
    DATEPART(DAYOFYEAR, Date) AS DayOfYear,
    DAY(Date) AS DayOfMonth,
    DATEPART(WEEKDAY, Date) AS DayOfWeek,
    DATENAME(WEEKDAY, Date) AS DayName,
    CASE WHEN DATEPART(WEEKDAY, Date) IN (1, 7) THEN 1 ELSE 0 END AS IsWeekend,
    CASE
        WHEN MONTH(Date) >= 7 THEN YEAR(Date)
        ELSE YEAR(Date) - 1
    END AS FiscalYear,
    CASE
        WHEN MONTH(Date) IN (7, 8, 9) THEN 1
        WHEN MONTH(Date) IN (10, 11, 12) THEN 2
        WHEN MONTH(Date) IN (1, 2, 3) THEN 3
        ELSE 4
    END AS FiscalQuarter
FROM DateRange
OPTION (MAXRECURSION 0);
GO

-- ================================================================
-- 6. STORED PROCEDURES FOR ETL
-- ================================================================

-- Procedure: Transform and load orders from staging to fact table
CREATE OR ALTER PROCEDURE dw.sp_LoadFactOrders
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Insert new orders
        INSERT INTO dw.FactOrders (
            OrderId,
            OrderDateKey,
            UserId,
            TotalAmount,
            Status,
            PaymentMethod,
            TransactionId,
            NumberOfItems,
            OrderDate,
            PaidDate,
            CreatedDate,
            UpdatedDate
        )
        SELECT
            s.id AS OrderId,
            CAST(FORMAT(CAST(s.createdAt AS DATE), 'yyyyMMdd') AS INT) AS OrderDateKey,
            s.userId,
            s.totalAmount,
            s.status,
            s.paymentMethod,
            s.transactionId,
            -- Calculate number of items from JSON
            (SELECT COUNT(*) FROM OPENJSON(s.items)) AS NumberOfItems,
            s.createdAt AS OrderDate,
            s.paidAt AS PaidDate,
            s.createdAt AS CreatedDate,
            s.updatedAt AS UpdatedDate
        FROM staging.Orders s
        WHERE NOT EXISTS (
            SELECT 1 FROM dw.FactOrders f WHERE f.OrderId = s.id
        );

        -- Update existing orders
        UPDATE f
        SET
            f.Status = s.status,
            f.TransactionId = s.transactionId,
            f.PaidDate = s.paidAt,
            f.UpdatedDate = s.updatedAt
        FROM dw.FactOrders f
        INNER JOIN staging.Orders s ON f.OrderId = s.id
        WHERE s.updatedAt > f.UpdatedDate;

        COMMIT TRANSACTION;

        PRINT 'FactOrders loaded successfully';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50000, @ErrorMessage, 1;
    END CATCH
END;
GO

-- Procedure: Aggregate daily sales
CREATE OR ALTER PROCEDURE dw.sp_AggregateDaily Sales
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Truncate and reload (for simplicity - in production use incremental)
        TRUNCATE TABLE dw.FactDailySales;

        -- Insert aggregated daily metrics
        INSERT INTO dw.FactDailySales (
            DateKey,
            TotalOrders,
            TotalRevenue,
            AverageOrderValue,
            UniqueCustomers,
            CompletedOrders,
            PendingOrders,
            CancelledOrders,
            TotalItems
        )
        SELECT
            f.OrderDateKey,
            COUNT(*) AS TotalOrders,
            SUM(f.TotalAmount) AS TotalRevenue,
            AVG(f.TotalAmount) AS AverageOrderValue,
            COUNT(DISTINCT f.UserId) AS UniqueCustomers,
            SUM(CASE WHEN f.Status = 'Completed' THEN 1 ELSE 0 END) AS CompletedOrders,
            SUM(CASE WHEN f.Status = 'Pending' THEN 1 ELSE 0 END) AS PendingOrders,
            SUM(CASE WHEN f.Status = 'Cancelled' THEN 1 ELSE 0 END) AS CancelledOrders,
            SUM(f.NumberOfItems) AS TotalItems
        FROM dw.FactOrders f
        GROUP BY f.OrderDateKey;

        COMMIT TRANSACTION;

        PRINT 'FactDailySales aggregated successfully';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50000, @ErrorMessage, 1;
    END CATCH
END;
GO

-- ================================================================
-- 7. VIEWS FOR POWER BI
-- ================================================================

-- View: Orders summary with date information
CREATE OR ALTER VIEW dw.vw_OrdersSummary
AS
SELECT
    f.OrderKey,
    f.OrderId,
    f.UserId,
    f.TotalAmount,
    f.Status,
    f.PaymentMethod,
    f.TransactionId,
    f.NumberOfItems,
    f.OrderDate,
    f.PaidDate,
    d.Date,
    d.Year,
    d.Quarter,
    d.Month,
    d.MonthName,
    d.DayName,
    d.IsWeekend
FROM dw.FactOrders f
LEFT JOIN dw.DimDate d ON f.OrderDateKey = d.DateKey;
GO

-- View: Daily sales trends
CREATE OR ALTER VIEW dw.vw_DailySalesTrend
AS
SELECT
    d.Date,
    d.Year,
    d.Month,
    d.MonthName,
    d.DayName,
    s.TotalOrders,
    s.TotalRevenue,
    s.AverageOrderValue,
    s.UniqueCustomers,
    s.CompletedOrders,
    s.PendingOrders,
    s.CancelledOrders,
    s.TotalItems
FROM dw.FactDailySales s
INNER JOIN dw.DimDate d ON s.DateKey = d.DateKey;
GO

-- View: Monthly revenue summary
CREATE OR ALTER VIEW dw.vw_MonthlyRevenue
AS
SELECT
    d.Year,
    d.Month,
    d.MonthName,
    SUM(s.TotalRevenue) AS MonthlyRevenue,
    SUM(s.TotalOrders) AS MonthlyOrders,
    AVG(s.AverageOrderValue) AS AvgOrderValue,
    SUM(s.UniqueCustomers) AS UniqueCustomers
FROM dw.FactDailySales s
INNER JOIN dw.DimDate d ON s.DateKey = d.DateKey
GROUP BY d.Year, d.Month, d.MonthName;
GO

-- ================================================================
-- 8. GRANT PERMISSIONS
-- ================================================================

-- Grant permissions to execute stored procedures
-- GRANT EXECUTE ON SCHEMA::dw TO [DataFactoryServicePrincipal];

-- ================================================================
-- VERIFICATION QUERIES
-- ================================================================

-- Check date dimension
-- SELECT COUNT(*) AS TotalDates, MIN(Date) AS StartDate, MAX(Date) AS EndDate FROM dw.DimDate;

-- Check fact tables
-- SELECT COUNT(*) AS TotalOrders FROM dw.FactOrders;
-- SELECT COUNT(*) AS TotalDays FROM dw.FactDailySales;

-- Sample data from views
-- SELECT TOP 10 * FROM dw.vw_OrdersSummary ORDER BY OrderDate DESC;
-- SELECT TOP 10 * FROM dw.vw_DailySalesTrend ORDER BY Date DESC;
-- SELECT * FROM dw.vw_MonthlyRevenue ORDER BY Year DESC, Month DESC;

PRINT 'Data warehouse schema created successfully!';
GO
