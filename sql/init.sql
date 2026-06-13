-- Wait for SQL Server to be ready
WAITFOR DELAY '00:00:05';
GO

-- Create database
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'TradingPlatform')
BEGIN
    CREATE DATABASE TradingPlatform;
END
GO

USE TradingPlatform;
GO

-- =====================================================
-- TABLE: trades
-- Models trade execution across asset classes
-- =====================================================
IF OBJECT_ID('dbo.trades', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.trades (
        trade_id INT IDENTITY(1,1) PRIMARY KEY,
        isin VARCHAR(12) NOT NULL,
        counterparty VARCHAR(100) NOT NULL,
        notional_amount DECIMAL(18,2) NOT NULL,
        currency VARCHAR(3) NOT NULL,
        trade_date DATE NOT NULL,
        settlement_date DATE NOT NULL,
        buy_sell_indicator VARCHAR(4) NOT NULL CHECK (buy_sell_indicator IN ('BUY', 'SELL')),
        asset_class VARCHAR(2) NOT NULL CHECK (asset_class IN ('EQ', 'FI', 'FX')),
        status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'CONFIRMED', 'SETTLED', 'CANCELLED')),
        created_at DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        updated_at DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    );

    CREATE INDEX IX_trades_isin ON dbo.trades(isin);
    CREATE INDEX IX_trades_trade_date ON dbo.trades(trade_date);
    CREATE INDEX IX_trades_status ON dbo.trades(status);
END
GO

-- =====================================================
-- TABLE: positions
-- Models portfolio holdings with risk metrics
-- =====================================================
IF OBJECT_ID('dbo.positions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.positions (
        position_id INT IDENTITY(1,1) PRIMARY KEY,
        isin VARCHAR(12) NOT NULL,
        quantity DECIMAL(18,4) NOT NULL,
        market_value DECIMAL(18,2) NOT NULL,
        currency VARCHAR(3) NOT NULL,
        oad DECIMAL(10,4) NULL,  -- Option-Adjusted Duration (for FI)
        oas DECIMAL(10,4) NULL,  -- Option-Adjusted Spread (for FI, in basis points)
        dts DECIMAL(10,4) NULL,  -- Duration Times Spread (risk metric for FI)
        asset_class VARCHAR(2) NOT NULL CHECK (asset_class IN ('EQ', 'FI', 'FX')),
        as_of_date DATE NOT NULL,
        updated_at DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    );

    CREATE INDEX IX_positions_isin ON dbo.positions(isin);
    CREATE INDEX IX_positions_as_of_date ON dbo.positions(as_of_date);
END
GO

-- =====================================================
-- TABLE: cash_movements
-- Models cash flows (settlements, dividends, coupons)
-- =====================================================
IF OBJECT_ID('dbo.cash_movements', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.cash_movements (
        movement_id INT IDENTITY(1,1) PRIMARY KEY,
        currency VARCHAR(3) NOT NULL,
        amount DECIMAL(18,2) NOT NULL,
        value_date DATE NOT NULL,
        direction VARCHAR(3) NOT NULL CHECK (direction IN ('IN', 'OUT')),
        status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'SETTLED', 'FAILED')),
        counterparty VARCHAR(100) NOT NULL,
        created_at DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        updated_at DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    );

    CREATE INDEX IX_cash_movements_value_date ON dbo.cash_movements(value_date);
    CREATE INDEX IX_cash_movements_status ON dbo.cash_movements(status);
END
GO

-- =====================================================
-- SEED DATA: trades
-- =====================================================
SET IDENTITY_INSERT dbo.trades ON;

INSERT INTO dbo.trades (trade_id, isin, counterparty, notional_amount, currency, trade_date, settlement_date, buy_sell_indicator, asset_class, status, created_at, updated_at)
VALUES
-- Equities
(1, 'GB0002374006', 'Barclays Capital', 250000.00, 'GBP', '2024-01-15', '2024-01-17', 'BUY', 'EQ', 'SETTLED', '2024-01-15 09:30:00', '2024-01-17 16:00:00'),
(2, 'US0378331005', 'Goldman Sachs', 500000.00, 'USD', '2024-01-16', '2024-01-18', 'BUY', 'EQ', 'SETTLED', '2024-01-16 10:15:00', '2024-01-18 16:00:00'),
(3, 'GB00B24CGK77', 'Morgan Stanley', 180000.00, 'GBP', '2024-01-18', '2024-01-20', 'SELL', 'EQ', 'SETTLED', '2024-01-18 11:20:00', '2024-01-20 16:00:00'),
(4, 'DE0005140008', 'Deutsche Bank', 320000.00, 'EUR', '2024-01-19', '2024-01-21', 'BUY', 'EQ', 'CONFIRMED', '2024-01-19 14:30:00', '2024-01-21 09:00:00'),
(5, 'FR0000120271', 'BNP Paribas', 275000.00, 'EUR', '2024-01-22', '2024-01-24', 'BUY', 'EQ', 'PENDING', '2024-01-22 10:00:00', '2024-01-22 10:00:00'),
(6, 'US5949181045', 'JP Morgan', 425000.00, 'USD', '2024-01-23', '2024-01-25', 'SELL', 'EQ', 'PENDING', '2024-01-23 13:45:00', '2024-01-23 13:45:00'),
(7, 'GB0031348658', 'Citigroup', 195000.00, 'GBP', '2024-01-24', '2024-01-26', 'BUY', 'EQ', 'CONFIRMED', '2024-01-24 09:15:00', '2024-01-25 10:30:00'),
(8, 'NL0000009165', 'UBS', 310000.00, 'EUR', '2024-01-25', '2024-01-27', 'BUY', 'EQ', 'SETTLED', '2024-01-25 11:00:00', '2024-01-27 16:00:00'),
(9, 'US88160R1014', 'Credit Suisse', 385000.00, 'USD', '2024-01-26', '2024-01-28', 'SELL', 'EQ', 'CONFIRMED', '2024-01-26 14:20:00', '2024-01-27 09:45:00'),
(10, 'CH0012005267', 'HSBC', 220000.00, 'GBP', '2024-01-29', '2024-01-31', 'BUY', 'EQ', 'PENDING', '2024-01-29 10:30:00', '2024-01-29 10:30:00'),

-- Fixed Income
(11, 'US912828ZG75', 'Barclays Capital', 1000000.00, 'USD', '2024-01-15', '2024-01-17', 'BUY', 'FI', 'SETTLED', '2024-01-15 10:00:00', '2024-01-17 16:00:00'),
(12, 'GB00B24FF097', 'Goldman Sachs', 750000.00, 'GBP', '2024-01-16', '2024-01-18', 'BUY', 'FI', 'SETTLED', '2024-01-16 11:30:00', '2024-01-18 16:00:00'),
(13, 'DE0001102440', 'Deutsche Bank', 850000.00, 'EUR', '2024-01-17', '2024-01-19', 'SELL', 'FI', 'SETTLED', '2024-01-17 13:00:00', '2024-01-19 16:00:00'),
(14, 'US912828ZK86', 'JP Morgan', 1200000.00, 'USD', '2024-01-18', '2024-01-20', 'BUY', 'FI', 'CONFIRMED', '2024-01-18 09:45:00', '2024-01-19 14:00:00'),
(15, 'FR0013230893', 'BNP Paribas', 920000.00, 'EUR', '2024-01-19', '2024-01-21', 'BUY', 'FI', 'PENDING', '2024-01-19 15:30:00', '2024-01-19 15:30:00'),
(16, 'GB00BJ0NCY47', 'Morgan Stanley', 680000.00, 'GBP', '2024-01-22', '2024-01-24', 'SELL', 'FI', 'CONFIRMED', '2024-01-22 10:15:00', '2024-01-23 09:30:00'),
(17, 'US912828ZR38', 'Citigroup', 1100000.00, 'USD', '2024-01-23', '2024-01-25', 'BUY', 'FI', 'PENDING', '2024-01-23 14:00:00', '2024-01-23 14:00:00'),
(18, 'DE0001102457', 'UBS', 795000.00, 'EUR', '2024-01-24', '2024-01-26', 'BUY', 'FI', 'SETTLED', '2024-01-24 11:45:00', '2024-01-26 16:00:00'),
(19, 'GB00BK5CVX03', 'HSBC', 625000.00, 'GBP', '2024-01-25', '2024-01-27', 'SELL', 'FI', 'CONFIRMED', '2024-01-25 13:30:00', '2024-01-26 10:00:00'),
(20, 'US912828ZY83', 'Credit Suisse', 1050000.00, 'USD', '2024-01-26', '2024-01-28', 'BUY', 'FI', 'PENDING', '2024-01-26 09:20:00', '2024-01-26 09:20:00'),

-- FX Trades
(21, 'FX_GBPUSD', 'Barclays Capital', 500000.00, 'GBP', '2024-01-15', '2024-01-17', 'BUY', 'FX', 'SETTLED', '2024-01-15 08:30:00', '2024-01-17 16:00:00'),
(22, 'FX_EURUSD', 'Goldman Sachs', 750000.00, 'EUR', '2024-01-16', '2024-01-18', 'SELL', 'FX', 'SETTLED', '2024-01-16 09:00:00', '2024-01-18 16:00:00'),
(23, 'FX_GBPEUR', 'Deutsche Bank', 420000.00, 'GBP', '2024-01-17', '2024-01-19', 'BUY', 'FX', 'SETTLED', '2024-01-17 10:30:00', '2024-01-19 16:00:00'),
(24, 'FX_EURUSD', 'JP Morgan', 680000.00, 'EUR', '2024-01-18', '2024-01-20', 'BUY', 'FX', 'CONFIRMED', '2024-01-18 11:15:00', '2024-01-19 09:00:00'),
(25, 'FX_GBPUSD', 'BNP Paribas', 550000.00, 'GBP', '2024-01-19', '2024-01-21', 'SELL', 'FX', 'PENDING', '2024-01-19 13:20:00', '2024-01-19 13:20:00'),
(26, 'FX_EURUSD', 'Morgan Stanley', 715000.00, 'EUR', '2024-01-22', '2024-01-24', 'BUY', 'FX', 'CONFIRMED', '2024-01-22 08:45:00', '2024-01-23 10:15:00'),
(27, 'FX_GBPEUR', 'Citigroup', 395000.00, 'GBP', '2024-01-23', '2024-01-25', 'SELL', 'FX', 'PENDING', '2024-01-23 14:30:00', '2024-01-23 14:30:00'),
(28, 'FX_GBPUSD', 'UBS', 625000.00, 'GBP', '2024-01-24', '2024-01-26', 'BUY', 'FX', 'SETTLED', '2024-01-24 09:30:00', '2024-01-26 16:00:00'),
(29, 'FX_EURUSD', 'HSBC', 780000.00, 'EUR', '2024-01-25', '2024-01-27', 'SELL', 'FX', 'CONFIRMED', '2024-01-25 10:45:00', '2024-01-26 11:00:00'),
(30, 'FX_GBPEUR', 'Credit Suisse', 445000.00, 'GBP', '2024-01-26', '2024-01-28', 'BUY', 'FX', 'PENDING', '2024-01-26 15:00:00', '2024-01-26 15:00:00');

SET IDENTITY_INSERT dbo.trades OFF;
GO

-- =====================================================
-- SEED DATA: positions
-- =====================================================
SET IDENTITY_INSERT dbo.positions ON;

INSERT INTO dbo.positions (position_id, isin, quantity, market_value, currency, oad, oas, dts, asset_class, as_of_date, updated_at)
VALUES
-- Equity Positions
(1, 'GB0002374006', 5000.0000, 248500.00, 'GBP', NULL, NULL, NULL, 'EQ', '2024-01-29', '2024-01-29 18:00:00'),
(2, 'US0378331005', 3000.0000, 512000.00, 'USD', NULL, NULL, NULL, 'EQ', '2024-01-29', '2024-01-29 18:00:00'),
(3, 'DE0005140008', 2500.0000, 318750.00, 'EUR', NULL, NULL, NULL, 'EQ', '2024-01-29', '2024-01-29 18:00:00'),
(4, 'FR0000120271', 4000.0000, 276800.00, 'EUR', NULL, NULL, NULL, 'EQ', '2024-01-29', '2024-01-29 18:00:00'),
(5, 'GB0031348658', 3500.0000, 196350.00, 'GBP', NULL, NULL, NULL, 'EQ', '2024-01-29', '2024-01-29 18:00:00'),
(6, 'NL0000009165', 2200.0000, 312400.00, 'EUR', NULL, NULL, NULL, 'EQ', '2024-01-29', '2024-01-29 18:00:00'),
(7, 'CH0012005267', 4500.0000, 221850.00, 'GBP', NULL, NULL, NULL, 'EQ', '2024-01-29', '2024-01-29 18:00:00'),
(8, 'US5949181045', 2800.0000, 423200.00, 'USD', NULL, NULL, NULL, 'EQ', '2024-01-29', '2024-01-29 18:00:00'),
(9, 'US88160R1014', 3200.0000, 387200.00, 'USD', NULL, NULL, NULL, 'EQ', '2024-01-29', '2024-01-29 18:00:00'),
(10, 'GB00B24CGK77', 2900.0000, 179100.00, 'GBP', NULL, NULL, NULL, 'EQ', '2024-01-29', '2024-01-29 18:00:00'),

-- Fixed Income Positions (with OAD, OAS, DTS)
(11, 'US912828ZG75', 10000.0000, 1002500.00, 'USD', 5.2500, 45.0000, 236.2500, 'FI', '2024-01-29', '2024-01-29 18:00:00'),
(12, 'GB00B24FF097', 7500.0000, 751250.00, 'GBP', 4.7800, 52.0000, 248.5600, 'FI', '2024-01-29', '2024-01-29 18:00:00'),
(13, 'US912828ZK86', 12000.0000, 1198800.00, 'USD', 6.1200, 38.0000, 232.5600, 'FI', '2024-01-29', '2024-01-29 18:00:00'),
(14, 'FR0013230893', 9000.0000, 918900.00, 'EUR', 5.4500, 48.0000, 261.6000, 'FI', '2024-01-29', '2024-01-29 18:00:00'),
(15, 'DE0001102457', 8000.0000, 796400.00, 'EUR', 4.9200, 55.0000, 270.6000, 'FI', '2024-01-29', '2024-01-29 18:00:00'),
(16, 'GB00BJ0NCY47', 6500.0000, 679800.00, 'GBP', 5.8900, 42.0000, 247.3800, 'FI', '2024-01-29', '2024-01-29 18:00:00'),
(17, 'US912828ZR38', 11000.0000, 1097900.00, 'USD', 7.2300, 35.0000, 253.0500, 'FI', '2024-01-29', '2024-01-29 18:00:00'),
(18, 'DE0001102440', 8500.0000, 848750.00, 'EUR', 6.4500, 40.0000, 258.0000, 'FI', '2024-01-29', '2024-01-29 18:00:00'),
(19, 'GB00BK5CVX03', 7000.0000, 624500.00, 'GBP', 5.1200, 58.0000, 296.9600, 'FI', '2024-01-29', '2024-01-29 18:00:00'),
(20, 'US912828ZY83', 10500.0000, 1048950.00, 'USD', 4.5600, 47.0000, 214.3200, 'FI', '2024-01-29', '2024-01-29 18:00:00'),

-- FX Positions
(21, 'FX_GBPUSD', 500000.0000, 500000.00, 'GBP', NULL, NULL, NULL, 'FX', '2024-01-29', '2024-01-29 18:00:00'),
(22, 'FX_EURUSD', 750000.0000, 750000.00, 'EUR', NULL, NULL, NULL, 'FX', '2024-01-29', '2024-01-29 18:00:00'),
(23, 'FX_GBPEUR', 420000.0000, 420000.00, 'GBP', NULL, NULL, NULL, 'FX', '2024-01-29', '2024-01-29 18:00:00'),
(24, 'FX_GBPUSD', 625000.0000, 625000.00, 'GBP', NULL, NULL, NULL, 'FX', '2024-01-29', '2024-01-29 18:00:00'),
(25, 'FX_EURUSD', 680000.0000, 680000.00, 'EUR', NULL, NULL, NULL, 'FX', '2024-01-29', '2024-01-29 18:00:00'),
(26, 'FX_GBPEUR', 395000.0000, 395000.00, 'GBP', NULL, NULL, NULL, 'FX', '2024-01-29', '2024-01-29 18:00:00'),
(27, 'FX_EURUSD', 715000.0000, 715000.00, 'EUR', NULL, NULL, NULL, 'FX', '2024-01-29', '2024-01-29 18:00:00'),
(28, 'FX_GBPUSD', 550000.0000, 550000.00, 'GBP', NULL, NULL, NULL, 'FX', '2024-01-29', '2024-01-29 18:00:00'),
(29, 'FX_EURUSD', 780000.0000, 780000.00, 'EUR', NULL, NULL, NULL, 'FX', '2024-01-29', '2024-01-29 18:00:00'),
(30, 'FX_GBPEUR', 445000.0000, 445000.00, 'GBP', NULL, NULL, NULL, 'FX', '2024-01-29', '2024-01-29 18:00:00');

SET IDENTITY_INSERT dbo.positions OFF;
GO

-- =====================================================
-- SEED DATA: cash_movements
-- =====================================================
SET IDENTITY_INSERT dbo.cash_movements ON;

INSERT INTO dbo.cash_movements (movement_id, currency, amount, value_date, direction, status, counterparty, created_at, updated_at)
VALUES
-- Trade settlements
(1, 'GBP', 250000.00, '2024-01-17', 'OUT', 'SETTLED', 'Barclays Capital', '2024-01-15 09:30:00', '2024-01-17 16:00:00'),
(2, 'USD', 500000.00, '2024-01-18', 'OUT', 'SETTLED', 'Goldman Sachs', '2024-01-16 10:15:00', '2024-01-18 16:00:00'),
(3, 'GBP', 180000.00, '2024-01-20', 'IN', 'SETTLED', 'Morgan Stanley', '2024-01-18 11:20:00', '2024-01-20 16:00:00'),
(4, 'EUR', 320000.00, '2024-01-21', 'OUT', 'SETTLED', 'Deutsche Bank', '2024-01-19 14:30:00', '2024-01-21 16:00:00'),
(5, 'USD', 425000.00, '2024-01-25', 'IN', 'PENDING', 'JP Morgan', '2024-01-23 13:45:00', '2024-01-23 13:45:00'),
(6, 'EUR', 310000.00, '2024-01-27', 'OUT', 'SETTLED', 'UBS', '2024-01-25 11:00:00', '2024-01-27 16:00:00'),
(7, 'USD', 1000000.00, '2024-01-17', 'OUT', 'SETTLED', 'Barclays Capital', '2024-01-15 10:00:00', '2024-01-17 16:00:00'),
(8, 'GBP', 750000.00, '2024-01-18', 'OUT', 'SETTLED', 'Goldman Sachs', '2024-01-16 11:30:00', '2024-01-18 16:00:00'),
(9, 'EUR', 850000.00, '2024-01-19', 'IN', 'SETTLED', 'Deutsche Bank', '2024-01-17 13:00:00', '2024-01-19 16:00:00'),
(10, 'USD', 1200000.00, '2024-01-20', 'OUT', 'SETTLED', 'JP Morgan', '2024-01-18 09:45:00', '2024-01-20 16:00:00'),

-- Dividends and coupons
(11, 'GBP', 12500.00, '2024-01-22', 'IN', 'SETTLED', 'Barclays Capital', '2024-01-20 10:00:00', '2024-01-22 09:00:00'),
(12, 'USD', 18750.00, '2024-01-23', 'IN', 'SETTLED', 'Goldman Sachs', '2024-01-21 11:00:00', '2024-01-23 09:00:00'),
(13, 'EUR', 22500.00, '2024-01-24', 'IN', 'SETTLED', 'Deutsche Bank', '2024-01-22 12:00:00', '2024-01-24 09:00:00'),
(14, 'GBP', 8900.00, '2024-01-25', 'IN', 'PENDING', 'Morgan Stanley', '2024-01-23 10:30:00', '2024-01-23 10:30:00'),
(15, 'USD', 15600.00, '2024-01-26', 'IN', 'PENDING', 'JP Morgan', '2024-01-24 11:45:00', '2024-01-24 11:45:00'),
(16, 'EUR', 19200.00, '2024-01-27', 'IN', 'SETTLED', 'BNP Paribas', '2024-01-25 09:30:00', '2024-01-27 09:00:00'),
(17, 'GBP', 11400.00, '2024-01-28', 'IN', 'PENDING', 'HSBC', '2024-01-26 10:15:00', '2024-01-26 10:15:00'),
(18, 'USD', 21300.00, '2024-01-29', 'IN', 'SETTLED', 'Citigroup', '2024-01-27 11:00:00', '2024-01-29 09:00:00'),

-- Fee payments
(19, 'GBP', 2500.00, '2024-01-20', 'OUT', 'SETTLED', 'Barclays Capital', '2024-01-18 14:00:00', '2024-01-20 16:00:00'),
(20, 'USD', 3750.00, '2024-01-21', 'OUT', 'SETTLED', 'Goldman Sachs', '2024-01-19 15:00:00', '2024-01-21 16:00:00'),
(21, 'EUR', 4200.00, '2024-01-22', 'OUT', 'SETTLED', 'Deutsche Bank', '2024-01-20 13:30:00', '2024-01-22 16:00:00'),
(22, 'GBP', 1800.00, '2024-01-23', 'OUT', 'PENDING', 'Morgan Stanley', '2024-01-21 14:15:00', '2024-01-21 14:15:00'),
(23, 'USD', 2900.00, '2024-01-24', 'OUT', 'PENDING', 'JP Morgan', '2024-01-22 15:30:00', '2024-01-22 15:30:00'),
(24, 'EUR', 3350.00, '2024-01-25', 'OUT', 'FAILED', 'BNP Paribas', '2024-01-23 13:00:00', '2024-01-25 10:00:00'),
(25, 'GBP', 2100.00, '2024-01-26', 'OUT', 'SETTLED', 'HSBC', '2024-01-24 14:45:00', '2024-01-26 16:00:00'),

-- Margin calls and collateral
(26, 'USD', 75000.00, '2024-01-22', 'OUT', 'SETTLED', 'Goldman Sachs', '2024-01-20 08:00:00', '2024-01-22 09:00:00'),
(27, 'EUR', 65000.00, '2024-01-23', 'IN', 'SETTLED', 'Deutsche Bank', '2024-01-21 09:00:00', '2024-01-23 09:00:00'),
(28, 'GBP', 50000.00, '2024-01-24', 'OUT', 'PENDING', 'Barclays Capital', '2024-01-22 10:00:00', '2024-01-22 10:00:00'),
(29, 'USD', 82000.00, '2024-01-25', 'IN', 'SETTLED', 'JP Morgan', '2024-01-23 11:30:00', '2024-01-25 09:00:00'),
(30, 'EUR', 71000.00, '2024-01-26', 'OUT', 'PENDING', 'UBS', '2024-01-24 12:45:00', '2024-01-24 12:45:00');

SET IDENTITY_INSERT dbo.cash_movements OFF;
GO

PRINT 'Database TradingPlatform initialised successfully with seed data.';
GO
