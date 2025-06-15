#!/bin/bash

# Check shell version
echo "Running with shell: $BASH_VERSION"

# Config
SERVER="wpaine.database.windows.net"
DISCOVERY_DB="discovery"
AUTH_ARGS="--authentication-method ActiveDirectoryAzCli"

echo "🔐 Logging in interactively to Azure SQL..."

# Read sample_users into memory
echo "📥 Reading sample_users from $DISCOVERY_DB..."
sample_users=()
while IFS= read -r line; do
  sample_users+=("$line")
done < <(sqlcmd $AUTH_ARGS -S "$SERVER" -d "$DISCOVERY_DB" -h -1 -W -s "," -Q "SET NOCOUNT ON;SELECT first, last, email FROM sample_users")

# Read client DB names
echo "📋 Fetching client database names from $DISCOVERY_DB..."
client_dbs=()
while IFS= read -r line; do
  client_dbs+=("$line")
done < <(sqlcmd $AUTH_ARGS -S "$SERVER" -d "$DISCOVERY_DB" -h -1 -W -Q "SET NOCOUNT ON;SELECT database_name FROM clients")

# Loop through each DB
for dbname in "${client_dbs[@]}"; do
  [[ -z "$dbname" ]] && continue

  echo "⚙️  Processing $dbname..."
continue
  # Create users table if not exists
  sqlcmd $AUTH_ARGS -S "$SERVER" -d "$dbname" -Q "
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'users')
BEGIN
  CREATE TABLE users (
    first NVARCHAR(100),
    last NVARCHAR(100),
    email NVARCHAR(255)
  );
END;
"

  # Random sample size between 500 and 5000
  count=$((RANDOM % 4501 + 500)) 

  # Shuffle sample_users manually (no shuf in Bash 3.2, so use awk workaround)
  sample=()
  while IFS= read -r line; do sample+=("$line"); done < <(printf "%s\n" "${sample_users[@]}" | awk 'BEGIN {srand()} {print rand(), $0}' | sort -k1,1n | cut -d' ' -f2- | head -n $count)

  # Build a single INSERT statement
  batch_size=1000
  row_count=0
  insert_chunk=""

  for row in "${sample[@]}"; do
    IFS=',' read -r first last email <<< "$row"
    first="${first//\'/''}"
    last="${last//\'/''}"
    email="${email//\'/''}"
    insert_chunk+="(N'$first', N'$last', N'$email'),"
    row_count=$((row_count + 1))

    if (( row_count % batch_size == 0 )); then
      # Trim trailing comma, build full insert, execute
      insert_stmt="INSERT INTO users (first, last, email) VALUES ${insert_chunk%,};"
      sqlcmd $AUTH_ARGS -S "$SERVER" -d "$dbname" -Q "$insert_stmt"
      insert_chunk=""
    fi
  done

  # Final leftover insert (if any)
  if [[ -n "$insert_chunk" ]]; then
    insert_stmt="INSERT INTO users (first, last, email) VALUES ${insert_chunk%,};"
    sqlcmd $AUTH_ARGS -S "$SERVER" -d "$dbname" -Q "$insert_stmt"
  fi

  echo "✅ Inserted $row_count rows into $dbname.users"
done

echo "✅ Done."