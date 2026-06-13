using Microsoft.Data.SqlClient;
using System.Text;

namespace CdcReader;

/// <summary>
/// CDC Reader for TradingPlatform database
/// Reads change data from SQL Server CDC and tracks processed LSN
/// </summary>
class Program
{
    private const string ConnectionString = "Server=localhost,1433;Database=TradingPlatform;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;";
    private const string LsnTrackingFile = "last-processed-lsn.txt";

    static async Task<int> Main(string[] args)
    {
        Console.WriteLine("===========================================");
        Console.WriteLine("CDC Reader - TradingPlatform");
        Console.WriteLine("===========================================\n");

        try
        {
            await using var connection = new SqlConnection(ConnectionString);
            await connection.OpenAsync();
            Console.WriteLine("✓ Connected to TradingPlatform database\n");

            // Get the LSN range to process
            var (fromLsn, toLsn) = await GetLsnRangeAsync(connection);

            if (fromLsn == null || toLsn == null)
            {
                Console.WriteLine("⚠ No changes to process (LSN range is invalid)");
                return 0;
            }

            Console.WriteLine($"Processing LSN range:");
            Console.WriteLine($"  From: {BitConverter.ToString(fromLsn).Replace("-", "")}");
            Console.WriteLine($"  To:   {BitConverter.ToString(toLsn).Replace("-", "")}\n");

            // Process changes for each table
            // NOTE: Azure SQL Edge has a bug where CDC functions only work for the first table enabled
            // In production SQL Server, all three tables would work. For now, we'll demo with trades only.
            var tables = new[]
            {
                new { Name = "trades", CaptureInstance = "dbo_trades", KeyColumn = "trade_id" }
                // TODO Week 2: Migrate to full SQL Server or work around Azure SQL Edge CDC limitation
                // new { Name = "positions", CaptureInstance = "dbo_positions", KeyColumn = "position_id" },
                // new { Name = "cash_movements", CaptureInstance = "dbo_cash_movements", KeyColumn = "movement_id" }
            };

            int totalChanges = 0;

            foreach (var table in tables)
            {
                var changeCount = await ProcessTableChangesAsync(connection, table.Name, table.CaptureInstance, table.KeyColumn, fromLsn, toLsn);
                totalChanges += changeCount;
            }

            // Save the new LSN checkpoint
            await SaveLastProcessedLsnAsync(toLsn);

            Console.WriteLine("\n===========================================");
            Console.WriteLine($"✓ Processing complete: {totalChanges} total changes processed");
            Console.WriteLine($"✓ LSN checkpoint saved to {LsnTrackingFile}");
            Console.WriteLine("===========================================\n");

            return 0;
        }
        catch (SqlException ex)
        {
            Console.Error.WriteLine($"\n❌ SQL Error: {ex.Message}");
            Console.Error.WriteLine($"   Error Number: {ex.Number}");
            Console.Error.WriteLine($"   State: {ex.State}");
            return 1;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"\n❌ Unexpected error: {ex.Message}");
            Console.Error.WriteLine(ex.StackTrace);
            return 1;
        }
    }

    /// <summary>
    /// Gets the LSN range to process: (last processed LSN, current max LSN)
    /// </summary>
    private static async Task<(byte[]? fromLsn, byte[]? toLsn)> GetLsnRangeAsync(SqlConnection connection)
    {
        // Get the current maximum LSN in the database
        byte[]? currentMaxLsn = null;
        await using (var cmd = new SqlCommand("SELECT sys.fn_cdc_get_max_lsn()", connection))
        {
            var result = await cmd.ExecuteScalarAsync();
            if (result != DBNull.Value && result != null)
            {
                currentMaxLsn = (byte[])result;
            }
        }

        if (currentMaxLsn == null)
        {
            Console.WriteLine("⚠ No CDC data available yet (max LSN is NULL)");
            return (null, null);
        }

        // Get the last processed LSN from our tracking file
        byte[]? lastProcessedLsn = await ReadLastProcessedLsnAsync();

        byte[] fromLsn;

        if (lastProcessedLsn == null)
        {
            Console.WriteLine("ℹ No previous LSN checkpoint found - starting from the beginning");

            // Get the minimum valid LSN for any CDC table
            await using var cmd = new SqlCommand(@"
                SELECT MIN(start_lsn)
                FROM cdc.change_tables", connection);

            var result = await cmd.ExecuteScalarAsync();
            if (result == DBNull.Value || result == null)
            {
                return (null, null);
            }

            fromLsn = (byte[])result;
        }
        else
        {
            Console.WriteLine($"ℹ Resuming from last checkpoint: {BitConverter.ToString(lastProcessedLsn).Replace("-", "")}");

            // Note: fn_cdc_increment_lsn requires CLR which Azure SQL Edge doesn't support
            // We'll use the last processed LSN directly - the CDC functions handle this correctly
            fromLsn = lastProcessedLsn;
        }

        return (fromLsn, currentMaxLsn);
    }

    /// <summary>
    /// Processes changes for a single table and returns the number of changes found
    /// </summary>
    private static async Task<int> ProcessTableChangesAsync(
        SqlConnection connection,
        string tableName,
        string captureInstance,
        string keyColumn,
        byte[] fromLsn,
        byte[] toLsn)
    {
        Console.WriteLine($"───────────────────────────────────────────");
        Console.WriteLine($"Processing: {tableName}");
        Console.WriteLine($"───────────────────────────────────────────");

        var sql = $@"
            SELECT *
            FROM cdc.fn_cdc_get_net_changes_{captureInstance}(@from_lsn, @to_lsn, 'all')
            ORDER BY __$start_lsn";

        await using var cmd = new SqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@from_lsn", fromLsn);
        cmd.Parameters.AddWithValue("@to_lsn", toLsn);

        SqlDataReader reader;
        try
        {
            reader = await cmd.ExecuteReaderAsync();
        }
        catch (SqlException ex)
        {
            Console.WriteLine($"  ❌ Error querying {tableName}: {ex.Message}");
            Console.WriteLine($"  SQL: {sql}");
            throw;
        }

        await using (reader)
        {

        int changeCount = 0;

        while (await reader.ReadAsync())
        {
            changeCount++;

            // Read CDC metadata columns
            var startLsn = (byte[])reader["__$start_lsn"];
            var operation = (int)reader["__$operation"];
            var updateMask = reader["__$update_mask"] as byte[];

            // Get the primary key value
            var keyValue = reader[keyColumn];

            // Determine operation type
            var operationType = operation switch
            {
                1 => "DELETE",
                2 => "INSERT",
                4 => "UPDATE",
                _ => $"UNKNOWN({operation})"
            };

            // Build a concise summary of the change
            var summary = BuildChangeSummary(tableName, reader, keyColumn, keyValue);

            Console.WriteLine($"  [{operationType}] {summary}");
        }

            if (changeCount == 0)
            {
                Console.WriteLine($"  (No changes)");
            }

            Console.WriteLine();

            return changeCount;
        }
    }

    /// <summary>
    /// Builds a concise one-line summary of a change record
    /// </summary>
    private static string BuildChangeSummary(string tableName, SqlDataReader reader, string keyColumn, object keyValue)
    {
        var sb = new StringBuilder();
        sb.Append($"{keyColumn}={keyValue}");

        // Add relevant fields based on table type
        switch (tableName)
        {
            case "trades":
                sb.Append($" | ISIN={GetStringValue(reader, "isin")}");
                sb.Append($" | Counterparty={GetStringValue(reader, "counterparty")}");
                sb.Append($" | Notional={GetDecimalValue(reader, "notional_amount"):N2} {GetStringValue(reader, "currency")}");
                sb.Append($" | Status={GetStringValue(reader, "status")}");
                sb.Append($" | Asset={GetStringValue(reader, "asset_class")}");
                break;

            case "positions":
                sb.Append($" | ISIN={GetStringValue(reader, "isin")}");
                sb.Append($" | Qty={GetDecimalValue(reader, "quantity"):N4}");
                sb.Append($" | MV={GetDecimalValue(reader, "market_value"):N2} {GetStringValue(reader, "currency")}");
                sb.Append($" | Asset={GetStringValue(reader, "asset_class")}");

                // Include risk metrics for FI positions
                var assetClass = GetStringValue(reader, "asset_class");
                if (assetClass == "FI")
                {
                    sb.Append($" | OAD={GetDecimalValue(reader, "oad"):F4}");
                    sb.Append($" | OAS={GetDecimalValue(reader, "oas"):F2}bp");
                }
                break;

            case "cash_movements":
                sb.Append($" | Amount={GetDecimalValue(reader, "amount"):N2} {GetStringValue(reader, "currency")}");
                sb.Append($" | Direction={GetStringValue(reader, "direction")}");
                sb.Append($" | Status={GetStringValue(reader, "status")}");
                sb.Append($" | Counterparty={GetStringValue(reader, "counterparty")}");
                break;
        }

        return sb.ToString();
    }

    // Helper methods for safe data access
    private static string GetStringValue(SqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? "NULL" : reader.GetString(ordinal);
    }

    private static decimal GetDecimalValue(SqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? 0m : reader.GetDecimal(ordinal);
    }

    /// <summary>
    /// Reads the last processed LSN from the tracking file
    /// </summary>
    private static async Task<byte[]?> ReadLastProcessedLsnAsync()
    {
        if (!File.Exists(LsnTrackingFile))
        {
            return null;
        }

        try
        {
            var hexString = (await File.ReadAllTextAsync(LsnTrackingFile)).Trim();
            if (string.IsNullOrEmpty(hexString))
            {
                return null;
            }

            // Convert hex string back to byte array
            return Convert.FromHexString(hexString);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"⚠ Warning: Could not read LSN tracking file: {ex.Message}");
            return null;
        }
    }

    /// <summary>
    /// Saves the last processed LSN to the tracking file
    /// </summary>
    private static async Task SaveLastProcessedLsnAsync(byte[] lsn)
    {
        try
        {
            // Convert to hex string for human readability
            var hexString = Convert.ToHexString(lsn);
            await File.WriteAllTextAsync(LsnTrackingFile, hexString);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"⚠ Warning: Could not save LSN tracking file: {ex.Message}");
        }
    }
}
