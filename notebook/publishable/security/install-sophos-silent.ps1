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
