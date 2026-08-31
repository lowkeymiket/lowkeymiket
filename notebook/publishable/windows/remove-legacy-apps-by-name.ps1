[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory)]
    [string[]]$DisplayNamePattern,

    [string]$LogPath = "$env:ProgramData\LegacyAppCleanup\cleanup.log"
)

$ErrorActionPreference = 'Stop'
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
