# Validate Entra Join and MDM State After Migration

## Problem

During tenant-consolidation testing, a workstation could be successfully joined to the target Microsoft Entra tenant while still not being managed by Intune. Treating those states as equivalent would create a false-positive migration result: identity could look correct while compliance, application deployment, security policy, and configuration management were still missing.

## Investigation

We used `dsregcmd /status` and the Entra/Intune management portals to separate device-registration state from MDM enrollment state. Recovered evidence shows a migrated workstation reporting `AzureAdJoined : YES` and `DeviceAuthStatus : SUCCESS`, while separate Intune configuration work was still required.

## Fix

This public reconstruction turns those checks into a reusable validation script. It records:

- Entra join state;
- domain / enterprise join state;
- device authentication status;
- tenant identity;
- MDM URLs advertised to the device; and
- Windows enrollment-registry indicators.

It warns when Entra join is absent, device authentication is unhealthy, or there are no obvious MDM enrollment indicators.

## Safety / Notes

The script is completely read-only. It deliberately does not attempt automatic enrollment because the correct remediation depends on tenant MDM scope, licensing, enrollment restrictions, Conditional Access, device ownership, and migration tooling.

## Result

The diagnostic approach prevented a successful Entra join from being incorrectly treated as a complete endpoint migration. That distinction is important during large tenant cutovers because identity, Office profile transition, OneDrive transition, and MDM enrollment can succeed or fail independently.

## Publication note

The script below is read-only by design: it only queries and reports, and makes no changes.

## Script

```powershell
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
```
