[CmdletBinding()]
param(
    [string]$CsvPath
)

$ErrorActionPreference = 'Stop'

$dsreg = & dsregcmd.exe /status 2>&1 | Out-String

function Get-DsRegValue {
    param([Parameter(Mandatory)][string]$Name)
    $pattern = '(?m)^\s*' + [regex]::Escape($Name) + '\s*:\s*(.+?)\s*$'
    $match = [regex]::Match($dsreg, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return $null
}

$enrollmentRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Enrollments',
    'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts'
)

$enrollmentKeys = foreach ($root in $enrollmentRoots) {
    if (Test-Path $root) {
        Get-ChildItem $root -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName
    }
}

$result = [pscustomobject]@{
    ComputerName       = $env:COMPUTERNAME
    AzureAdJoined      = Get-DsRegValue 'AzureAdJoined'
    EnterpriseJoined   = Get-DsRegValue 'EnterpriseJoined'
    DomainJoined       = Get-DsRegValue 'DomainJoined'
    DeviceAuthStatus   = Get-DsRegValue 'DeviceAuthStatus'
    TenantName         = Get-DsRegValue 'TenantName'
    TenantId           = Get-DsRegValue 'TenantId'
    MdmUrl             = Get-DsRegValue 'MdmUrl'
    MdmTouUrl          = Get-DsRegValue 'MdmTouUrl'
    MdmComplianceUrl   = Get-DsRegValue 'MdmComplianceUrl'
    EnrollmentKeyCount = @($enrollmentKeys | Sort-Object -Unique).Count
    CheckedAt          = Get-Date
}

$result | Format-List

if ($result.AzureAdJoined -ne 'YES') {
    Write-Warning 'Device is not Microsoft Entra joined according to dsregcmd.'
}
if ($result.DeviceAuthStatus -and $result.DeviceAuthStatus -ne 'SUCCESS') {
    Write-Warning "Device authentication status is $($result.DeviceAuthStatus)."
}
if (-not $result.MdmUrl -and $result.EnrollmentKeyCount -eq 0) {
    Write-Warning 'No obvious MDM enrollment indicators were found. Entra join does not by itself prove Intune enrollment.'
}

if ($CsvPath) {
    $result | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Exported validation result to $CsvPath"
}
