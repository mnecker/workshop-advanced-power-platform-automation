# Config
$server = "wpaine.database.windows.net"
$discoveryDb = "discovery"

$discoveryUsername = Read-Host "Enter discovery database username"
$discoveryPassword = Read-Host "Enter discovery database password" -AsSecureString
 $discoveryPasswordPlain = $discoveryPassword | ConvertFrom-SecureString -AsPlainText
# Helper: Run sqlcmd and return results as array of strings
function Run-SqlCmd {
    param (
        [string]$server,
        [string]$database,
        [string]$query,
        [string]$username = $null,
        [string]$password = $null
    )
    $tempFile = New-TemporaryFile
    if ($username -and $password) {
        & sqlcmd -U $username -P $password -S $server -d $database -Q $query -W -h -1 -s "," > $tempFile
    } else {
        & sqlcmd --authentication-method ActiveDirectoryAzCli -S $server -d $database -Q $query -W -h -1 -s "," > $tempFile
    }
    $results = Get-Content $tempFile | Where-Object { $_ -ne "" }
    Remove-Item $tempFile -Force
    return $results
}

# Step 1: Get list of client records from discovery_db
$clientRecords = Run-SqlCmd -server $server -database $discoveryDb -query "SET NOCOUNT ON;SELECT [server], [database], username, password FROM clients" -username $discoveryUsername -password $discoveryPasswordPlain

$total = $clientRecords.Count
$index = 0

# Step 2: Build email → set of databases map
$emailDbMap = @{}

foreach ($record in $clientRecords | Where-Object { $_.Trim() -ne "" }) {
    $index++
    $columns = $record -split ","
    $clientServer = $columns[0].Trim()
    $clientDatabase = $columns[1].Trim()
    $clientUsername = $columns[2].Trim()
    $clientPassword = $columns[3].Trim()

    Write-Output "[$index/$total] Processing database: $clientDatabase on $clientServer"

    try {
        $emails = Run-SqlCmd -server $clientServer -database $clientDatabase -query "SET NOCOUNT ON;SELECT email FROM users" -username $clientUsername -password $clientPassword
        foreach ($email in $emails) {
            $emailLower = $email.ToLower()
            if (-not $emailDbMap.ContainsKey($emailLower)) {
                $emailDbMap[$emailLower] = [System.Collections.Generic.HashSet[string]]::new()
            }
            $emailDbMap[$emailLower].Add($clientDatabase) | Out-Null
        }
    } catch {
        Write-Warning "Failed to query ${clientDatabase} on ${clientServer}: $_"
    }
}

Write-Host "`nTotal unique emails collected: $($emailDbMap.Count)" -ForegroundColor Yellow

# Step 3: Group by number of databases and track detailed info for users with < 10 DBs
$groupCounts = @{}
$detailsToPrint = @()

foreach ($kvp in $emailDbMap.GetEnumerator()) {
    $count = $kvp.Value.Count
    if (-not $groupCounts.ContainsKey($count)) {
        $groupCounts[$count] = 0
    }
    $groupCounts[$count]++

    if ($count -gt 10) {
        $detailsToPrint += @{
            Email = $kvp.Key
            Count = $count
            Databases = ($kvp.Value | Sort-Object -CaseSensitive) -join ", "
        }
    }
}

# Step 4: Output summary
$groupCounts.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Output "$($_.Key): $($_.Value)"
}

# Step 5: Output details for users in <10 databases
if ($detailsToPrint.Count -gt 0) {
    Write-Host "`nDetails for users in more than 10 databases:`n" -ForegroundColor Cyan
    $detailsToPrint | Sort-Object Count | ForEach-Object {
        Write-Output "[$($_.Count)] $($_.Email) → $($_.Databases)"
    }
}

# Step 6: build python chart
$groupCounts.GetEnumerator() |
    Sort-Object Name |
    ConvertTo-Csv -NoTypeInformation |
    Set-Content groupcounts.csv

    python3 -m venv venv
    venv/bin/Activate.ps1
    python3 -m pip install pandas matplotlib  
    python3 -c "
import pandas as pd; import matplotlib.pyplot as plt
df = pd.read_csv('groupcounts.csv')
df.sort_values('Name', inplace=True)
plt.bar(df['Name'], df['Value'])
plt.xlabel('Databases per User'); plt.ylabel('User Count'); plt.title('User Duplicates')
plt.show()
"
    deactivate #deactivate python virtual environment