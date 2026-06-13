#!/usr/bin/env dotnet script

#r "nuget: Microsoft.Data.SqlClient, 5.2.2"

using Microsoft.Data.SqlClient;
using System.IO;

var connectionString = "Server=localhost,1433;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;";
var sqlScript = File.ReadAllText("/Users/yashvyas/Documents/event-driven-project/sql/init.sql");

var batches = sqlScript.Split(new[] { "\nGO\n", "\nGO\r\n", "\r\nGO\r\n", "\r\nGO\n" }, StringSplitOptions.RemoveEmptyEntries);

using (var connection = new SqlConnection(connectionString))
{
    connection.Open();
    Console.WriteLine("Connected to SQL Server successfully!");

    foreach (var batch in batches)
    {
        if (string.IsNullOrWhiteSpace(batch)) continue;

        try
        {
            using (var command = new SqlCommand(batch, connection))
            {
                command.ExecuteNonQuery();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error executing batch: {ex.Message}");
            Console.WriteLine($"Batch: {batch.Substring(0, Math.Min(100, batch.Length))}...");
        }
    }

    Console.WriteLine("Database initialized successfully!");
}
