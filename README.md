# Event-Driven Data Ingestion Platform

**Week 1 Complete**: Foundation and CDC Proof of Concept

## Overview

This is a 12-week personal project building an event-driven data ingestion platform in C# (.NET 8), modelling a simplified buy-side trading environment at a sovereign wealth fund.

## Week 1 Achievements

✓ Docker Compose setup with Azure SQL Edge
✓ Three normalised tables with realistic trading data
✓ Change Data Capture (CDC) enabled on SQL Server
✓ .NET 8 console app reading CDC changes with LSN tracking
✓ Mutation script to simulate daily trading activity

## Architecture

```
┌─────────────────┐
│  SQL Server     │
│  (Azure SQL     │
│   Edge)         │
│                 │
│  ┌───────────┐  │
│  │   CDC     │  │
│  │  Change   │  │
│  │  Tables   │  │
│  └───────────┘  │
└────────┬────────┘
         │
         │ fn_cdc_get_net_changes
         │
         ▼
┌─────────────────┐
│  CdcReader      │
│  (.NET 8)       │
│                 │
│  ┌───────────┐  │
│  │ LSN Track │  │
│  │   File    │  │
│  └───────────┘  │
└─────────────────┘
```

## Project Structure

```
event-driven-project/
├── docker-compose.yml          # Azure SQL Edge container
├── sql/
│   ├── init.sql               # Database schema + seed data
│   ├── enable-cdc.sql         # CDC enable script
│   └── simulate_daily_changes.sql  # Mutation script
├── CdcReader/                 # .NET 8 console app
│   ├── Program.cs             # CDC reader implementation
│   └── last-processed-lsn.txt # LSN checkpoint (auto-generated)
├── *.csx                      # dotnet-script utilities
└── README.md
```

## Database Schema

### trades
Trade executions across asset classes (EQ, FI, FX)

**Key columns**: trade_id, isin, counterparty, notional_amount, currency, status, asset_class

### positions
Portfolio holdings with risk metrics (OAD, OAS, DTS for fixed income)

**Key columns**: position_id, isin, quantity, market_value, asset_class, oad, oas, dts

### cash_movements
Cash flows (settlements, dividends, coupons, fees, margin)

**Key columns**: movement_id, currency, amount, direction (IN/OUT), status, counterparty

## CDC Concepts (Quick Reference)

**LSN (Log Sequence Number)**
- Binary(10) value representing a point in the transaction log
- Monotonically increasing, unique per transaction
- Your "bookmark" for incremental reads

**Change Tables** (`cdc.schema_tablename_CT`)
- Mirror source table schema + metadata columns:
  - `__$start_lsn` — LSN when change was committed
  - `__$operation` — 1=DELETE, 2=INSERT, 4=UPDATE
  - `__$update_mask` — Which columns changed (varbinary)

**Query Functions**
- `fn_cdc_get_net_changes_<instance>` — Net effect within an LSN range (single row per key)
- `fn_cdc_get_all_changes_<instance>` — All changes including before/after images

**SQL Server Agent**
- **Capture job** — Scans transaction log every 5 seconds, populates change tables
- **Cleanup job** — Purges old change records (default: 3 days retention)

## Quick Start

### 1. Start SQL Server
```bash
docker compose up -d
```

### 2. Initialise Database
```bash
dotnet script init-db.csx
```

### 3. Enable CDC
```bash
dotnet script enable-cdc.csx
```

### 4. Run CDC Reader
```bash
cd CdcReader
dotnet run
```

### 5. Simulate Daily Activity
```bash
dotnet script simulate-changes.csx
dotnet run  # in CdcReader/ — will pick up incremental changes
```

## Azure SQL Edge Limitations

⚠️ **CDC Functions**: Only the first table enabled (trades) has working CDC functions. Positions and cash_movements hit an "insufficient arguments" error. This appears to be an Azure SQL Edge bug.

⚠️ **CLR Disabled**: `fn_cdc_increment_lsn` doesn't work (requires CLR). Workaround: Use last processed LSN directly as from_lsn.

**Week 2 TODO**: Migrate to full SQL Server (Windows container or cloud instance) for production-quality CDC.

## C# CDC Reader Highlights

**Production-quality patterns**:
- Async/await throughout
- Proper resource disposal (`await using`)
- Error handling with SqlException specifics
- LSN checkpoint persistence (hex string for readability)
- Table-specific change summaries

**LSN Tracking**:
- First run: Starts from `MIN(start_lsn)` in `cdc.change_tables`
- Subsequent runs: Resumes from `last-processed-lsn.txt`
- No duplicates, no missed changes

## Sample Output

```
===========================================
CDC Reader - TradingPlatform
===========================================

✓ Connected to TradingPlatform database

ℹ Resuming from last checkpoint: 0000002700000B680001
Processing LSN range:
  From: 0000002700000B680001
  To:   0000002700000D18000C

───────────────────────────────────────────
Processing: trades
───────────────────────────────────────────
  [INSERT] trade_id=39 | ISIN=US0378331005 | Counterparty=Goldman Sachs | Notional=485,000.00 USD | Status=PENDING | Asset=EQ
  [UPDATE] trade_id=35 | ISIN=GB00B24FF097 | Counterparty=HSBC | Notional=825,000.00 GBP | Status=CONFIRMED | Asset=FI

===========================================
✓ Processing complete: 12 total changes processed
✓ LSN checkpoint saved to last-processed-lsn.txt
===========================================
```

## Next Steps (Week 2)

- [ ] Migrate to full SQL Server for multi-table CDC
- [ ] Add structured logging (Serilog)
- [ ] Introduce domain events (record types)
- [ ] Basic event serialisation (JSON)
- [ ] File-based event log (precursor to message broker)

## Technical Stack

- **.NET 8** — Console app (LTS release)
- **C# 12** — Modern language features
- **Microsoft.Data.SqlClient** — SQL Server connectivity
- **Azure SQL Edge** — ARM64-compatible SQL Server (M-series Mac development)
- **Docker Compose** — Container orchestration
- **dotnet-script** — C# scripting for utilities

## Environment

- macOS (Apple Silicon)
- Docker Desktop
- .NET 8 SDK
- VS Code with C# Dev Kit + MSSQL extensions

---

**Week 1 Status**: ✅ Complete
**Next Review**: Week 2 — Structured Events + Logging
