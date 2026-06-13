#!/usr/bin/env dotnet script

#r "nuget: Microsoft.Data.SqlClient, 5.2.2"

using Microsoft.Data.SqlClient;

var connectionString = "Server=localhost,1433;Database=TradingPlatform;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;";

using (var connection = new SqlConnection(connectionString))
{
    connection.Open();

    // Get LSN range
    var fromLsnSql = "SELECT MIN(start_lsn) FROM cdc.change_tables";
    var toLsnSql = "SELECT sys.fn_cdc_get_max_lsn()";

    byte[] fromLsn;
    byte[] toLsn;

    using (var cmd = new SqlCommand(fromLsnSql, connection))
    {
        fromLsn = (byte[])cmd.ExecuteScalar();
    }

    using (var cmd = new SqlCommand(toLsnSql, connection))
    {
        toLsn = (byte[])cmd.ExecuteScalar();
    }

    Console.WriteLine($"LSN Range: {BitConverter.ToString(fromLsn).Replace("-", "")} to {BitConverter.ToString(toLsn).Replace("-", "")}\n");

    // Test different tables
    var tables = new[] { "dbo_trades", "dbo_positions", "dbo_cash_movements" };

    foreach (var table in tables)
    {
        Console.WriteLine($"Testing table: {table}");

        try
        {
            var sql = $"SELECT TOP 1 * FROM cdc.fn_cdc_get_net_changes_{table}(@from_lsn, @to_lsn, 'all')";

            using (var cmd = new SqlCommand(sql, connection))
            {
                cmd.Parameters.AddWithValue("@from_lsn", fromLsn);
                cmd.Parameters.AddWithValue("@to_lsn", toLsn);

                using (var reader = cmd.ExecuteReader())
                {
                    if (reader.Read())
                    {
                        Console.WriteLine($"  ✓ SUCCESS - Got 1 row with {reader.FieldCount} columns");
                    }
                    else
                    {
                        Console.WriteLine($"  ✓ SUCCESS - No rows but query executed");
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"  ❌ FAILED - {ex.Message}");

            // Try all changes function as fallback
            try
            {
                var sql2 = $"SELECT TOP 1 * FROM cdc.fn_cdc_get_all_changes_{table}(@from_lsn, @to_lsn, 'all')";

                using (var cmd = new SqlCommand(sql2, connection))
                {
                    cmd.Parameters.AddWithValue("@from_lsn", fromLsn);
                    cmd.Parameters.AddWithValue("@to_lsn", toLsn);

                    using (var reader = cmd.ExecuteReader())
                    {
                        if (reader.Read())
                        {
                            Console.WriteLine($"  ✓ FALLBACK TO ALL_CHANGES - Got 1 row with {reader.FieldCount} columns");
                        }
                        else
                        {
                            Console.WriteLine($"  ✓ FALLBACK TO ALL_CHANGES - No rows but query executed");
                        }
                    }
                }
            }
            catch (Exception ex2)
            {
                Console.WriteLine($"  ❌ ALL_CHANGES ALSO FAILED - {ex2.Message}");
            }
        }

        Console.WriteLine();
    }
}
