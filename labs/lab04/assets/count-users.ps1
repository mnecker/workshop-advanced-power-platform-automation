# Config
$server = "wpaine.database.windows.net"
$discoveryDb = "discovery"

# Helper: Run sqlcmd and return results as array of strings
function Run-SqlCmd {
    param (
        [string]$database,
        [string]$query
    )
    $tempFile = New-TemporaryFile
    & sqlcmd --authentication-method ActiveDirectoryAzCli -S $server -d $database -Q $query -W -h -1 -s "," > $tempFile
    $results = Get-Content $tempFile | Where-Object { $_ -ne "" }
    Remove-Item $tempFile -Force
    return $results
}

# Step 1: Get list of databases from discovery_db
$databases = Run-SqlCmd -database $discoveryDb -query "SET NOCOUNT ON;SELECT database_name FROM clients"
$total = $databases.Count
$index = 0

# Step 2: Build email → set of databases map
$emailDbMap = @{}

foreach ($db in $databases) {
    $index++
    Write-Output "[$index/$total] Processing database: $db"

    try {
        $emails = Run-SqlCmd -database $db -query "SET NOCOUNT ON;SELECT email FROM users"
        foreach ($email in $emails) {
            $emailLower = $email.ToLower()
            if (-not $emailDbMap.ContainsKey($emailLower)) {
                $emailDbMap[$emailLower] = [System.Collections.Generic.HashSet[string]]::new()
            }
            $emailDbMap[$emailLower].Add($db) | Out-Null
        }
    } catch {
        Write-Warning "Failed to query ${db}: $_"
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