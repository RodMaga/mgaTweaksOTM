Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$entryPoint = Join-Path $projectRoot 'src\main.ps1'

if (-not (Test-Path -Path $entryPoint)) {
	throw "Entry point not found: $entryPoint"
}

& $entryPoint
