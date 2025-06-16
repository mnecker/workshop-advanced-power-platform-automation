# Define Azure SQL details
$RESOURCE_GROUP = "wpaine"
$SERVER_NAME = "wpaine"
$ELASTIC_POOL = "wpaine"
$DISCOVERY_DB = "discovery"
$AUTH_ARGS = @("--authentication-method", "ActiveDirectoryAzCli")

# Step 0: Open firewall for the current IP
$MY_IP = Invoke-RestMethod -Uri "https://api.ipify.org"
Write-Host "Opening firewall for IP: $MY_IP"
az sql server firewall-rule create `
    --resource-group $RESOURCE_GROUP `
    --server $SERVER_NAME `
    --name AllowMyIP `
    --start-ip-address $MY_IP `
    --end-ip-address $MY_IP

# Step 1: Fetch database names into a variable
Write-Host "Fetching database names from $DISCOVERY_DB"
$DATABASES = & sqlcmd $AUTH_ARGS -S "$SERVER_NAME.database.windows.net" -d "$DISCOVERY_DB" -h -1 -W -Q "SET NOCOUNT ON;SELECT [database] FROM clients;" | ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne "" }

# Step 2: Loop through the list of databases
$DATABASES | ForEach-Object -Parallel {
    $dbname = $_
    Write-Host "Creating database: $dbname"

    # Create the database inside the elastic pool
    $dbexists = az sql db show `
        --name $dbname `
        --server $using:SERVER_NAME `
        --resource-group $using:RESOURCE_GROUP `
        --only-show-errors `
        --output json 2>$null

    if ($dbexists) {
        Write-Host "Database '$dbname' exists"
    } else {
        Write-Host "Creating database '$dbname'"
        az sql db create `
            --resource-group $using:RESOURCE_GROUP `
            --server $using:SERVER_NAME `
            --name $dbname `
            --elastic-pool $using:ELASTIC_POOL `
            --zone-redundant false `
            --backup-storage-redundancy Local
    }

    # function to generate a random strong password. Can't use GeneratePassword in PS 7
    function New-AzureSqlPassword {
        param([int]$Length = 16)
        $upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        $lower = 'abcdefghijklmnopqrstuvwxyz'
        $digit = '0123456789'
        $special = '!@#$%^&*'

        $chars = ($upper + $lower + $digit + $special).ToCharArray()
        $rand = [System.Random]::new()

        # Ensure at least one of each required type
        $password = @(
            $upper[$rand.Next($upper.Length)]
            $lower[$rand.Next($lower.Length)]
            $digit[$rand.Next($digit.Length)]
            $special[$rand.Next($special.Length)]
        )

        for ($i = $password.Count; $i -lt $Length; $i++) {
            $password += $chars[$rand.Next($chars.Length)]
        }

        # Shuffle and join
        -join ($password | Sort-Object {Get-Random})
    }

    # Generate a random password for the database user
    $DB_USER = "${dbName}_reader"
    $DB_PASSWORD = New-AzureSqlPassword 16 # Escape single quotes for SQL

    $userSql = @"
    IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$DB_USER')
        ALTER USER [$DB_USER] WITH PASSWORD = '$DB_PASSWORD';
    ELSE
        CREATE USER [$DB_USER] WITH PASSWORD = '$DB_PASSWORD';
    ALTER ROLE db_datareader ADD MEMBER [$DB_USER];
"@

    Write-Host "Creating user: $DB_USER in database: $dbname"

    # Step 4: Create user and add to db_owner in the target database
    & sqlcmd -S "$using:SERVER_NAME.database.windows.net" $using:AUTH_ARGS -d "$dbname" -Q $userSql
    # Step 5: Store the credentials
    
# Test the new user's connection
& sqlcmd -S "$using:SERVER_NAME.database.windows.net" -U "$DB_USER" -P "$DB_PASSWORD" -d "$dbname" -Q "SELECT 1"
    & sqlcmd $using:AUTH_ARGS -S "$using:SERVER_NAME.database.windows.net" -d "$using:DISCOVERY_DB" -Q "UPDATE clients SET [username] = '$DB_USER', [password]='$DB_PASSWORD' WHERE [database] = '$dbname';"

    Write-Host "Database $dbname created with user $DB_USER. Connection details updated."
} -ThrottleLimit 10

Write-Host "All databases and users created successfully!"
# ...existing code...