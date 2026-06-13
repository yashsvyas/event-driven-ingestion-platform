#!/usr/bin/env dotnet script

#r "nuget: Microsoft.Data.SqlClient, 5.2.2"

using Microsoft.Data.SqlClient;

var connectionString = "Server=localhost,1433;Database=TradingPlatform;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;";

using (var connection = new SqlConnection(connectionString))
{
    connection.Open();
    Console.WriteLine("CDC change tables and configuration:\n");

    var sql = @"
        SELECT
            capture_instance,
            supports_net_changes,
            start_lsn
        FROM cdc.change_tables
        ORDER BY capture_instance";

    using (var cmd = new SqlCommand(sql, connection))
    using (var reader = cmd.ExecuteReader())
    {
        while (reader.Read())
        {
            Console.WriteLine($"  {reader["capture_instance"],-30} | supports_net_changes: {reader["supports_net_changes"]} | start_lsn: {BitConverter.ToString((byte[])reader["start_lsn"]).Replace("-", "")}");
        }
    }

    Console.WriteLine("\nAll CDC table-valued functions:");
    sql = "SELECT name FROM sys.objects WHERE schema_id = SCHEMA_ID('cdc') AND type IN ('TF', 'IF', 'FN') ORDER BY name";

    using (var cmd = new SqlCommand(sql, connection))
    using (var reader = cmd.ExecuteReader())
    {
        while (reader.Read())
        {
            Console.WriteLine($"  {reader["name"]}");
        }
    }
}
