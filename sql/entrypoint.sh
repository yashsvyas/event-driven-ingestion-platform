#!/bin/bash

# Start SQL Server in the background
/opt/mssql/bin/sqlservr &

# Wait for SQL Server to start up
echo "Waiting for SQL Server to start..."
sleep 30s

# Run the initialization script
echo "Running init script..."
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P ${MSSQL_SA_PASSWORD} -C -i /docker-entrypoint-initdb.d/init.sql

# Keep the container running by bringing SQL Server back to foreground
wait
