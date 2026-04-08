$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $scriptDir "..\GamingOptimizer\web-guide\Start-LocalGuide.ps1"

if (-not (Test-Path $target)) {
  throw "Target script not found: $target"
}

& $target @args
