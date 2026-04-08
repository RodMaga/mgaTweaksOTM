[CmdletBinding()]
param(
    [switch]$SkipPowerTweaks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-RegistryValueSafe {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not (Test-Path -Path $Path)) {
        return [pscustomobject]@{
            Exists = $false
            Kind   = $null
            Value  = $null
        }
    }

    $item = Get-Item -Path $Path
    $kind = $null
    if ($item.Property -contains $Name) {
        $kind = $item.GetValueKind($Name).ToString()
        $value = (Get-ItemProperty -Path $Path -Name $Name).$Name
        return [pscustomobject]@{
            Exists = $true
            Kind   = $kind
            Value  = $value
        }
    }

    return [pscustomobject]@{
        Exists = $false
        Kind   = $null
        Value  = $null
    }
}

function Set-RegistryValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Type
    )

    New-Item -Path $Path -Force | Out-Null
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Get-PowerSettingIndex {
    param(
        [Parameter(Mandatory = $true)][string]$Output,
        [Parameter(Mandatory = $true)][string]$Mode
    )

    $regex = if ($Mode -eq 'AC') {
        'Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)'
    }
    else {
        'Current DC Power Setting Index:\s+0x([0-9a-fA-F]+)'
    }

    $match = [regex]::Match($Output, $regex)
    if ($match.Success) {
        return [Convert]::ToInt32($match.Groups[1].Value, 16)
    }

    return $null
}

if (-not (Test-IsAdmin)) {
    throw 'Execute este script como Administrador.'
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$backupDir = Join-Path $projectRoot 'backups\input-lag-keyboard'
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupFile = Join-Path $backupDir ("keyboard_input_lag_backup_{0}.json" -f $timestamp)

$registryTweaks = @(
    @{ Path = 'HKCU:\Control Panel\Keyboard'; Name = 'KeyboardDelay'; Type = 'String'; Value = '0'; Reason = 'Menor atraso antes de repetir tecla' },
    @{ Path = 'HKCU:\Control Panel\Keyboard'; Name = 'KeyboardSpeed'; Type = 'String'; Value = '31'; Reason = 'Maior taxa de repeticao de tecla' },
    @{ Path = 'HKCU:\Control Panel\Accessibility\StickyKeys'; Name = 'Flags'; Type = 'String'; Value = '506'; Reason = 'Desativa Sticky Keys sem popup' },
    @{ Path = 'HKCU:\Control Panel\Accessibility\ToggleKeys'; Name = 'Flags'; Type = 'String'; Value = '58'; Reason = 'Desativa Toggle Keys sem popup' },
    @{ Path = 'HKCU:\Control Panel\Accessibility\Keyboard Response'; Name = 'Flags'; Type = 'String'; Value = '122'; Reason = 'Desativa Filter Keys e atrasos' },
    @{ Path = 'HKCU:\Control Panel\Accessibility\Keyboard Response'; Name = 'AutoRepeatDelay'; Type = 'String'; Value = '0'; Reason = 'Sem atraso adicional de repeticao' },
    @{ Path = 'HKCU:\Control Panel\Accessibility\Keyboard Response'; Name = 'AutoRepeatRate'; Type = 'String'; Value = '0'; Reason = 'Sem limitacao adicional da repeticao' },
    @{ Path = 'HKCU:\Control Panel\Accessibility\Keyboard Response'; Name = 'DelayBeforeAcceptance'; Type = 'String'; Value = '0'; Reason = 'Aceita teclas imediatamente' },
    @{ Path = 'HKCU:\Control Panel\Accessibility\Keyboard Response'; Name = 'BounceTime'; Type = 'String'; Value = '0'; Reason = 'Sem bloqueio anti-bounce do Windows' },
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters'; Name = 'KeyboardDataQueueSize'; Type = 'DWord'; Value = 120; Reason = 'Fila maior para reduzir drops em carga alta' }
)

$backup = [ordered]@{
    CreatedAt = (Get-Date).ToString('o')
    Registry  = @()
    Power     = [ordered]@{
        Applied = $false
        ACValue = $null
        DCValue = $null
    }
}

foreach ($tweak in $registryTweaks) {
    $current = Get-RegistryValueSafe -Path $tweak.Path -Name $tweak.Name
    $backup.Registry += [pscustomobject]@{
        Path   = $tweak.Path
        Name   = $tweak.Name
        Exists = $current.Exists
        Kind   = $current.Kind
        Value  = $current.Value
    }

    Set-RegistryValue -Path $tweak.Path -Name $tweak.Name -Value $tweak.Value -Type $tweak.Type
    Write-Host ("[OK] {0} -> {1} ({2})" -f $tweak.Name, $tweak.Value, $tweak.Reason) -ForegroundColor Green
}

if (-not $SkipPowerTweaks) {
    $subUsb = '2a737441-1930-4402-8d77-b2bebba308a3'
    $usbSelectiveSuspend = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'

    $powerQuery = powercfg /Q SCHEME_CURRENT $subUsb $usbSelectiveSuspend | Out-String
    $acValue = Get-PowerSettingIndex -Output $powerQuery -Mode 'AC'
    $dcValue = Get-PowerSettingIndex -Output $powerQuery -Mode 'DC'

    $backup.Power.Applied = $true
    $backup.Power.ACValue = $acValue
    $backup.Power.DCValue = $dcValue

    powercfg /SETACVALUEINDEX SCHEME_CURRENT $subUsb $usbSelectiveSuspend 0 | Out-Null
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT $subUsb $usbSelectiveSuspend 0 | Out-Null
    powercfg /SETACTIVE SCHEME_CURRENT | Out-Null

    Write-Host '[OK] USB Selective Suspend desativado (AC/DC).' -ForegroundColor Green
}

$backup | ConvertTo-Json -Depth 6 | Set-Content -Path $backupFile -Encoding UTF8

Write-Host ''
Write-Host 'Tweaks aplicados com sucesso.' -ForegroundColor Cyan
Write-Host ("Backup salvo em: {0}" -f $backupFile) -ForegroundColor Yellow
Write-Host 'Reinicie o PC para garantir que tudo foi aplicado.' -ForegroundColor Yellow
