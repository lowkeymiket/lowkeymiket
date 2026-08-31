param(
    [Parameter(Mandatory = $false)]
    [string]$CsvPath = ".\Employee ID Update.csv",

    [Parameter(Mandatory = $false)]
    [string]$LogPath = ".\EmployeeIdUpdateResults.csv",

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $CsvPath)) {
    throw "CSV file not found: $CsvPath"
}

$requiredModules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Users')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing missing module: $module" -ForegroundColor Yellow
        Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
    }
}

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Users

Connect-MgGraph -Scopes 'User.ReadWrite.All'

$rows = Import-Csv -LiteralPath $CsvPath
$results = New-Object System.Collections.Generic.List[object]

foreach ($row in $rows) {
    $upn = $row.'User principal name'
    $employeeId = $row.'Employee ID'
    $firstName = $row.'First Name'
    $lastName = $row.'Last Name'

    if ([string]::IsNullOrWhiteSpace($upn) -or [string]::IsNullOrWhiteSpace($employeeId)) {
        $results.Add([pscustomobject]@{
            UserPrincipalName = $upn
            EmployeeId        = $employeeId
            FirstName         = $firstName
            LastName          = $lastName
            Status            = 'Skipped'
            Notes             = 'Missing UPN or Employee ID'
        })
        continue
    }

    if ($employeeId.Length -gt 16) {
        $results.Add([pscustomobject]@{
            UserPrincipalName = $upn
            EmployeeId        = $employeeId
            FirstName         = $firstName
            LastName          = $lastName
            Status            = 'Skipped'
            Notes             = 'Employee ID exceeds 16 characters'
        })
        continue
    }

    try {
        $user = Get-MgUser -UserId $upn -Property 'id,userPrincipalName,displayName,employeeId,onPremisesSyncEnabled' -ErrorAction Stop

        if ($user.OnPremisesSyncEnabled -eq $true) {
            $results.Add([pscustomobject]@{
                UserPrincipalName = $upn
                EmployeeId        = $employeeId
                FirstName         = $firstName
                LastName          = $lastName
                Status            = 'Skipped'
                Notes             = 'User is synced from on-premises and should be updated at the source directory'
            })
            continue
        }

        if ($DryRun) {
            $results.Add([pscustomobject]@{
                UserPrincipalName = $upn
                EmployeeId        = $employeeId
                FirstName         = $firstName
                LastName          = $lastName
                Status            = 'WouldUpdate'
                Notes             = "Current Employee ID: $($user.EmployeeId)"
            })
            continue
        }

        Update-MgUser -UserId $user.Id -EmployeeId $employeeId -ErrorAction Stop

        $results.Add([pscustomobject]@{
            UserPrincipalName = $upn
            EmployeeId        = $employeeId
            FirstName         = $firstName
            LastName          = $lastName
            Status            = 'Updated'
            Notes             = "Previous Employee ID: $($user.EmployeeId)"
        })
    }
    catch {
        $results.Add([pscustomobject]@{
            UserPrincipalName = $upn
            EmployeeId        = $employeeId
            FirstName         = $firstName
            LastName          = $lastName
            Status            = 'Error'
            Notes             = $_.Exception.Message
        })
    }
}

$results | Export-Csv -LiteralPath $LogPath -NoTypeInformation -Encoding UTF8
Write-Host "Done. Results written to $LogPath" -ForegroundColor Green
