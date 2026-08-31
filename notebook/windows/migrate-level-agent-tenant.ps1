<#
Recovered exact source from a four-tenant RMM consolidation.
Delivered through the OLD tenant's Level terminal: the wrapper writes the swap
script to disk and launches it detached, so it survives the uninstall of the
agent that delivered it. Only the tenant API key is a placeholder.
#>

$scriptPath = "C:\Windows\Temp\level-swap-to-new.ps1"

@'
$ErrorActionPreference = "Continue"
$log = "C:\Windows\Temp\level-swap-to-new.log"
function Log($m){ Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m) }

function Stop-Level {
  Log "Stopping Level services/processes..."
  Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "level" -or $_.DisplayName -match "level" } | ForEach-Object {
    try { Stop-Service $_.Name -Force -ErrorAction SilentlyContinue } catch {}
    try { Set-Service $_.Name -StartupType Disabled -ErrorAction SilentlyContinue } catch {}
  }
  foreach($p in @("level","Level")){ try { Stop-Process -Name $p -Force -ErrorAction SilentlyContinue } catch {} }
}

# Decode MSI packed GUID used under HKLM:\SOFTWARE\Classes\Installer\Products
function Convert-PackedGuidToGuid([string]$packed) {
  if (-not $packed -or $packed.Length -ne 32) { return $null }

  function SwapPairs($s) { ($s -split '(.{2})' | Where-Object { $_ })[-1..0] -join '' }

  $a = SwapPairs($packed.Substring(0,8))
  $b = SwapPairs($packed.Substring(8,4))
  $c = SwapPairs($packed.Substring(12,4))

  function NibbleSwapPairs($s) {
    $out = ""
    for ($i=0; $i -lt $s.Length; $i+=2) {
      $pair = $s.Substring($i,2)
      $out += ($pair.Substring(1,1) + $pair.Substring(0,1))
    }
    $out
  }

  $d = NibbleSwapPairs($packed.Substring(16,4))
  $e = NibbleSwapPairs($packed.Substring(20,12))

  "{0}-{1}-{2}-{3}-{4}" -f $a,$b,$c,$d,$e
}

function Find-LevelMsiProductCodes {
  $codes = @()
  $roots = @(
    "HKLM:\SOFTWARE\Classes\Installer\Products",
    "HKLM:\SOFTWARE\WOW6432Node\Classes\Installer\Products"
  )

  foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
      $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
      if ($props -and $props.ProductName -and ($props.ProductName -match "^Level($|\s)")) {
        $guid = Convert-PackedGuidToGuid $_.PSChildName
        if ($guid) { $codes += "{"+$guid+"}" }
      }
    }
  }
  $codes | Select-Object -Unique
}

function Uninstall-Level {
  Stop-Level

  # 1) Vendor uninstall via level.exe
  $levelExe = @(
    "C:\Program Files\Level\level.exe",
    "C:\Program Files (x86)\Level\level.exe"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1

  if ($levelExe) {
    Log "Running vendor uninstall: $levelExe --action uninstall"
    try { & $levelExe --action uninstall | Out-Null } catch { Log "Vendor uninstall error: $_" }
    Start-Sleep 10
  } else {
    Log "level.exe not found in Program Files paths"
  }

  Stop-Level

  # 2) MSI uninstall by product code (covers blank uninstall string cases)
  $codes = @(Find-LevelMsiProductCodes)
  if ($codes.Count -gt 0) {
    foreach ($code in $codes) {
      Log "Uninstalling MSI product $code"
      Start-Process msiexec.exe -Wait -ArgumentList "/x $code /qn /norestart /l*v C:\Windows\Temp\level-uninstall.log" | Out-Null
    }
  } else {
    Log "No MSI product codes found (may already be removed)."
  }

  Stop-Level

  # 3) Remove identity/config leftovers (critical for tenant swap)
  $folders = @(
    "C:\Program Files\Level",
    "C:\Program Files (x86)\Level",
    "$env:ProgramData\Level"
  )
  foreach($f in $folders){
    if(Test-Path $f){
      Log "Removing folder: $f"
      try { Remove-Item $f -Recurse -Force -ErrorAction SilentlyContinue } catch { Log "Remove failed: $_" }
    }
  }
}

function Install-NewTenant {
  Log "Installing Level for NEW tenant..."
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  $msi = Join-Path $env:windir "Temp\level.msi"
  Log "Downloading MSI to $msi"
  Invoke-WebRequest -Uri "https://downloads.level.io/level.msi" -OutFile $msi

  $prop = "LEVEL_API_KEY=INSERT API KEY FROM NEW LEVEL TENANT DEVICE GROUP"
  Log "Running msiexec install with property $prop"
  Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /qn /norestart /l*v C:\Windows\Temp\level-install.log $prop" | Out-Null
  Log "Install complete"

  # Start services best-effort
  Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "level" -or $_.DisplayName -match "level" } | ForEach-Object {
    try { Set-Service $_.Name -StartupType Automatic -ErrorAction SilentlyContinue } catch {}
    try { Start-Service $_.Name -ErrorAction SilentlyContinue } catch {}
  }
}

try {
  Log "=== START swap (to NEW tenant) ==="
  Uninstall-Level
  Install-NewTenant
  Log "=== DONE swap ==="
} catch {
  Log "FATAL: $_"
}
'@ | Set-Content -Path $scriptPath -Encoding UTF8

Start-Process -FilePath "powershell.exe" -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
"Detached swap launched. Log: C:\Windows\Temp\level-swap-to-new.log"
