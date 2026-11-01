# Remove Legacy Applications by Display Name

## Problem
During a tenant and endpoint migration, workstations accumulated software that was no longer needed after cutover. The cleanup set included migration agents and legacy applications. Manually removing each product was impractical and inconsistent, especially because the automation needed to run in SYSTEM context through endpoint management.

## Investigation
The production transcript showed the cleanup enumerating installed software from the Windows uninstall registry, identifying the product name, version, publisher, uninstall string and quiet uninstall string. Different installer technologies behaved differently: MSI products returned normal Windows Installer codes while executable uninstallers could return vendor-specific values.

## Fix
The public version searches both 32-bit and 64-bit uninstall registry paths, accepts one or more display-name patterns, prefers a vendor-provided quiet uninstall string, normalizes MSI removals to silent `/qn /norestart`, logs exit codes, and performs a second inventory pass after removal.

## Safety / Notes
- `SupportsShouldProcess` and `-WhatIf` support.
- Targets are explicit display-name patterns rather than blanket software removal.
- Both registry views are checked.
- Every uninstall result is logged.
- Final verification treats still-installed targets as a failure instead of assuming the uninstall command succeeded.

## Result
In production the migration agent was removed successfully, ShareFile was removed after iterative testing, and final verification correctly identified software that remained installed. The script re-checks installed state instead of treating an uninstall exit code as proof of success.

## Notes

The original production code has been modified to run read-only for this public notebook.

## Script

```powershell
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory)]
    [string[]]$DisplayNamePattern,

    [string]$LogPath = "$env:ProgramData\LegacyAppCleanup\cleanup.log"
)

$ErrorActionPreference = 'Stop'

# Read-only for publication: WhatIf is forced on, so every change is
# simulated and logged instead of executed.
$WhatIfPreference = $true
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format s) $Message"
    $line | Tee-Object -FilePath $LogPath -Append
}

function Get-InstalledApplication {
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    Get-ItemProperty $roots -ErrorAction SilentlyContinue |
        Where-Object DisplayName |
        Sort-Object PSPath -Unique
}

function Invoke-AppUninstall {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory)]$App)

    $command = if ($App.QuietUninstallString) { $App.QuietUninstallString } else { $App.UninstallString }
    if (-not $command) {
        Write-Log "No uninstall command available for '$($App.DisplayName)'."
        return
    }

    # MSI product-code uninstall strings are normalized to a silent uninstall.
    if ($command -match '(?i)msiexec(?:\.exe)?\s+/[IX]\s*\{([^}]+)\}') {
        $file = "$env:SystemRoot\System32\msiexec.exe"
        $argList = "/x {$($Matches[1])} /qn /norestart"
    }
    else {
        $file = 'cmd.exe'
        $argList = "/d /s /c `"$command`""
    }

    if ($PSCmdlet.ShouldProcess($App.DisplayName, "Uninstall using $file $argList")) {
        Write-Log "Uninstalling '$($App.DisplayName)' version '$($App.DisplayVersion)' publisher '$($App.Publisher)'."
        $p = Start-Process -FilePath $file -ArgumentList $argList -Wait -PassThru -WindowStyle Hidden
        Write-Log "Uninstall exit code for '$($App.DisplayName)': $($p.ExitCode)"
    }
}

$apps = Get-InstalledApplication
foreach ($pattern in $DisplayNamePattern) {
    Write-Log "Checking for applications matching: $pattern"
    $matched = $apps | Where-Object { $_.DisplayName -like "*$pattern*" }

    if (-not $matched) {
        Write-Log "No matching applications found for '$pattern'."
        continue
    }

    foreach ($app in $matched) {
        Invoke-AppUninstall -App $app
    }
}

Write-Log 'Performing final verification.'
$remaining = Get-InstalledApplication | Where-Object {
    $name = $_.DisplayName
    $DisplayNamePattern | Where-Object { $name -like "*$_*" }
}

if ($remaining) {
    foreach ($app in $remaining) {
        Write-Warning "Remaining application: $($app.DisplayName) $($app.DisplayVersion) [$($app.Publisher)]"
    }
    exit 1
}

Write-Log 'All targeted applications are absent.'
```
