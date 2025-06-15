-- Stored Procedure 1: InsertOrderDetails
IF OBJECT_ID('InsertOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE InsertOrderDetails;
GO

CREATE PROCEDURE InsertOrderDetails
    @SalesOrderID INT,
    @ProductID INT,
    @UnitPrice MONEY,
    @OrderQty SMALLINT,
    @UnitPriceDiscount FLOAT = 0,
    @SpecialOfferID INT = 1 -- Required by AdventureWorks2022!
AS
BEGIN
    INSERT INTO Sales.SalesOrderDetail 
    (SalesOrderID, ProductID, UnitPrice, OrderQty, UnitPriceDiscount, SpecialOfferID)
    VALUES 
    (@SalesOrderID, @ProductID, @UnitPrice, @OrderQty, @UnitPriceDiscount, @SpecialOfferID);
END;
GO

-- Stored Procedure 2: UpdateOrderDetails
IF OBJECT_ID('UpdateOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE UpdateOrderDetails;
GO

CREATE PROCEDURE UpdateOrderDetails
    @SalesOrderID INT,
    @ProductID INT,
    @UnitPrice MONEY,
    @OrderQty SMALLINT,
    @UnitPriceDiscount FLOAT
AS
BEGIN
    UPDATE Sales.SalesOrderDetail
    SET UnitPrice = ISNULL(@UnitPrice, UnitPrice),
        OrderQty = ISNULL(@OrderQty, OrderQty),
        UnitPriceDiscount = ISNULL(@UnitPriceDiscount, UnitPriceDiscount)
    WHERE SalesOrderID = @SalesOrderID AND ProductID = @ProductID;
END;
GO

-- Stored Procedure 3: OrderDetailsCheck
IF OBJECT_ID('OrderDetailsCheck', 'P') IS NOT NULL
    DROP PROCEDURE OrderDetailsCheck;
GO

CREATE PROCEDURE OrderDetailsCheck
    @SalesOrderID INT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM Sales.SalesOrderDetail WHERE SalesOrderID = @SalesOrderID)
    BEGIN
        PRINT 'The OrderID ' + CAST(@SalesOrderID AS VARCHAR(10)) + ' exists in Order Details.';
    END
    ELSE
    BEGIN
        PRINT 'No Order Details found for OrderID ' + CAST(@SalesOrderID AS VARCHAR(10)) + '.';
    END
END;
GO

-- Stored Procedure 4: DeleteOrderDetails
IF OBJECT_ID('DeleteOrderDetails', 'P') IS NOT NULL
    DROP PROCEDURE DeleteOrderDetails;
GO

CREATE PROCEDURE DeleteOrderDetails
    @SalesOrderID INT,
    @ProductID INT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM Sales.SalesOrderDetail WHERE SalesOrderID = @SalesOrderID AND ProductID = @ProductID)
    BEGIN
        DELETE FROM Sales.SalesOrderDetail
        WHERE SalesOrderID = @SalesOrderID AND ProductID = @ProductID;

        PRINT 'Order detail deleted successfully.';
    END
    ELSE
    BEGIN
        PRINT 'Invalid OrderID or ProductID. No matching record found.';
    END
END;
GO

-- Function 1: Format Date as MM/DD/YYYY
IF OBJECT_ID('fn_FormatDateMDY', 'FN') IS NOT NULL
    DROP FUNCTION fn_FormatDateMDY;
GO

CREATE FUNCTION fn_FormatDateMDY (@InputDate DATETIME)
RETURNS VARCHAR(10)
AS
BEGIN
    RETURN FORMAT(@InputDate, 'MM/dd/yyyy');
END;
GO

-- Function 2: Format Date as YYYYMMDD
IF OBJECT_ID('fn_FormatDateYMD', 'FN') IS NOT NULL
    DROP FUNCTION fn_FormatDateYMD;
GO

CREATE FUNCTION fn_FormatDateYMD (@InputDate DATETIME)
RETURNS VARCHAR(8)
AS
BEGIN
    RETURN FORMAT(@InputDate, 'yyyyMMdd');
END;
GO

-- View 1: vwCustomerOrders (NO CompanyName)
IF OBJECT_ID('vwCustomerOrders', 'V') IS NOT NULL
    DROP VIEW vwCustomerOrders;
GO

CREATE VIEW vwCustomerOrders AS
SELECT 
    OH.SalesOrderID,
    OH.OrderDate,
    OD.ProductID,
    P.Name AS ProductName,
    OD.OrderQty,
    OD.UnitPrice,
    OD.UnitPriceDiscount
FROM Sales.SalesOrderHeader OH
JOIN Sales.SalesOrderDetail OD ON OH.SalesOrderID = OD.SalesOrderID
JOIN Production.Product P ON OD.ProductID = P.ProductID;
GO


-- View 2: vwYesterdayOrders
IF OBJECT_ID('vwYesterdayOrders', 'V') IS NOT NULL
    DROP VIEW vwYesterdayOrders;
GO

CREATE VIEW vwYesterdayOrders AS
SELECT 
    OH.SalesOrderID,
    OH.OrderDate,
    OD.ProductID,
    P.Name AS ProductName,
    OD.OrderQty,
    OD.UnitPrice,
    OD.UnitPriceDiscount
FROM Sales.SalesOrderHeader OH
JOIN Sales.SalesOrderDetail OD ON OH.SalesOrderID = OD.SalesOrderID
JOIN Production.Product P ON OD.ProductID = P.ProductID
WHERE OH.OrderDate = CAST(GETDATE()-1 AS DATE);
GO

-- View 3: vwProductInfo
IF OBJECT_ID('vwProductInfo', 'V') IS NOT NULL
    DROP VIEW vwProductInfo;
GO

CREATE VIEW vwProductInfo AS
SELECT 
    P.ProductID,
    P.Name AS ProductName,
    P.StandardCost,
    P.ListPrice,
    P.Weight,
    PC.Name AS CategoryName
FROM Production.Product P
JOIN Production.ProductSubcategory PSC ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
JOIN Production.ProductCategory PC ON PSC.ProductCategoryID = PC.ProductCategoryID
WHERE P.DiscontinuedDate IS NULL; -- only active products
GO

-- Trigger: trg_DeleteOrderDetails
IF OBJECT_ID('Sales.trg_DeleteOrderDetails', 'TR') IS NOT NULL
    DROP TRIGGER Sales.trg_DeleteOrderDetails;
GO

CREATE TRIGGER Sales.trg_DeleteOrderDetails
ON Sales.SalesOrderHeader
AFTER DELETE
AS
BEGIN
    DELETE FROM Sales.SalesOrderDetail
    WHERE SalesOrderID IN (SELECT SalesOrderID FROM DELETED);
END;
GO


-- Trigger: trg_CheckStockOnOrderInsert
IF OBJECT_ID('Sales.trg_CheckStockOnOrderInsert', 'TR') IS NOT NULL
    DROP TRIGGER Sales.trg_CheckStockOnOrderInsert;
GO

CREATE TRIGGER Sales.trg_CheckStockOnOrderInsert
ON Sales.SalesOrderDetail
AFTER INSERT
AS
BEGIN
    DECLARE @ProductID INT, @OrderQty INT, @SafetyStockLevel INT;

    SELECT TOP 1 @ProductID = i.ProductID, @OrderQty = i.OrderQty
    FROM INSERTED i;

    SELECT @SafetyStockLevel = p.SafetyStockLevel
    FROM Production.Product p
    WHERE p.ProductID = @ProductID;

    IF @OrderQty > @SafetyStockLevel
    BEGIN
        RAISERROR ('Not enough stock to fulfill the order.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

--testing    testing  testing  testing
-- some queries may return 0 rows as output if no matching data exists

-- Pick an existing SalesOrderID and ProductID to avoid FK constraint violations
DECLARE @SalesOrderID INT = (
    SELECT TOP 1 SalesOrderID FROM Sales.SalesOrderHeader ORDER BY NEWID()
);

DECLARE @ProductID INT = (
    SELECT TOP 1 ProductID FROM Production.Product WHERE ProductID IN (
        SELECT ProductID FROM Sales.SalesOrderDetail
    ) ORDER BY NEWID()
);

-- Insert new detail (this assumes SpecialOfferID = 1 exists, which usually does)
EXEC InsertOrderDetails 
    @SalesOrderID = @SalesOrderID,
    @ProductID = @ProductID,
    @UnitPrice = 100.00,
    @OrderQty = 2,
    @UnitPriceDiscount = 0.1,
    @SpecialOfferID = 1;

-- Update the order detail we just inserted
EXEC UpdateOrderDetails 
    @SalesOrderID = @SalesOrderID,
    @ProductID = @ProductID,
    @UnitPrice = 120.00,
    @OrderQty = 3,
    @UnitPriceDiscount = 0.05;

-- Check if order details exist
EXEC OrderDetailsCheck @SalesOrderID = @SalesOrderID;

-- Delete the inserted order detail
EXEC DeleteOrderDetails 
    @SalesOrderID = @SalesOrderID,
    @ProductID = @ProductID;

-- Test functions
SELECT dbo.fn_FormatDateMDY(GETDATE()) AS [Date_MDY];
SELECT dbo.fn_FormatDateYMD(GETDATE()) AS [Date_YMD];

-- View queries
SELECT TOP 5 * FROM vwCustomerOrders;
SELECT TOP 5 * FROM vwYesterdayOrders;
SELECT TOP 5 * FROM vwProductInfo;
