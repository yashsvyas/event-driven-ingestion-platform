#!/usr/bin/env dotnet script

#r "nuget: Microsoft.Data.SqlClient, 5.2.2"

using Microsoft.Data.SqlClient;

var connectionString = "Server=localhost,1433;Database=TradingPlatform;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;";

using (var connection = new SqlConnection(connectionString))
{
    connection.Open();
    Console.WriteLine("✓ Connected to TradingPlatform database\n");

    var tables = new[] { "trades", "positions", "cash_movements" };

    foreach (var table in tables)
    {
        using (var command = new SqlCommand($"SELECT COUNT(*) FROM {table}", connection))
        {
            var count = (int)command.ExecuteScalar();
            Console.WriteLine($"  {table,-20} {count,3} rows");
        }
    }

    Console.WriteLine("\n✓ Database verification complete!");
}
