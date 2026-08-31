# Silent Sophos Endpoint Deployment via RMM

## Problem
The four-entity tenant consolidation covered endpoint protection too: four separate Sophos tenants were being merged into one, the same shape as the Level RMM consolidation elsewhere in this repository.

Migration testing surfaced a second, bigger problem. Sophos was stalling the Windows profile re-ACL step of the tenant migration (re-permissioning local profiles to the target-tenant identities), turning a few minutes per machine into days. The endpoint plan therefore became: remotely remove Sophos before migration, run the migration and re-ACL at normal speed, then silently reinstall Sophos into the consolidated tenant afterward, without user interaction and without the automation unexpectedly rebooting endpoints.

## Fix
This script is the reinstall leg. The PowerShell wrapper validates the packaged installer, creates a persistent log location, checks for another active Sophos install, launches the installer silently, and handles known installer return codes.

## Safety / Notes
- Fails early if the installer is missing from the automation package.
- Refuses to launch a second Sophos installer concurrently.
- Logs execution identity, progress, and exit code.
- Treats exit code `3010` as successful but reboot-required without initiating the restart.
- Flags `1641` because it indicates that the installer initiated a reboot.
- Sequencing mattered: reinstall only ran after the migration/re-ACL had completed on the endpoint.

## Result
Endpoints came through the migration with the re-ACL running at normal speed instead of days, then were re-protected in the consolidated Sophos tenant through a silent RMM push, with endpoint-side logs retained for any failed installs.

## Notes
**Recovered exact source with organization-specific installer naming sanitized.**

## Script

```powershell
# Sophos Central Endpoint - Silent Install via Level
# Place SophosSetup.exe in the same Level automation/package as this script.
# Runs silently and does not initiate a restart.

$ErrorActionPreference = "Stop"

$InstallerName = "SophosSetup.exe"
$InstallerPath = Join-Path -Path $PSScriptRoot -ChildPath $InstallerName
$LogDirectory = "C:\ProgramData\Level\Logs"
$LogPath = Join-Path -Path $LogDirectory -ChildPath "SophosInstall.log"

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "[$Timestamp] $Message"
    Write-Output $Entry
    Add-Content -Path $LogPath -Value $Entry -Encoding UTF8
}

try {
    New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null

    Write-Log "Starting Sophos silent installation."
    Write-Log "Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"

    if (-not [Environment]::Is64BitOperatingSystem) {
        Write-Log "WARNING: The target device is running a 32-bit operating system."
    }

    if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
        throw "Installer not found: $InstallerPath. Attach $InstallerName to the same Level automation as this script."
    }

    # Avoid launching a second Sophos installer if one is already active.
    $ExistingInstaller = Get-Process -Name "SophosSetup", "SophosInstall" -ErrorAction SilentlyContinue
    if ($ExistingInstaller) {
        throw "A Sophos installation process is already running."
    }

    Write-Log "Installer found: $InstallerPath"
    Write-Log "Launching installer with --quiet."

    $Process = Start-Process `
        -FilePath $InstallerPath `
        -ArgumentList "--quiet" `
        -WorkingDirectory $PSScriptRoot `
        -WindowStyle Hidden `
        -Wait `
        -PassThru

    $ExitCode = $Process.ExitCode
    Write-Log "Sophos installer exit code: $ExitCode"

    switch ($ExitCode) {
        0 {
            Write-Log "Sophos installation completed successfully. No restart was initiated."
            exit 0
        }

        3010 {
            Write-Log "Sophos installation completed successfully, but Windows reports that a restart is required. This script will not restart the device."
            exit 0
        }

        1641 {
            # 1641 conventionally means the installer initiated a restart.
            # The script itself never invokes Restart-Computer or shutdown.exe.
            Write-Log "Sophos returned exit code 1641, indicating a restart was initiated by the installer."
            exit 1
        }

        default {
            throw "Sophos installation failed with exit code $ExitCode."
        }
    }
}
catch {
    try {
        Write-Log "ERROR: $($_.Exception.Message)"
    }
    catch {
        Write-Error $_.Exception.Message
    }

    exit 1
}
```
