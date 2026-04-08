param(
  [int]$Port = 8080,
  [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"
$target = Join-Path $PSScriptRoot "web-guide\Start-LocalGuide.ps1"

if (-not (Test-Path $target)) {
  throw "Launcher target not found: $target"
}

& $target -Port $Port -NoBrowser:$NoBrowser
