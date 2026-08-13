---
name: windows-cleanup-to-d
description: 'Windows 电脑 C 盘清理、软件数据迁移的完整流程。Use when the user asks to clean the C drive, continue a previous cleanup, move app data/installers/logs to another drive or folder, migrate software default storage paths, back up software before uninstall, or inspect C drive leftovers.'
---

# Windows Cleanup and Data Migration

## Goal

Audit C drive leftovers safely, move reusable files to a chosen destination, and verify applications still work after migration. Prefer moving to `<DestinationRoot>\<App>\OldFromC` over deleting unless the user explicitly approves deletion.

## Workflow

1. Confirm the destination root with the user, for example `D:\xie` or another drive. Store it in `$destinationRoot`.
2. Inventory first.
   - Run the read-only scan for target apps:
     ```powershell
     & "$env:CODEX_HOME\skills\windows-cleanup-to-d\scripts\Inspect-CleanupCandidates.ps1" -AppNames <app1>,<app2> -IncludeTemp
     ```
   - If `CODEX_HOME` is unset, read the skill from the active Codex home and adjust the path.
   - List running processes with `Get-Process` before moving anything.
3. Categorize each found item.
   - Safe to move: installers, empty directories, old logs, crash reports, obsolete temp files.
   - Move with backup: app config, user data, session data, project files.
   - Do not move: active program installation directories, active temp directories, system folders, unrelated user files.
4. Create the destination folder before moving:
   ```powershell
   New-Item -ItemType Directory -Force -Path "$destinationRoot\WorkBuddy\OldFromC"
   ```
5. Move with `Move-Item` and `-LiteralPath`; use the full resolved path for every source and destination.
6. Verify after each batch:
   - source no longer exists or is empty,
   - destination contains the expected files,
   - target application still runs from its configured path,
   - environment variables were written for the real user.
7. Report exactly what was moved, how much space it occupied, and what still remains.

## Safety Rules

- Never run destructive deletion commands unless the user explicitly confirms.
- Do not move or rename an active app data directory while the app is running.
- Do not move running temp directories; wait until the app is closed.
- Keep the old directory as a backup until the new location is verified.
- Do not modify user files unrelated to the cleanup request.
- Use `-LiteralPath` for paths with dots, spaces, or special characters.
- Use the real Windows user context for registry and environment checks; `whoami` may show a sandbox user in the default shell.
- Verify any recursive target path stays inside the intended destination before moving or deleting.

## Migration Patterns

See [cleanup-patterns.md](references/cleanup-patterns.md) for reusable PowerShell patterns, including `CODEX_HOME` migration, app data relocation, and real-user environment variable checks.
