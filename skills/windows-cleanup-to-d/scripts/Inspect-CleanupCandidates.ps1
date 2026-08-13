param(
    [string[]]$AppNames,
    [switch]$IncludeTemp
)

$ErrorActionPreference = "Continue"

if ($AppNames.Count -eq 0) {
    Write-Warning "No app names supplied. Example: -AppNames WorkBuddy,Codex -IncludeTemp"
    exit 1
}

$roots = @(
    $env:USERPROFILE,
    $env:LOCALAPPDATA,
    $env:APPDATA,
    $env:ProgramData,
    ${env:ProgramFiles(x86)},
    $env:ProgramFiles
)

$tempRoot = $env:LOCALAPPDATA
if ($IncludeTemp) {
    $roots += (Join-Path $tempRoot "Temp")
}

$results = @()

foreach ($app in $AppNames) {
    $pattern = "(?i)(^|[-_.@])" + [regex]::Escape($app) + "|" + [regex]::Escape($app) + "[-_.@]"

    foreach ($root in $roots) {
        if (-not $root -or -not (Test-Path -LiteralPath $root -ErrorAction SilentlyContinue)) {
            continue
        }

        Get-ChildItem -Force -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match $pattern } |
            ForEach-Object {
                $items = Get-ChildItem -Force -LiteralPath $_.FullName -Recurse -File -ErrorAction SilentlyContinue
                $size = ($items | Measure-Object -Property Length -Sum).Sum
                $results += [PSCustomObject]@{
                    App = $app
                    Path = $_.FullName
                    Kind = "Directory"
                    FileCount = $items.Count
                    SizeMB = [math]::Round($size / 1MB, 2)
                    LastWriteTime = $_.LastWriteTime
                }
            }
    }
}

Write-Output "Running processes:"
foreach ($app in $AppNames) {
    Get-Process -Name $app -ErrorAction SilentlyContinue |
        Select-Object ProcessName, Id, Path |
        Format-Table -AutoSize
}

Write-Output "Candidate folders:"
$results | Sort-Object App, SizeMB -Descending | Format-Table -AutoSize

Write-Output "Total candidate bytes:"
Write-Output (($results | Measure-Object -Property SizeMB -Sum).Sum)
