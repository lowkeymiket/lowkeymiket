# Run Self-Hosted GitHub Actions Runners on Windows with WSL

## What it is
Three self-hosted GitHub Actions runners, one per private repository, run as systemd services in WSL 2 on our build and test server. Each runner polls GitHub over outbound HTTPS, so it needs no inbound ports, and takes one job at a time.

## How it works

### WSL
- **Systemd.** Enabled in `/etc/wsl.conf`, so each runner is an ordinary service, in its own folder under `/opt`, under an unprivileged Linux user with no sudo.
- **Staying up.** WSL stops its VM when nothing is attached, and the runners stop with it. A user-level scheduled task (third block) holds `sleep infinity` in the distro as the runner user, at logon and every 5 minutes, through a headless console host.
- **Memory.** `%UserProfile%\.wslconfig` (first block) caps the VM at 14 GB, about half of what Windows sees, with 8 GB of swap so a heavy job slows down instead of being killed. `autoMemoryReclaim` returns idle page cache to Windows and `sparseVhd` returns freed disk. A fixed 40 GB page file sits on a second disk.

### Runners
- **Picking the runner.** A repository variable (second block) holds the runner label, so switching needs no workflow edit. Unset, the job runs on a hosted runner.
- **Forks and Dependabot.** The `runs-on` expression keeps those pull requests on hosted runners, so they never reach this machine.
- **Private repositories only, as GitHub advises.** A pull request from a fork of a public repository can run code on the machine.
- **No sudo in jobs.** System libraries, such as browser dependencies, are installed once by hand. `apt-get` and `--with-deps` steps are guarded with `runner.environment == 'github-hosted'`.
- **Test workers.** Vitest runs with `--maxWorkers=4`, because one worker per CPU thread trips test timeouts in the capped VM.
- **Registration.** Each runner is registered by hand from its repository's Actions settings.

## Gotchas
- **`wsl --shutdown` also kills the keep-alive.** Start the task again afterward.
- **`pkill -f` through a wrapper kills the wrapper.** `pkill -f playwright` inside `wsl.exe` matches the wrapper's own command line. Write `[p]laywright`.
- **The Docker daemon outlives the job.** Clear leftover containers on fixed ports first and remove images in an `if: always()` step.
- **Memory runs out in combination.** A test gate, a concurrent Docker image build, orphaned Vite dev servers and unreturned page cache can exhaust the machine together, so run one heavy WSL job at a time.

## Script
If you have a similar task, here is a script you can try. The script is dry-run by default: nothing is registered until `-Execute` is passed.

```ini
# %UserProfile%\.wslconfig. Applies after `wsl --shutdown`.
# Windows side, set separately: a fixed 40 GB page file on a second disk.
[wsl2]
# Hard cap for the WSL VM: about half of the RAM Windows can see.
memory=14GB
# Swap inside the VM, so a heavy test run slows down instead of being killed.
swap=8GB

[experimental]
# Return page cache to Windows as the VM idles, instead of holding it.
autoMemoryReclaim=gradual
# Hand freed disk blocks back to Windows so the virtual disk stays small.
sparseVhd=true
```

```yaml
# Workflow fragment. Repository variable CI_RUNNER holds the runner label (for example wsl-runner).
# Unset or deleted: the job runs on a GitHub-hosted runner.
# Simple form for a repository with no fork pull requests: runs-on: ${{ vars.CI_RUNNER || 'ubuntu-latest' }}
# Full form below: pull requests from forks and from Dependabot never reach the self-hosted runner.
name: ci
on:
  pull_request:
  workflow_call:

permissions:
  contents: read

jobs:
  test:
    runs-on: ${{ (github.event_name != 'pull_request' || (github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]')) && vars.CI_RUNNER || 'ubuntu-latest' }}
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 24
          cache: npm
      # The runner user has no sudo, so package installs run on hosted runners only.
      - name: Install browser and system libraries
        if: runner.environment == 'github-hosted'
        run: npx playwright install --with-deps chromium
      - run: npm ci
      # Four workers instead of one per CPU thread, to fit the memory-capped VM.
      - run: npm test -- --maxWorkers=4
```

```powershell
<#
.SYNOPSIS
Registers a user-level scheduled task that keeps a WSL distro, and the runner services inside it, running.

.DESCRIPTION
WSL shuts its VM down when no process is attached. This script registers a scheduled task that holds
`sleep infinity` inside the distro through a headless console host, so the VM never counts as idle.
The task starts at logon and again every 5 minutes. A copy that is already running is not doubled
(MultipleInstances IgnoreNew), and the repeat starts a copy that stopped.

DRY RUN BY DEFAULT. Without -Execute the script only prints the task it would register and exits 0.
With -Execute it registers the task for the current user (no elevation, interactive logon) and starts it.
It never touches the distro, the runners, or any other scheduled task. If a task with the same name
already exists, -Execute stops with an error and changes nothing.

`wsl --shutdown` ends the keep-alive. Start the task again afterward:
    Start-ScheduledTask -TaskName 'WSL Runner Keep-Alive'

.PARAMETER Distro
WSL distro name, as listed by `wsl -l -v`. Default: Ubuntu.

.PARAMETER TaskName
Scheduled task name. Default: WSL Runner Keep-Alive.

.PARAMETER LinuxUser
Optional Linux user the keep-alive process runs as. Default: the distro's default user.
Use the unprivileged user that owns the runner services.

.PARAMETER Execute
Register and start the task. Without this switch nothing is changed.

.EXAMPLE
.\Set-WslRunnerKeepAlive.ps1
Dry run: prints the plan and exits 0.

.EXAMPLE
.\Set-WslRunnerKeepAlive.ps1 -Distro Ubuntu-24.04 -LinuxUser runner -Execute
Registers and starts the keep-alive for that distro, running as the user "runner".

.NOTES
Requires PowerShell 7 on Windows.
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Distro = 'Ubuntu',

    [ValidateNotNullOrEmpty()]
    [string]$TaskName = 'WSL Runner Keep-Alive',

    [ValidatePattern('^[a-z_][a-z0-9_-]*$')]
    [string]$LinuxUser,

    [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) { throw 'This script registers a Windows scheduled task and runs on Windows only.' }

$conhost = Join-Path $env:SystemRoot 'System32\conhost.exe'
$wsl     = Join-Path $env:SystemRoot 'System32\wsl.exe'
$wslArgs = @('-d', $Distro)
if ($LinuxUser) { $wslArgs += @('-u', $LinuxUser) }
$wslArgs += @('--exec', '/bin/sleep', 'infinity')
$argument = '--headless {0} {1}' -f $wsl, ($wslArgs -join ' ')
$account  = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

Write-Output ('Mode     : {0}' -f $(if ($Execute) { 'EXECUTE' } else { 'DRY RUN (nothing is registered; pass -Execute to register)' }))
Write-Output "Task     : $TaskName (user $account, interactive logon, no elevation)"
Write-Output "Action   : $conhost $argument"
Write-Output 'Triggers : at logon; then every 5 minutes, indefinitely'
Write-Output 'Settings : never start a second copy; no time limit; start when available; run on battery'
if ($existing) { Write-Output "Existing : a task named '$TaskName' already exists; -Execute would stop and change nothing" }

if (-not $Execute) { exit 0 }

if ($existing) { throw "A task named '$TaskName' already exists. Choose another -TaskName or remove the old task yourself." }

$taskAction = New-ScheduledTaskAction -Execute $conhost -Argument $argument
$triggers   = @(
    New-ScheduledTaskTrigger -AtLogOn -User $account
    New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
)
$settings   = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal  = New-ScheduledTaskPrincipal -UserId $account -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $taskAction -Trigger $triggers -Settings $settings -Principal $principal | Out-Null
Start-ScheduledTask -TaskName $TaskName
Write-Output "Registered and started '$TaskName'. After any wsl --shutdown, run: Start-ScheduledTask -TaskName '$TaskName'"
```
