-- =====================================================
-- Simulate Daily Trading Activity
-- =====================================================
-- Run this script to generate realistic changes that CDC will capture
-- This simulates end-of-day processing for a sovereign wealth fund
-- =====================================================

USE TradingPlatform;
GO

DECLARE @Today DATE = CAST(GETUTCDATE() AS DATE);
DECLARE @SettlementDate DATE = DATEADD(DAY, 2, @Today);  -- T+2 settlement

PRINT '========================================';
PRINT 'Simulating daily activity for ' + CAST(@Today AS VARCHAR(20));
PRINT '========================================';
PRINT '';

-- =====================================================
-- 1. INSERT new trades (5-10 trades across asset classes)
-- =====================================================
PRINT '1. Inserting new trades...';

INSERT INTO dbo.trades (isin, counterparty, notional_amount, currency, trade_date, settlement_date, buy_sell_indicator, asset_class, status, created_at, updated_at)
VALUES
    -- Equities
    ('US0378331005', 'Goldman Sachs', 485000.00, 'USD', @Today, @SettlementDate, 'BUY', 'EQ', 'PENDING', GETUTCDATE(), GETUTCDATE()),
    ('GB00B24CGK77', 'JP Morgan', 215000.00, 'GBP', @Today, @SettlementDate, 'SELL', 'EQ', 'PENDING', GETUTCDATE(), GETUTCDATE()),
    ('DE0005140008', 'Barclays Capital', 350000.00, 'EUR', @Today, @SettlementDate, 'BUY', 'EQ', 'PENDING', GETUTCDATE(), GETUTCDATE()),

    -- Fixed Income
    ('US912828ZG75', 'Morgan Stanley', 1150000.00, 'USD', @Today, @SettlementDate, 'BUY', 'FI', 'PENDING', GETUTCDATE(), GETUTCDATE()),
    ('GB00B24FF097', 'HSBC', 825000.00, 'GBP', @Today, @SettlementDate, 'SELL', 'FI', 'PENDING', GETUTCDATE(), GETUTCDATE()),
    ('DE0001102440', 'UBS', 920000.00, 'EUR', @Today, @SettlementDate, 'BUY', 'FI', 'CONFIRMED', GETUTCDATE(), GETUTCDATE()),

    -- FX
    ('FX_GBPUSD', 'Citigroup', 575000.00, 'GBP', @Today, @SettlementDate, 'BUY', 'FX', 'CONFIRMED', GETUTCDATE(), GETUTCDATE()),
    ('FX_EURUSD', 'Deutsche Bank', 685000.00, 'EUR', @Today, @SettlementDate, 'SELL', 'FX', 'PENDING', GETUTCDATE(), GETUTCDATE());

PRINT '  ✓ Inserted ' + CAST(@@ROWCOUNT AS VARCHAR(5)) + ' new trades';
PRINT '';

-- =====================================================
-- 2. UPDATE trade statuses (simulating confirmations)
-- =====================================================
PRINT '2. Updating trade statuses...';

-- Move some PENDING trades to CONFIRMED
UPDATE dbo.trades
SET status = 'CONFIRMED',
    updated_at = GETUTCDATE()
WHERE status = 'PENDING'
    AND trade_id IN (
        SELECT TOP 3 trade_id
        FROM dbo.trades
        WHERE status = 'PENDING'
        ORDER BY NEWID()  -- Random selection
    );

DECLARE @ConfirmedCount INT = @@ROWCOUNT;

-- Move some CONFIRMED trades to SETTLED (older trades)
UPDATE dbo.trades
SET status = 'SETTLED',
    updated_at = GETUTCDATE()
WHERE status = 'CONFIRMED'
    AND trade_date < @Today
    AND trade_id IN (
        SELECT TOP 2 trade_id
        FROM dbo.trades
        WHERE status = 'CONFIRMED'
            AND trade_date < @Today
        ORDER BY trade_date
    );

DECLARE @SettledCount INT = @@ROWCOUNT;

PRINT '  ✓ Confirmed ' + CAST(@ConfirmedCount AS VARCHAR(5)) + ' trades';
PRINT '  ✓ Settled ' + CAST(@SettledCount AS VARCHAR(5)) + ' trades';
PRINT '';

-- =====================================================
-- 3. UPDATE positions (end-of-day repricing)
-- =====================================================
PRINT '3. Updating position valuations (EOD repricing)...';

-- Update equity positions (market value changes, no OAD/OAS/DTS)
UPDATE dbo.positions
SET market_value = market_value * (1 + (RAND(CHECKSUM(NEWID())) * 0.04 - 0.02)),  -- ±2% change
    as_of_date = @Today,
    updated_at = GETUTCDATE()
WHERE asset_class = 'EQ'
    AND position_id IN (
        SELECT TOP 3 position_id
        FROM dbo.positions
        WHERE asset_class = 'EQ'
        ORDER BY NEWID()
    );

DECLARE @EqCount INT = @@ROWCOUNT;

-- Update fixed income positions (market value + risk metrics change)
-- Note: We can't use RAND() directly in UPDATE with multiple rows,
-- so we update one at a time for FI positions to get realistic risk metric changes
UPDATE p
SET market_value = market_value * (1 + (RAND(CHECKSUM(NEWID())) * 0.03 - 0.015)),  -- ±1.5% change
    oad = oad * (1 + (RAND(CHECKSUM(NEWID())) * 0.1 - 0.05)),  -- ±5% change in duration
    oas = oas * (1 + (RAND(CHECKSUM(NEWID())) * 0.15 - 0.075)),  -- ±7.5% change in spread
    dts = oad * oas,  -- Recalculate DTS = Duration × Spread
    as_of_date = @Today,
    updated_at = GETUTCDATE()
FROM dbo.positions p
WHERE asset_class = 'FI'
    AND position_id IN (
        SELECT TOP 5 position_id
        FROM dbo.positions
        WHERE asset_class = 'FI'
        ORDER BY NEWID()
    );

DECLARE @FiCount INT = @@ROWCOUNT;

PRINT '  ✓ Repriced ' + CAST(@EqCount AS VARCHAR(5)) + ' equity positions';
PRINT '  ✓ Repriced ' + CAST(@FiCount AS VARCHAR(5)) + ' fixed income positions';
PRINT '';

-- =====================================================
-- 4. INSERT new cash movements
-- =====================================================
PRINT '4. Inserting new cash movements...';

INSERT INTO dbo.cash_movements (currency, amount, value_date, direction, status, counterparty, created_at, updated_at)
VALUES
    -- Dividends received
    ('GBP', 15200.00, DATEADD(DAY, 1, @Today), 'IN', 'PENDING', 'Morgan Stanley', GETUTCDATE(), GETUTCDATE()),
    ('USD', 22400.00, DATEADD(DAY, 1, @Today), 'IN', 'PENDING', 'Goldman Sachs', GETUTCDATE(), GETUTCDATE()),

    -- Trade settlements
    ('USD', 485000.00, @SettlementDate, 'OUT', 'PENDING', 'Goldman Sachs', GETUTCDATE(), GETUTCDATE()),
    ('GBP', 215000.00, @SettlementDate, 'IN', 'PENDING', 'JP Morgan', GETUTCDATE(), GETUTCDATE()),

    -- Management fee payment
    ('GBP', 3800.00, @Today, 'OUT', 'PENDING', 'State Street', GETUTCDATE(), GETUTCDATE());

PRINT '  ✓ Inserted ' + CAST(@@ROWCOUNT AS VARCHAR(5)) + ' new cash movements';
PRINT '';

-- =====================================================
-- 5. UPDATE cash movement statuses
-- =====================================================
PRINT '5. Updating cash movement statuses...';

-- Settle pending movements with today's value date
UPDATE dbo.cash_movements
SET status = 'SETTLED',
    updated_at = GETUTCDATE()
WHERE status = 'PENDING'
    AND value_date <= @Today
    AND movement_id IN (
        SELECT TOP 3 movement_id
        FROM dbo.cash_movements
        WHERE status = 'PENDING'
            AND value_date <= @Today
        ORDER BY value_date
    );

DECLARE @CashSettledCount INT = @@ROWCOUNT;

-- Occasionally mark a payment as FAILED (simulate operational issues)
-- Only do this 20% of the time
IF RAND() < 0.2
BEGIN
    UPDATE TOP (1) dbo.cash_movements
    SET status = 'FAILED',
        updated_at = GETUTCDATE()
    WHERE status = 'PENDING'
        AND direction = 'OUT'
        AND value_date = @Today;

    IF @@ROWCOUNT > 0
        PRINT '  ⚠ Marked 1 payment as FAILED (operational issue)';
END

PRINT '  ✓ Settled ' + CAST(@CashSettledCount AS VARCHAR(5)) + ' cash movements';
PRINT '';

-- =====================================================
-- Summary
-- =====================================================
PRINT '========================================';
PRINT 'Daily activity simulation complete!';
PRINT '========================================';
PRINT '';
PRINT 'Current counts:';

SELECT 'Trades' AS TableName, COUNT(*) AS TotalRows, SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) AS Pending
FROM dbo.trades
UNION ALL
SELECT 'Positions', COUNT(*), SUM(CASE WHEN as_of_date = @Today THEN 1 ELSE 0 END)
FROM dbo.positions
UNION ALL
SELECT 'Cash Movements', COUNT(*), SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END)
FROM dbo.cash_movements;

PRINT '';
PRINT 'These changes are now in the CDC change tables.';
PRINT 'Run your .NET CDC reader to capture them!';
GO
