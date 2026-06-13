-- =====================================================
-- Enable Change Data Capture (CDC)
-- =====================================================

USE TradingPlatform;
GO

-- Check if SQL Server Agent is running (required for CDC)
EXEC sp_helpdb 'TradingPlatform';
GO

-- Enable CDC at the database level
-- This creates the cdc schema and system tables
EXEC sys.sp_cdc_enable_db;
GO

-- Verify CDC is enabled at database level
SELECT name, is_cdc_enabled
FROM sys.databases
WHERE name = 'TradingPlatform';
GO

-- =====================================================
-- Enable CDC on individual tables
-- =====================================================

-- Enable CDC on trades table
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'trades',
    @role_name = NULL,  -- No role-based security (NULL means sysadmin only, fine for dev)
    @supports_net_changes = 1;  -- Enable net changes function (requires PK)
GO

-- Enable CDC on positions table
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'positions',
    @role_name = NULL,
    @supports_net_changes = 1;
GO

-- Enable CDC on cash_movements table
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'cash_movements',
    @role_name = NULL,
    @supports_net_changes = 1;
GO

-- =====================================================
-- Verify CDC configuration
-- =====================================================

-- Check which tables have CDC enabled
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    t.is_tracked_by_cdc,
    ct.capture_instance,
    ct.start_lsn,
    ct.create_date
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN cdc.change_tables ct ON t.object_id = ct.source_object_id
WHERE s.name = 'dbo'
ORDER BY t.name;
GO

-- Check CDC capture job status
-- Note: In Azure SQL Edge, the job may not appear in sysjobs
-- but the capture process runs automatically
SELECT
    name,
    enabled,
    date_created,
    date_modified
FROM msdb.dbo.sysjobs
WHERE name LIKE 'cdc%'
ORDER BY name;
GO

-- View the change table structures
SELECT
    SCHEMA_NAME(schema_id) + '.' + name AS change_table_name,
    create_date
FROM sys.tables
WHERE schema_id = SCHEMA_ID('cdc')
    AND name LIKE '%_CT'
ORDER BY name;
GO

-- Get the current maximum LSN (this is your starting point for CDC reads)
SELECT
    'trades' AS table_name,
    sys.fn_cdc_get_max_lsn() AS current_max_lsn;
GO

PRINT '';
PRINT 'CDC enabled successfully on TradingPlatform database!';
PRINT 'Change tables created:';
PRINT '  - cdc.dbo_trades_CT';
PRINT '  - cdc.dbo_positions_CT';
PRINT '  - cdc.dbo_cash_movements_CT';
PRINT '';
PRINT 'Available query functions:';
PRINT '  All changes:';
PRINT '    - cdc.fn_cdc_get_all_changes_dbo_trades';
PRINT '    - cdc.fn_cdc_get_all_changes_dbo_positions';
PRINT '    - cdc.fn_cdc_get_all_changes_dbo_cash_movements';
PRINT '  Net changes:';
PRINT '    - cdc.fn_cdc_get_net_changes_dbo_trades';
PRINT '    - cdc.fn_cdc_get_net_changes_dbo_positions';
PRINT '    - cdc.fn_cdc_get_net_changes_dbo_cash_movements';
PRINT '';
GO
