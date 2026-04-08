[CmdletBinding()]
param(
    [string]$BackupFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restore-RegistryValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Exists,
        [Parameter()][string]$Kind,
        [Parameter()]$Value
    )

    New-Item -Path $Path -Force | Out-Null

    if (-not $Exists) {
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        Write-Host ("[OK] {0} removido (nao existia originalmente)." -f $Name) -ForegroundColor Green
        return
    }

    if ([string]::IsNullOrWhiteSpace($Kind)) {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value
    }
    else {
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Kind -Force | Out-Null
    }

    Write-Host ("[OK] {0} restaurado para {1}." -f $Name, $Value) -ForegroundColor Green
}

if (-not (Test-IsAdmin)) {
    throw 'Execute este script como Administrador.'
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$backupDir = Join-Path $projectRoot 'backups\input-lag-keyboard'

if (-not $BackupFile) {
    $latest = Get-ChildItem -Path $backupDir -Filter 'keyboard_input_lag_backup_*.json' -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latest) {
        throw 'Nenhum backup encontrado para restaurar.'
    }

    $BackupFile = $latest.FullName
}

if (-not (Test-Path -Path $BackupFile)) {
    throw ("Backup nao encontrado: {0}" -f $BackupFile)
}

$backup = Get-Content -Path $BackupFile -Raw | ConvertFrom-Json

foreach ($entry in $backup.Registry) {
    Restore-RegistryValue -Path $entry.Path -Name $entry.Name -Exists ([bool]$entry.Exists) -Kind $entry.Kind -Value $entry.Value
}

if ($backup.Power -and $backup.Power.Applied) {
    $subUsb = '2a737441-1930-4402-8d77-b2bebba308a3'
    $usbSelectiveSuspend = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'

    if ($null -ne $backup.Power.ACValue) {
        powercfg /SETACVALUEINDEX SCHEME_CURRENT $subUsb $usbSelectiveSuspend $backup.Power.ACValue | Out-Null
    }

    if ($null -ne $backup.Power.DCValue) {
        powercfg /SETDCVALUEINDEX SCHEME_CURRENT $subUsb $usbSelectiveSuspend $backup.Power.DCValue | Out-Null
    }

    powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
    Write-Host '[OK] USB Selective Suspend restaurado.' -ForegroundColor Green
}

Write-Host ''
Write-Host ("Restore concluido a partir de: {0}" -f $BackupFile) -ForegroundColor Cyan
Write-Host 'Reinicie o PC para garantir rollback completo.' -ForegroundColor Yellow
