# Cleanup Patterns

## Real User Checks

The default shell may run under a sandbox user. Before changing or reading user environment variables:

```powershell
whoami
reg query 'HKCU\Environment' /v CODEX_HOME
```

Run registry or environment writes through an approved real-user command. Verify the value after writing:

```powershell
$destinationRoot = 'D:\xie' # Replace with the user's chosen destination
$newCodexHome = Join-Path $destinationRoot 'CodexHome'
[Environment]::SetEnvironmentVariable('CODEX_HOME', $newCodexHome, 'User')
[Environment]::GetEnvironmentVariable('CODEX_HOME', 'User')
```

## App Data Relocation

Use this pattern for old logs, installers, crash reports, and other movable app leftovers:

```powershell
$destinationRoot = 'D:\xie' # Replace with the user's chosen destination
$appName = 'WorkBuddy'      # Replace with the target app
$dest = Join-Path $destinationRoot "$appName\OldFromC"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$source = Join-Path $env:LOCALAPPDATA $appName
Move-Item -LiteralPath $source -Destination (Join-Path $dest $appName) -Force
```

Do not move active app folders. Close the app first when the folder is in use.

## CODEX_HOME Migration

1. Confirm current state:
   ```powershell
   $destinationRoot = 'D:\xie' # Replace with the user's chosen destination
   Write-Output "CODEX_HOME=$env:CODEX_HOME"
   Get-ChildItem -Force -LiteralPath (Join-Path $env:USERPROFILE '.codex')
   ```
2. Copy, do not cut, the old `.codex` directory to the new home:
   ```powershell
   $oldCodexHome = Join-Path $env:USERPROFILE '.codex'
   $newCodexHome = Join-Path $destinationRoot 'CodexHome'
   robocopy $oldCodexHome $newCodexHome /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NP
   ```
3. Set the user environment variable:
   ```powershell
   setx CODEX_HOME $newCodexHome
   ```
4. Fully restart Codex.
5. Verify sessions, auth, config, and skills still work.
6. Only after verification, rename or move the old C directory as backup.

## File Categories

- Installer and updater files: safe to move; usually large.
- Logs and crash reports: safe to move or delete after checking that no active app needs them.
- Empty directories: safe to move; do not waste time on them alone.
- Config, auth, sessions, projects, and work files: move only with a backup and verification step.
- Active temp directories: leave in place until the owning app is closed.
- Installed program directories: do not move; uninstall and reinstall if relocation is required.

## Verification Checklist

- Source path no longer exists or is empty.
- Destination contains expected files and correct size.
- Target app still runs.
- Environment variable is visible for the real Windows user.
- User confirmed the moved data is accessible before the old copy is removed.
