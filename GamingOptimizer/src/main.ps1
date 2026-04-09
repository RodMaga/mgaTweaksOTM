Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Path $PSScriptRoot -Parent

. (Join-Path $projectRoot 'src\utils\Elevate.ps1')
. (Join-Path $projectRoot 'src\gui\gui_handler.ps1')

Ensure-Admin -ScriptPath $MyInvocation.MyCommand.Path
Launch-GamingOptimizerUtility
