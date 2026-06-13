#!/usr/bin/env dotnet script

#r "nuget: Microsoft.Data.SqlClient, 5.2.2"

using Microsoft.Data.SqlClient;
using System.IO;
using System.Data;

var connectionString = "Server=localhost,1433;Database=TradingPlatform;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;";
var sqlScript = File.ReadAllText("/Users/yashvyas/Documents/event-driven-project/sql/enable-cdc.sql");

var batches = sqlScript.Split(new[] { "\nGO\n", "\nGO\r\n", "\r\nGO\r\n", "\r\nGO\n" }, StringSplitOptions.RemoveEmptyEntries);

using (var connection = new SqlConnection(connectionString))
{
    connection.Open();
    Console.WriteLine("Connected to TradingPlatform database\n");

    foreach (var batch in batches)
    {
        if (string.IsNullOrWhiteSpace(batch)) continue;

        try
        {
            using (var command = new SqlCommand(batch, connection))
            {
                command.CommandTimeout = 120;

                using (var reader = command.ExecuteReader())
                {
                    do
                    {
                        // Print column headers
                        if (reader.HasRows && reader.FieldCount > 0)
                        {
                            var headers = new List<string>();
                            for (int i = 0; i < reader.FieldCount; i++)
                            {
                                headers.Add(reader.GetName(i).PadRight(25));
                            }
                            Console.WriteLine(string.Join(" ", headers));
                            Console.WriteLine(new string('-', headers.Sum(h => h.Length + 1)));
                        }

                        // Print rows
                        while (reader.Read())
                        {
                            var values = new List<string>();
                            for (int i = 0; i < reader.FieldCount; i++)
                            {
                                var value = reader.IsDBNull(i) ? "NULL" : reader.GetValue(i).ToString();
                                values.Add(value.PadRight(25));
                            }
                            Console.WriteLine(string.Join(" ", values));
                        }

                        if (reader.HasRows)
                        {
                            Console.WriteLine();
                        }

                    } while (reader.NextResult());
                }

                // Handle info messages (PRINT statements)
                connection.InfoMessage += (sender, e) =>
                {
                    Console.WriteLine(e.Message);
                };
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
        }
    }

    Console.WriteLine("\n✓ CDC enabled successfully!");
}
