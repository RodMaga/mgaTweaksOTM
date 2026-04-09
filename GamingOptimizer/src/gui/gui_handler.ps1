Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Launch-GamingOptimizerUtility {
	Add-Type -AssemblyName PresentationCore
	Add-Type -AssemblyName PresentationFramework
	Add-Type -AssemblyName WindowsBase

	$script:ProjectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
	. (Join-Path $script:ProjectRoot 'src\utils\RestorePoint.ps1')

	$xamlPath = Join-Path $PSScriptRoot 'MainWindow.xaml'
	[xml]$xaml = Get-Content -Path $xamlPath -Raw
	$reader = New-Object System.Xml.XmlNodeReader $xaml
	$window = [Windows.Markup.XamlReader]::Load($reader)

	$txtLog = $window.FindName('TxtLog')
	$btnApply = $window.FindName('BtnApply')
	$btnRollbackAll = $window.FindName('BtnRollbackAll')
	$cmbProfile = $window.FindName('CmbProfile')
	$btnApplyProfile = $window.FindName('BtnApplyProfile')
	$btnExportPreset = $window.FindName('BtnExportPreset')
	$btnImportPreset = $window.FindName('BtnImportPreset')
	$cmbCategoryFilter = $window.FindName('CmbCategoryFilter')
	$cmbRiskFilter = $window.FindName('CmbRiskFilter')
	$txtSearchFilter = $window.FindName('TxtSearchFilter')
	$btnApplyFilters = $window.FindName('BtnApplyFilters')
	$btnClearFilters = $window.FindName('BtnClearFilters')
	$pnlTweaks = $window.FindName('PnlTweaks')
	$btnRefreshServices = $window.FindName('BtnRefreshServices')
	$btnDisableSelectedServices = $window.FindName('BtnDisableSelectedServices')
	$btnManualSelectedServices = $window.FindName('BtnManualSelectedServices')
	$pnlServices = $window.FindName('PnlServices')
	$chkCreateRestorePoint = $window.FindName('ChkCreateRestorePoint')
	$btnInstallProcessLasso = $window.FindName('BtnInstallProcessLasso')
	$btnOpenProcessLasso = $window.FindName('BtnOpenProcessLasso')
	$btnInstallISLC = $window.FindName('BtnInstallISLC')
	$btnOpenISLC = $window.FindName('BtnOpenISLC')
	$btnApplyTimer05 = $window.FindName('BtnApplyTimer05')
	$btnApplyTimer1 = $window.FindName('BtnApplyTimer1')
	$btnInstallAfterburner = $window.FindName('BtnInstallAfterburner')
	$btnInstallHWMonitor = $window.FindName('BtnInstallHWMonitor')
	$btnGenerateAutoToolProfiles = $window.FindName('BtnGenerateAutoToolProfiles')
	$btnOpenAutoProfilesFolder = $window.FindName('BtnOpenAutoProfilesFolder')
	$btnApplyAutoToolProfile = $window.FindName('BtnApplyAutoToolProfile')

	$tweakControls = @{}
	$tweakCatalog = @()
	$catalogById = @{}
	$tweakSelection = @{}

	$serviceTargets = @(
		'DiagTrack',
		'SysMain',
		'WSearch',
		'XblAuthManager',
		'XblGameSave',
		'XboxGipSvc'
	)

	function Write-Log {
		param([string]$Message)

		$timestamp = Get-Date -Format 'HH:mm:ss'
		$line = "[$timestamp] $Message"
		$txtLog.AppendText($line + [Environment]::NewLine)
		$txtLog.ScrollToEnd()
	}

	function Get-RiskLabel {
		param([string]$Risk)
		$riskValue = if ($null -eq $Risk) { '' } else { $Risk }
		switch ($riskValue.ToLowerInvariant()) {
			'high' { return 'High' }
			'medium' { return 'Medium' }
			default { return 'Low' }
		}
	}

	function Get-RegistryValueSafe {
		param(
			[Parameter(Mandatory = $true)][string]$Path,
			[Parameter(Mandatory = $true)][string]$Name
		)

		if (-not (Test-Path -Path $Path)) {
			return [pscustomobject]@{ Exists = $false; Kind = $null; Value = $null }
		}

		$item = Get-Item -Path $Path
		if ($item.Property -contains $Name) {
			$kind = $item.GetValueKind($Name).ToString()
			$value = (Get-ItemProperty -Path $Path -Name $Name).$Name
			return [pscustomobject]@{ Exists = $true; Kind = $kind; Value = $value }
		}

		return [pscustomobject]@{ Exists = $false; Kind = $null; Value = $null }
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
			return
		}

		if ([string]::IsNullOrWhiteSpace($Kind)) {
			Set-ItemProperty -Path $Path -Name $Name -Value $Value
		}
		else {
			New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Kind -Force | Out-Null
		}
	}

	function New-ApplyBackup {
		return [ordered]@{
			CreatedAt       = (Get-Date).ToString('o')
			AppliedTweaks   = @()
			KeyboardApplied = $false
			Registry        = @()
			Power           = [ordered]@{
				HadValue   = $false
				ActiveGuid = $null
			}
		}
	}

	function Backup-RegistryEntry {
		param(
			[Parameter(Mandatory = $true)]$Backup,
			[Parameter(Mandatory = $true)][hashtable]$Seen,
			[Parameter(Mandatory = $true)][string]$Path,
			[Parameter(Mandatory = $true)][string]$Name
		)

		$key = "$Path|$Name"
		if ($Seen.ContainsKey($key)) {
			return
		}

		$current = Get-RegistryValueSafe -Path $Path -Name $Name
		$Backup.Registry += [pscustomobject]@{
			Path   = $Path
			Name   = $Name
			Exists = $current.Exists
			Kind   = $current.Kind
			Value  = $current.Value
		}
		$Seen[$key] = $true
	}

	function Get-ActivePowerSchemeGuid {
		$output = (powercfg /GetActiveScheme) | Out-String
		$match = [regex]::Match($output, '([0-9a-fA-F\-]{36})')
		if ($match.Success) {
			return $match.Groups[1].Value
		}

		return $null
	}

	function Test-BackupHasData {
		param([Parameter(Mandatory = $true)]$Backup)
		return ($Backup.AppliedTweaks.Count -gt 0 -or $Backup.KeyboardApplied -or $Backup.Registry.Count -gt 0 -or $Backup.Power.HadValue)
	}

	function Save-ApplyBackup {
		param([Parameter(Mandatory = $true)]$Backup)

		$backupDir = Join-Path $script:ProjectRoot 'backups\gui-global'
		New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

		$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
		$filePath = Join-Path $backupDir ("gui_apply_backup_{0}.json" -f $timestamp)
		$Backup | ConvertTo-Json -Depth 8 | Set-Content -Path $filePath -Encoding UTF8
		return $filePath
	}

	function Get-LatestApplyBackupFile {
		$backupDir = Join-Path $script:ProjectRoot 'backups\gui-global'
		if (-not (Test-Path -Path $backupDir)) {
			return $null
		}

		$latest = Get-ChildItem -Path $backupDir -Filter 'gui_apply_backup_*.json' -File |
			Sort-Object LastWriteTime -Descending |
			Select-Object -First 1

		if (-not $latest) {
			return $null
		}

		return $latest.FullName
	}

	function Invoke-KeyboardInputLagApply {
		$scriptPath = Join-Path $script:ProjectRoot 'tweaks\keyboard_input_lag\Apply-KeyboardInputLagTweaks.ps1'
		if (-not (Test-Path -Path $scriptPath)) {
			throw "Keyboard tweak script not found: $scriptPath"
		}
		& $scriptPath
	}

	function Invoke-KeyboardInputLagRestore {
		$scriptPath = Join-Path $script:ProjectRoot 'tweaks\keyboard_input_lag\Revert-KeyboardInputLagTweaks.ps1'
		if (-not (Test-Path -Path $scriptPath)) {
			throw "Keyboard revert script not found: $scriptPath"
		}
		& $scriptPath
	}

	function Set-GameBarDisabled {
		New-Item -Path 'HKCU:\SOFTWARE\Microsoft\GameBar' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\GameBar' -Name 'ShowStartupPanel' -Value 0 -PropertyType DWord -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value 1 -PropertyType DWord -Force | Out-Null
		New-Item -Path 'HKCU:\System\GameConfigStore' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0 -PropertyType DWord -Force | Out-Null
		New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0 -PropertyType DWord -Force | Out-Null
	}

	function Set-UltimatePerformancePlan {
		$ultimateGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
		$existingPlans = (powercfg /L) | Out-String
		if ($existingPlans -notmatch $ultimateGuid) {
			powercfg -duplicatescheme $ultimateGuid | Out-Null
		}
		powercfg -setactive $ultimateGuid | Out-Null
	}

	function Set-NetworkLatencyProfile {
		$basePath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
		New-Item -Path $basePath -Force | Out-Null
		New-ItemProperty -Path $basePath -Name 'NetworkThrottlingIndex' -Value 0xffffffff -PropertyType DWord -Force | Out-Null
		New-ItemProperty -Path $basePath -Name 'SystemResponsiveness' -Value 0 -PropertyType DWord -Force | Out-Null
	}

	function Set-MouseAccelerationDisabled {
		New-Item -Path 'HKCU:\Control Panel\Mouse' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed' -Value '0' -PropertyType String -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold1' -Value '0' -PropertyType String -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold2' -Value '0' -PropertyType String -Force | Out-Null
	}

	function Set-HardwareSchedulingEnabled {
		New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -Value 2 -PropertyType DWord -Force | Out-Null
	}

	function Set-HibernationDisabled {
		powercfg -h off | Out-Null
	}

	function Set-StartupDelayDisabled {
		New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name 'StartupDelayInMSec' -Value 0 -PropertyType DWord -Force | Out-Null
	}

	function Set-TransparencyDisabled {
		New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0 -PropertyType DWord -Force | Out-Null
	}

	function Set-PowerThrottlingDisabled {
		New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -Name 'PowerThrottlingOff' -Value 1 -PropertyType DWord -Force | Out-Null
	}

	function Set-DeliveryOptimizationDisabled {
		New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' -Name 'DODownloadMode' -Value 0 -PropertyType DWord -Force | Out-Null
	}

	function Set-BackgroundAppsLimited {
		New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled' -Value 1 -PropertyType DWord -Force | Out-Null
	}

	function Set-ActivityHistoryDisabled {
		New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'EnableActivityFeed' -Value 0 -PropertyType DWord -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'PublishUserActivities' -Value 0 -PropertyType DWord -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'UploadUserActivities' -Value 0 -PropertyType DWord -Force | Out-Null
	}

	function Set-ConsumerFeaturesDisabled {
		New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures' -Value 1 -PropertyType DWord -Force | Out-Null
	}

	function Set-LocationTrackingDisabled {
		New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' -Name 'Value' -Value 'Deny' -PropertyType String -Force | Out-Null
		New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation' -Value 1 -PropertyType DWord -Force | Out-Null
	}

	function Set-TelemetryDisabled {
		New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -PropertyType DWord -Force | Out-Null
	}

	function Set-TaskbarEndTaskEnabled {
		New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Name 'TaskbarEndTask' -Value 1 -PropertyType DWord -Force | Out-Null
	}

	function Set-WidgetsDisabled {
		New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa' -Value 0 -PropertyType DWord -Force | Out-Null
		New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests' -Value 0 -PropertyType DWord -Force | Out-Null
	}

	function Invoke-DeleteTempFiles {
		$targets = @($env:TEMP, "$env:WINDIR\Temp")
		foreach ($path in $targets) {
			if (Test-Path -Path $path) {
				Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
					Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
			}
		}
	}

	function Invoke-DiskCleanup {
		Start-Process cleanmgr.exe -ArgumentList '/verylowdisk' -Wait
	}

	function Set-FullscreenOptimizationsDisabled {
		New-Item -Path 'HKCU:\System\GameConfigStore' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_FSEBehaviorMode' -Value 2 -PropertyType DWord -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_HonorUserFSEBehaviorMode' -Value 1 -PropertyType DWord -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_DXGIHonorFSEWindowsCompatible' -Value 1 -PropertyType DWord -Force | Out-Null
	}

	function Set-IPv6Disabled {
		New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisabledComponents' -Value 255 -PropertyType DWord -Force | Out-Null
	}

	function Set-PreferIPv4OverIPv6 {
		New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisabledComponents' -Value 32 -PropertyType DWord -Force | Out-Null
	}

	function Set-CopilotDisabled {
		New-Item -Path 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1 -PropertyType DWord -Force | Out-Null
	}

	function Set-StorageSenseDisabled {
		New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' -Name '01' -Value 0 -PropertyType DWord -Force | Out-Null
	}

	function Set-TeredoDisabled {
		netsh interface teredo set state disabled | Out-Null
	}

	function Set-ClassicContextMenu {
		$path = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
		New-Item -Path $path -Force | Out-Null
		Set-ItemProperty -Path $path -Name '(default)' -Value ''
	}

	function Set-VisualEffectsBestPerformance {
		New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2 -PropertyType DWord -Force | Out-Null
	}

	function Set-UTCDualBoot {
		New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Name 'RealTimeIsUniversal' -Value 1 -PropertyType DWord -Force | Out-Null
	}

	function Disable-CPUCoresParking {
		$subProcessor = '54533251-82be-4824-96c1-47b60b740d00'
		$coreParkingMin = '0cc5b647-c1df-4637-891a-dec35c318583'
		$coreParkingMax = 'ea062031-0e34-4ff1-9b6d-eb1059334028'

		powercfg -setacvalueindex SCHEME_CURRENT $subProcessor $coreParkingMin 100 | Out-Null
		powercfg -setdcvalueindex SCHEME_CURRENT $subProcessor $coreParkingMin 100 | Out-Null
		powercfg -setacvalueindex SCHEME_CURRENT $subProcessor $coreParkingMax 100 | Out-Null
		powercfg -setdcvalueindex SCHEME_CURRENT $subProcessor $coreParkingMax 100 | Out-Null
		powercfg -setactive SCHEME_CURRENT | Out-Null
	}

	function Disable-DynamicTick {
		bcdedit /set disabledynamictick yes | Out-Null
	}

	function Disable-HPET {
		bcdedit /set useplatformclock false | Out-Null
	}

	function Set-SystemTimerResolution {
		param([Parameter(Mandatory = $true)][ValidateSet(500, 1000)][int]$Microseconds)

		if (-not ('GamingOptimizer.NativeTimerResolution' -as [type])) {
			Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace GamingOptimizer {
    public static class NativeTimerResolution {
        [DllImport("ntdll.dll")]
        public static extern int NtSetTimerResolution(uint DesiredResolution, bool Set, out uint CurrentResolution);
    }
}
"@
		}

		$desired = [uint32]($Microseconds * 10)
		$current = [uint32]0
		$status = [GamingOptimizer.NativeTimerResolution]::NtSetTimerResolution($desired, $true, [ref]$current)
		if ($status -ne 0) {
			throw "NtSetTimerResolution failed with status code $status"
		}
	}

	function Set-PciInterruptAffinityGpuNic {
		param(
			[Parameter(Mandatory = $true)]$Backup,
			[Parameter(Mandatory = $true)][hashtable]$BackupSeen
		)

		$targetClassGuids = @(
			'{4d36e968-e325-11ce-bfc1-08002be10318}',
			'{4d36e972-e325-11ce-bfc1-08002be10318}'
		)

		$instances = Get-ChildItem -Path 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -Recurse -ErrorAction SilentlyContinue
		foreach ($instance in $instances) {
			$classGuid = (Get-ItemProperty -Path $instance.PSPath -Name 'ClassGUID' -ErrorAction SilentlyContinue).ClassGUID
			if (-not $classGuid) {
				continue
			}

			if (-not ($targetClassGuids -contains ([string]$classGuid).ToLowerInvariant())) {
				continue
			}

			$policyPath = Join-Path $instance.PSPath 'Device Parameters\Interrupt Management\Affinity Policy'
			Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path $policyPath -Name 'DevicePolicy'
			New-Item -Path $policyPath -Force | Out-Null
			New-ItemProperty -Path $policyPath -Name 'DevicePolicy' -Value 2 -PropertyType DWord -Force | Out-Null
		}
	}

	function Set-GpuMsiModeEnabled {
		param(
			[Parameter(Mandatory = $true)]$Backup,
			[Parameter(Mandatory = $true)][hashtable]$BackupSeen
		)

		$displayClassGuid = '{4d36e968-e325-11ce-bfc1-08002be10318}'
		$instances = Get-ChildItem -Path 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -Recurse -ErrorAction SilentlyContinue
		foreach ($instance in $instances) {
			$classGuid = (Get-ItemProperty -Path $instance.PSPath -Name 'ClassGUID' -ErrorAction SilentlyContinue).ClassGUID
			if (-not $classGuid -or ([string]$classGuid).ToLowerInvariant() -ne $displayClassGuid) {
				continue
			}

			$msiPath = Join-Path $instance.PSPath 'Device Parameters\Interrupt Management\MessageSignaledInterruptProperties'
			Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path $msiPath -Name 'MSISupported'
			New-Item -Path $msiPath -Force | Out-Null
			New-ItemProperty -Path $msiPath -Name 'MSISupported' -Value 1 -PropertyType DWord -Force | Out-Null
		}
	}

	function Set-PcieLinkStatePowerManagementDisabled {
		$subgroupPcie = '501a4d13-42af-4429-9fd1-a8218c268e20'
		$linkStateSetting = 'ee12f906-d277-404b-b6da-e5fa1a576df5'

		powercfg -setacvalueindex SCHEME_CURRENT $subgroupPcie $linkStateSetting 0 | Out-Null
		powercfg -setdcvalueindex SCHEME_CURRENT $subgroupPcie $linkStateSetting 0 | Out-Null
		powercfg -setactive SCHEME_CURRENT | Out-Null
	}

	function Set-TcpAckFrequencyOnly {
		$interfacesPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
		if (-not (Test-Path -Path $interfacesPath)) {
			return
		}

		$interfaces = Get-ChildItem -Path $interfacesPath -ErrorAction SilentlyContinue
		foreach ($iface in $interfaces) {
			New-ItemProperty -Path $iface.PSPath -Name 'TcpAckFrequency' -Value 1 -PropertyType DWord -Force | Out-Null
		}
	}

	function Set-QoSPacketSchedulerDisabled {
		$adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
		foreach ($adapter in $adapters) {
			Disable-NetAdapterBinding -Name $adapter.Name -ComponentID 'ms_pacer' -ErrorAction SilentlyContinue | Out-Null
		}
	}

	function Clear-StandbyMemoryList {
		if (-not ('GamingOptimizer.NativeMemoryList' -as [type])) {
			Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace GamingOptimizer {
    public static class NativeMemoryList {
        [DllImport("ntdll.dll")]
        public static extern int NtSetSystemInformation(int SystemInformationClass, ref int SystemInformation, int SystemInformationLength);
    }
}
"@
		}

		$memoryPurgeStandbyList = 4
		$systemMemoryListInformation = 80
		$status = [GamingOptimizer.NativeMemoryList]::NtSetSystemInformation($systemMemoryListInformation, [ref]$memoryPurgeStandbyList, 4)
		if ($status -ne 0) {
			throw "NtSetSystemInformation failed with status code $status"
		}
	}

	function Set-UsbPollingOptimization {
		Set-DisableUsbPowerSaving

		$usbInstances = Get-ChildItem -Path 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB' -Recurse -ErrorAction SilentlyContinue
		foreach ($instance in $usbInstances) {
			$deviceParamPath = Join-Path $instance.PSPath 'Device Parameters'
			if (-not (Test-Path -Path $deviceParamPath)) {
				continue
			}

			New-ItemProperty -Path $deviceParamPath -Name 'EnhancedPowerManagementEnabled' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
		}
	}

	function Set-GameProcessPriorityAutoHigh {
		$gameExecutables = @(
			'cs2.exe',
			'valorant.exe',
			'fortniteclient-win64-shipping.exe',
			'cod.exe',
			'apexlegends.exe',
			'r5apex.exe',
			'overwatch.exe',
			'leagueoflegends.exe',
			'dota2.exe',
			'rocketleague.exe'
		)

		foreach ($exe in $gameExecutables) {
			$path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions"
			New-Item -Path $path -Force | Out-Null
			New-ItemProperty -Path $path -Name 'CpuPriorityClass' -Value 3 -PropertyType DWord -Force | Out-Null
		}
	}

	function Set-BcdUsePlatformTickEnabled {
		bcdedit /set useplatformtick yes | Out-Null
	}

	function Set-BcdTscSyncPolicyEnhanced {
		bcdedit /set tscsyncpolicy Enhanced | Out-Null
	}

	function Open-ToolUrl {
		param([Parameter(Mandatory = $true)][string]$Url)
		Start-Process $Url
	}

	function Install-ToolWithWinget {
		param(
			[Parameter(Mandatory = $true)][string]$ToolName,
			[Parameter(Mandatory = $true)][string]$PackageId,
			[Parameter(Mandatory = $true)][string]$FallbackUrl
		)

		$winget = Get-Command -Name winget.exe -ErrorAction SilentlyContinue
		if (-not $winget) {
			Write-Log ("winget not found. Opening website for {0}." -f $ToolName)
			Open-ToolUrl -Url $FallbackUrl
			return
		}

		$arguments = @(
			'install',
			'--id', $PackageId,
			'--exact',
			'--accept-package-agreements',
			'--accept-source-agreements'
		)

		$process = Start-Process -FilePath 'winget.exe' -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
		if ($process.ExitCode -eq 0) {
			Write-Log ("Installed: {0} ({1})" -f $ToolName, $PackageId)
		}
		else {
			Write-Log ("winget failed for {0} (exit {1}). Opening website." -f $ToolName, $process.ExitCode)
			Open-ToolUrl -Url $FallbackUrl
		}
	}

	function Get-ExternalProfilesDirectory {
		$dir = Join-Path $script:ProjectRoot 'src\profiles\external_tools'
		New-Item -Path $dir -ItemType Directory -Force | Out-Null
		return $dir
	}

	function Get-HardwareProfileSnapshot {
		$cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
		$comp = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
		$gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
		$nics = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Disabled' }
		$disks = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue
		$hid = Get-PnpDevice -Class HIDClass -Status OK -ErrorAction SilentlyContinue

		$ramBytes = if ($comp -and $comp.TotalPhysicalMemory) { [int64]$comp.TotalPhysicalMemory } else { 0 }
		$ramGb = [math]::Round($ramBytes / 1GB, 1)

		$storageType = 'Unknown'
		if ($disks) {
			if ($disks | Where-Object { $_.Model -match 'NVMe' -or $_.MediaType -match 'SSD' }) {
				$storageType = 'NVMe/SSD'
			}
			elseif ($disks | Where-Object { $_.MediaType -match 'SSD' }) {
				$storageType = 'SSD'
			}
			else {
				$storageType = 'HDD/Mixed'
			}
		}

		$gpuVendor = 'Unknown'
		$gpuName = if ($gpu) { [string](($gpu | Select-Object -First 1).Name) } else { 'Unknown' }
		if ($gpuName -match 'NVIDIA') { $gpuVendor = 'NVIDIA' }
		elseif ($gpuName -match 'AMD|Radeon') { $gpuVendor = 'AMD' }
		elseif ($gpuName -match 'Intel') { $gpuVendor = 'Intel' }

		$fastNic = $false
		if ($nics) {
			$fastNic = $nics | Where-Object { $_.LinkSpeed -match '([2-9]\d*\s*Gbps|1\s*Gbps)' } | Select-Object -First 1
			$fastNic = $null -ne $fastNic
		}

		return [ordered]@{
			generatedAt = (Get-Date).ToString('o')
			cpuName = if ($cpu) { [string]$cpu.Name } else { 'Unknown' }
			physicalCores = if ($cpu) { [int]$cpu.NumberOfCores } else { 0 }
			logicalProcessors = if ($cpu) { [int]$cpu.NumberOfLogicalProcessors } else { 0 }
			ramGb = $ramGb
			gpuName = $gpuName
			gpuVendor = $gpuVendor
			storageType = $storageType
			networkAdapters = @($nics | ForEach-Object { [string]$_.Name })
			networkFastLink = $fastNic
			hidPeripheralCount = if ($hid) { [int]$hid.Count } else { 0 }
		}
	}

	function New-ExternalToolProfilesFromSnapshot {
		param([Parameter(Mandatory = $true)][hashtable]$Snapshot)

		$logical = [int]$Snapshot.logicalProcessors
		$ramGb = [double]$Snapshot.ramGb

		$proBalance = if ($logical -ge 12) { $true } else { $false }
		$cpuSets = if ($logical -ge 16) { 'Prefer P-cores / high-performance cores for foreground games' } elseif ($logical -ge 8) { 'Use all cores, keep 1 logical core free for OS background' } else { 'Use all cores, no pinning by default' }
		$ioPriority = if ($Snapshot.storageType -eq 'HDD/Mixed') { 'High' } else { 'Normal' }

		$islcListSize = 1024
		$islcFreeMb = 2048
		if ($ramGb -ge 32) {
			$islcListSize = 4096
			$islcFreeMb = 8192
		}
		elseif ($ramGb -ge 16) {
			$islcListSize = 2048
			$islcFreeMb = 4096
		}
		elseif ($ramGb -lt 12) {
			$islcListSize = 512
			$islcFreeMb = 1024
		}

		$timerMs = if ($logical -ge 12 -and $ramGb -ge 16) { 0.5 } else { 1.0 }

		$processLassoProfile = [ordered]@{
			profileName = 'Gaming Auto-Optimized'
			engineVersion = 'mga-1'
			recommendedBy = 'Mga Optimizer'
			proBalanceEnabled = $proBalance
			foregroundPriorityClass = 'High'
			powerProfileHint = 'Bitsum Highest Performance'
			cpuAffinityStrategy = $cpuSets
			ioPriority = $ioPriority
			detectedGpuVendor = [string]$Snapshot.gpuVendor
			networkBias = if ($Snapshot.networkFastLink) { 'Low latency' } else { 'Balanced latency' }
			notes = @(
				'Import manually in Process Lasso as a target behavior baseline.',
				'If stutter appears, reduce forced priority from High to Above Normal.'
			)
		}

		$islcProfile = [ordered]@{
			profileName = 'Gaming Auto-Optimized'
			engineVersion = 'mga-1'
			recommendedBy = 'Mga Optimizer'
			wantedTimerResolutionMs = $timerMs
			freeMemoryLowerThanMb = $islcFreeMb
			isrStandbyListThresholdMb = $islcListSize
			purgeStandbyList = $true
			autoStartWithWindows = $true
			startMinimized = $true
			notes = @(
				'Use these values in ISLC fields and enable Start ISLC minimized + Auto-Start monitoring.',
				'For unstable frametime, try timer 1.0 ms even on high-end systems.'
			)
		}

		return [ordered]@{
			hardware = $Snapshot
			processLasso = $processLassoProfile
			islc = $islcProfile
		}
	}

	function Save-ExternalToolProfiles {
		param([Parameter(Mandatory = $true)][hashtable]$Profiles)

		$dir = Get-ExternalProfilesDirectory
		$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

		$hardwarePath = Join-Path $dir ("hardware_snapshot_{0}.json" -f $stamp)
		$plPath = Join-Path $dir ("process_lasso_profile_{0}.json" -f $stamp)
		$islcPath = Join-Path $dir ("islc_profile_{0}.json" -f $stamp)
		$guidePath = Join-Path $dir ("README_apply_profiles_{0}.txt" -f $stamp)

		$Profiles.hardware | ConvertTo-Json -Depth 8 | Set-Content -Path $hardwarePath -Encoding UTF8
		$Profiles.processLasso | ConvertTo-Json -Depth 8 | Set-Content -Path $plPath -Encoding UTF8
		$Profiles.islc | ConvertTo-Json -Depth 8 | Set-Content -Path $islcPath -Encoding UTF8

		$guide = @(
			'Mga Optimizer - External Gaming Tool Profiles',
			'',
			'1) Process Lasso:',
			"   - Open $plPath",
			'   - Apply equivalent rules: ProBalance, High priority for games, and affinity strategy from cpuAffinityStrategy.',
			'',
			'2) ISLC:',
			"   - Open $islcPath",
			'   - Fill ISLC values: wantedTimerResolutionMs, freeMemoryLowerThanMb, isrStandbyListThresholdMb.',
			'   - Enable auto-start monitoring and minimized startup.',
			'',
			'3) Built-in timer:',
			'   - You can also use the Built-in Timer Resolution buttons in FPS Boost Tools tab.'
		)
		$guide | Set-Content -Path $guidePath -Encoding UTF8

		return [ordered]@{
			directory = $dir
			hardwarePath = $hardwarePath
			processLassoPath = $plPath
			islcPath = $islcPath
			guidePath = $guidePath
		}
	}

	function Get-AutoToolTweakIdsFromSnapshot {
		param([Parameter(Mandatory = $true)][hashtable]$Snapshot)

		$ids = @(
			'network_profile',
			'set_tcp_ack_frequency',
			'disable_nagle_algorithm',
			'disable_usb_power_saving',
			'auto_game_process_priority_high'
		)

		if ([int]$Snapshot.hidPeripheralCount -gt 0) {
			$ids += 'usb_polling_rate_optimization'
		}

		if ([double]$Snapshot.ramGb -le 16) {
			$ids += 'clear_standby_memory'
		}

		if (([int]$Snapshot.logicalProcessors -ge 12) -and ([double]$Snapshot.ramGb -ge 16)) {
			$ids += 'set_timer_resolution_05ms'
		}
		else {
			$ids += 'set_timer_resolution_1ms'
		}

		return @($ids | Select-Object -Unique)
	}

	function Apply-AutoToolProfileNow {
		param([Parameter(Mandatory = $true)][hashtable]$Snapshot)

		$recommended = Get-AutoToolTweakIdsFromSnapshot -Snapshot $Snapshot
		$selectedTweaks = @($recommended | Where-Object { $catalogById.ContainsKey($_) })
		if ($selectedTweaks.Count -eq 0) {
			throw 'No auto-profile tweaks are available in current tweak catalog.'
		}

		$highRiskSelected = @($selectedTweaks | Where-Object { $catalogById[$_].risk -eq 'high' })
		if ($highRiskSelected.Count -gt 0) {
			$names = ($highRiskSelected | ForEach-Object { [string]$catalogById[$_].label }) -join "`n- "
			$confirm = [System.Windows.MessageBox]::Show("Auto profile includes high-risk tweaks:`n- $names`n`nContinue?", 'High-risk confirmation', 'YesNo', 'Warning')
			if ($confirm -ne 'Yes') {
				return [ordered]@{ Applied = $false; AppliedCount = 0; BackupFile = $null }
			}
		}

		$backup = New-ApplyBackup
		$backupSeen = @{}
		$backupFile = $null

		try {
			foreach ($tweakId in $selectedTweaks) {
				Write-Log ("Auto applying: {0}" -f [string]$catalogById[$tweakId].label)
				Invoke-TweakById -Id $tweakId -Backup $backup -BackupSeen $backupSeen
				Write-Log ("Auto applied: {0}" -f [string]$catalogById[$tweakId].label)
			}

			if (Test-BackupHasData -Backup $backup) {
				$backupFile = Save-ApplyBackup -Backup $backup
				Write-Log ("Auto profile rollback backup saved: {0}" -f $backupFile)
			}
		}
		catch {
			if ((-not [string]::IsNullOrWhiteSpace([string]$backupFile)) -eq $false -and (Test-BackupHasData -Backup $backup)) {
				$backupFile = Save-ApplyBackup -Backup $backup
				Write-Log ("Partial auto-profile backup saved: {0}" -f $backupFile)
			}
			throw
		}

		return [ordered]@{ Applied = $true; AppliedCount = $selectedTweaks.Count; BackupFile = $backupFile }
	}

	function Set-DisableMPO {
		New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' -Name 'OverlayTestMode' -Value 5 -PropertyType DWord -Force | Out-Null
	}

	function Set-NagleDisabled {
		$interfacesPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
		if (-not (Test-Path -Path $interfacesPath)) {
			return
		}

		$interfaces = Get-ChildItem -Path $interfacesPath -ErrorAction SilentlyContinue
		foreach ($iface in $interfaces) {
			New-ItemProperty -Path $iface.PSPath -Name 'TCPNoDelay' -Value 1 -PropertyType DWord -Force | Out-Null
			New-ItemProperty -Path $iface.PSPath -Name 'TcpAckFrequency' -Value 1 -PropertyType DWord -Force | Out-Null
		}
	}

	function Invoke-FlushDns {
		ipconfig /flushdns | Out-Null
	}

	function Set-DnsServers {
		param([Parameter(Mandatory = $true)][string[]]$Servers)

		$adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
		foreach ($adapter in $adapters) {
			Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $Servers -ErrorAction SilentlyContinue
		}
	}

	function Set-ServiceStartupTypeByName {
		param(
			[Parameter(Mandatory = $true)][string[]]$ServiceNames,
			[Parameter(Mandatory = $true)][ValidateSet('Disabled', 'Manual')][string]$StartupType
		)

		foreach ($svcName in $ServiceNames) {
			$svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
			if (-not $svc) {
				continue
			}

			Set-Service -Name $svcName -StartupType $StartupType -ErrorAction SilentlyContinue
			if ($StartupType -eq 'Disabled' -and $svc.Status -eq 'Running') {
				Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
			}
		}
	}

	function Set-MemoryCompressionDisabled {
		if (Get-Command -Name Disable-MMAgent -ErrorAction SilentlyContinue) {
			Disable-MMAgent -MemoryCompression | Out-Null
		}
	}

	function Set-LargeSystemCacheEnabled {
		New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Force | Out-Null
		New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'LargeSystemCache' -Value 1 -PropertyType DWord -Force | Out-Null
	}

	function Set-DisableUsbPowerSaving {
		$subUsb = '2a737441-1930-4402-8d77-b2bebba308a3'
		$usbSuspend = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
		powercfg /SETACVALUEINDEX SCHEME_CURRENT $subUsb $usbSuspend 0 | Out-Null
		powercfg /SETDCVALUEINDEX SCHEME_CURRENT $subUsb $usbSuspend 0 | Out-Null
		powercfg /SETACTIVE SCHEME_CURRENT | Out-Null
	}

	function Set-RawInputPriority {
		$path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
		New-Item -Path $path -Force | Out-Null
		New-ItemProperty -Path $path -Name 'GPU Priority' -Value 8 -PropertyType DWord -Force | Out-Null
		New-ItemProperty -Path $path -Name 'Priority' -Value 6 -PropertyType DWord -Force | Out-Null
		New-ItemProperty -Path $path -Name 'Scheduling Category' -Value 'High' -PropertyType String -Force | Out-Null
	}

	function Set-KeyboardRepeatDelayMin {
		New-Item -Path 'HKCU:\Control Panel\Keyboard' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Control Panel\Keyboard' -Name 'KeyboardDelay' -Value '0' -PropertyType String -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Control Panel\Keyboard' -Name 'KeyboardSpeed' -Value '31' -PropertyType String -Force | Out-Null
	}

	function Set-NtfsLastAccessDisabled {
		fsutil behavior set disablelastaccess 1 | Out-Null
	}

	function Set-DefragScheduleDisabled {
		schtasks /Change /TN '\Microsoft\Windows\Defrag\ScheduledDefrag' /Disable | Out-Null
	}

	function Invoke-TrimOptimization {
		$drives = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }
		foreach ($drive in $drives) {
			Optimize-Volume -DriveLetter $drive.DriveLetter -ReTrim -ErrorAction SilentlyContinue | Out-Null
		}
	}

	function Set-MaxCpuState {
		$subProcessor = '54533251-82be-4824-96c1-47b60b740d00'
		$procThrottleMin = '893dee8e-2bef-41e0-89c6-b55d0929964c'
		$procThrottleMax = 'bc5038f7-23e0-4960-96da-33abaf5935ec'

		powercfg -setacvalueindex SCHEME_CURRENT $subProcessor $procThrottleMin 100 | Out-Null
		powercfg -setdcvalueindex SCHEME_CURRENT $subProcessor $procThrottleMin 100 | Out-Null
		powercfg -setacvalueindex SCHEME_CURRENT $subProcessor $procThrottleMax 100 | Out-Null
		powercfg -setdcvalueindex SCHEME_CURRENT $subProcessor $procThrottleMax 100 | Out-Null
		powercfg -setactive SCHEME_CURRENT | Out-Null
	}

	function Set-DisableSleepStates {
		powercfg /change standby-timeout-ac 0 | Out-Null
		powercfg /change standby-timeout-dc 0 | Out-Null
		powercfg /change hibernate-timeout-ac 0 | Out-Null
		powercfg /change hibernate-timeout-dc 0 | Out-Null
	}

	function Set-GameModeForcedOn {
		New-Item -Path 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value 1 -PropertyType DWord -Force | Out-Null
		New-ItemProperty -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AllowAutoGameMode' -Value 1 -PropertyType DWord -Force | Out-Null
	}

	function Set-DefenderRealtimeDisabled {
		if (Get-Command -Name Set-MpPreference -ErrorAction SilentlyContinue) {
			Set-MpPreference -DisableRealtimeMonitoring $true
		}
	}

	function Load-TweakCatalog {
		$catalogPath = Join-Path $script:ProjectRoot 'src\config\gui_tweaks.json'
		if (-not (Test-Path -Path $catalogPath)) {
			throw "Missing tweak catalog: $catalogPath"
		}

		$raw = Get-Content -Path $catalogPath -Raw | ConvertFrom-Json
		if (-not $raw.tweaks -or $raw.tweaks.Count -eq 0) {
			throw 'Tweak catalog is empty.'
		}

		Set-Variable -Scope 1 -Name tweakCatalog -Value @($raw.tweaks)
		$catalogById.Clear()
		$tweakSelection.Clear()
		foreach ($tweak in $tweakCatalog) {
			$id = [string]$tweak.id
			$catalogById[$id] = $tweak
			$tweakSelection[$id] = $false
		}
	}

	function Get-ComboSelectedText {
		param(
			[Parameter(Mandatory = $true)]$Combo,
			[string]$DefaultText = 'All'
		)

		if ($null -eq $Combo) {
			return $DefaultText
		}

		if ($Combo.SelectedItem -is [string]) {
			return [string]$Combo.SelectedItem
		}

		if ($Combo.SelectedItem -is [System.Windows.Controls.ComboBoxItem]) {
			return [string]$Combo.SelectedItem.Content
		}

		if ($null -ne $Combo.SelectedItem) {
			return [string]$Combo.SelectedItem.ToString()
		}

		return $DefaultText
	}

	function Populate-FilterControls {
		$cmbCategoryFilter.Items.Clear()
		$cmbRiskFilter.Items.Clear()

		$cmbCategoryFilter.Items.Add('All Categories') | Out-Null

		$categories = $tweakCatalog | ForEach-Object { [string]$_.category } | Sort-Object -Unique
		foreach ($category in $categories) {
			$cmbCategoryFilter.Items.Add($category) | Out-Null
		}

		$cmbRiskFilter.Items.Add('No Auto-Select') | Out-Null
		$cmbRiskFilter.Items.Add('ALL') | Out-Null

		foreach ($risk in @('Low', 'Medium', 'High')) {
			$cmbRiskFilter.Items.Add($risk) | Out-Null
		}

		$cmbCategoryFilter.SelectedIndex = 0
		$cmbRiskFilter.SelectedIndex = 0
		$txtSearchFilter.Text = ''
	}

	function Get-FilteredTweaks {
		$categoryText = Get-ComboSelectedText -Combo $cmbCategoryFilter -DefaultText 'All Categories'
		$searchText = if ($null -eq $txtSearchFilter) { '' } else { [string]$txtSearchFilter.Text }
		$searchText = $searchText.Trim().ToLowerInvariant()

		$filtered = $tweakCatalog

		if ($categoryText -ne 'All Categories') {
			$filtered = @($filtered | Where-Object { [string]$_.category -eq $categoryText })
		}

		if (-not [string]::IsNullOrWhiteSpace($searchText)) {
			$filtered = @($filtered | Where-Object {
				$hay = ("{0} {1} {2} {3}" -f ([string]$_.label), ([string]$_.description), ([string]$_.category), ([string]$_.id)).ToLowerInvariant()
				$hay.Contains($searchText)
			})
		}

		return @($filtered)
	}

	function Apply-RiskSelection {
		$riskText = Get-ComboSelectedText -Combo $cmbRiskFilter -DefaultText 'No Auto-Select'
		if ($riskText -eq 'No Auto-Select') {
			return 0
		}

		if ($riskText -eq 'ALL') {
			foreach ($id in @($tweakSelection.Keys)) {
				$tweakSelection[$id] = $true
			}
			return $tweakSelection.Count
		}

		foreach ($id in @($tweakSelection.Keys)) {
			$tweakSelection[$id] = $false
		}

		$matched = @($tweakCatalog | Where-Object { (Get-RiskLabel -Risk ([string]$_.risk)) -eq $riskText })
		foreach ($tweak in $matched) {
			$id = [string]$tweak.id
			if ($tweakSelection.ContainsKey($id)) {
				$tweakSelection[$id] = $true
			}
		}

		return $matched.Count
	}

	function Render-Tweaks {
		$pnlTweaks.Children.Clear()
		$tweakControls.Clear()

		$filteredTweaks = Get-FilteredTweaks
		if ($filteredTweaks.Count -eq 0) {
			$empty = New-Object System.Windows.Controls.TextBlock
			$empty.Text = 'No tweaks match current filters.'
			$empty.Foreground = [System.Windows.Media.Brushes]::LightGray
			$empty.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
			$pnlTweaks.Children.Add($empty) | Out-Null
			return
		}

		$grouped = $filteredTweaks | Group-Object -Property category
		foreach ($group in $grouped) {
			$header = New-Object System.Windows.Controls.TextBlock
			$header.Text = [string]$group.Name
			$header.Style = $window.FindResource('CategoryText')
			$pnlTweaks.Children.Add($header) | Out-Null

			foreach ($tweak in $group.Group) {
				$check = New-Object System.Windows.Controls.CheckBox
				$check.Margin = New-Object System.Windows.Thickness(0, 4, 0, 4)
				$check.FontSize = 14
				$id = [string]$tweak.id
				$check.Tag = $id
				$check.Content = "{0} [{1}]" -f [string]$tweak.label, (Get-RiskLabel -Risk ([string]$tweak.risk))
				$check.ToolTip = [string]$tweak.description
				$check.Foreground = [System.Windows.Media.Brushes]::Gainsboro
				$check.IsChecked = [bool]$tweakSelection[$id]
				$check.Add_Checked({
					$currentId = [string]$this.Tag
					$tweakSelection[$currentId] = $true
				})
				$check.Add_Unchecked({
					$currentId = [string]$this.Tag
					$tweakSelection[$currentId] = $false
				})
				$pnlTweaks.Children.Add($check) | Out-Null
				$tweakControls[$id] = $check
			}
		}
	}

	function Get-SelectedTweakIds {
		$ids = @($tweakSelection.Keys | Where-Object { [bool]$tweakSelection[$_] })
		if (-not $ids) {
			return @()
		}
		return @($ids)
	}

	function Set-SelectionByIds {
		param([string[]]$Ids)
		$set = @{}
		foreach ($id in $Ids) { $set[$id] = $true }
		foreach ($id in @($tweakSelection.Keys)) {
			$tweakSelection[$id] = $set.ContainsKey($id)
		}
		Render-Tweaks
	}

	function Apply-ModeDefaults {
		param([Parameter(Mandatory = $true)][ValidateSet('safe', 'aggressive')][string]$Mode)
		foreach ($tweak in $tweakCatalog) {
			$id = [string]$tweak.id

			if ($Mode -eq 'safe') {
				$tweakSelection[$id] = [bool]$tweak.safeDefault
			}
			else {
				$tweakSelection[$id] = [bool]$tweak.aggressiveDefault
			}
		}
		Render-Tweaks
		Write-Log ("Mode applied: {0}." -f $Mode)
	}

	function Set-Profile {
		param([Parameter(Mandatory = $true)][string]$ProfileName)

		switch ($ProfileName.ToLowerInvariant()) {
			'safe' {
				Apply-ModeDefaults -Mode 'safe'
			}
			'aggressive' {
				Apply-ModeDefaults -Mode 'aggressive'
			}
			default {
				Set-SelectionByIds -Ids @(
					'delete_temp_files',
					'keyboard_input_lag',
					'disable_usb_power_saving',
					'disable_mouse_accel',
					'disable_gamebar',
					'game_mode_on',
					'disable_fullscreen_optimizations',
					'disable_mpo',
					'hw_scheduling',
					'ultimate_power_plan',
					'cpu_core_parking_disable',
					'disable_dynamic_tick',
					'network_profile',
					'disable_nagle_algorithm',
					'disable_sysmain',
					'large_system_cache',
					'disable_power_throttling',
					'max_cpu_state_100',
					'disable_ntfs_last_access'
				)
			}
		}
		Write-Log ("Profile applied: {0}." -f $ProfileName)
	}

	function Export-Preset {
		$selected = Get-SelectedTweakIds
		$profile = if ($cmbProfile.SelectedItem -is [System.Windows.Controls.ComboBoxItem]) { [string]$cmbProfile.SelectedItem.Content } else { 'Balanced' }

		$dialog = New-Object Microsoft.Win32.SaveFileDialog
		$dialog.Filter = 'JSON files (*.json)|*.json'
		$dialog.FileName = 'custom-preset.json'
		$dialog.InitialDirectory = Join-Path $script:ProjectRoot 'src\profiles'

		$ok = $dialog.ShowDialog()
		if (-not $ok) {
			return
		}

		$preset = [ordered]@{
			name = 'custom'
			createdAt = (Get-Date).ToString('o')
			profile = $profile
			tweaks = $selected
		}

		$preset | ConvertTo-Json -Depth 6 | Set-Content -Path $dialog.FileName -Encoding UTF8
		Write-Log ("Preset exported: {0}" -f $dialog.FileName)
	}

	function Import-Preset {
		$dialog = New-Object Microsoft.Win32.OpenFileDialog
		$dialog.Filter = 'JSON files (*.json)|*.json'
		$dialog.InitialDirectory = Join-Path $script:ProjectRoot 'src\profiles'

		$ok = $dialog.ShowDialog()
		if (-not $ok) {
			return
		}

		$preset = Get-Content -Path $dialog.FileName -Raw | ConvertFrom-Json
		if (-not $preset.tweaks) {
			throw 'Preset file does not contain tweaks.'
		}

		Set-SelectionByIds -Ids @($preset.tweaks)
		Write-Log ("Preset imported: {0}" -f $dialog.FileName)
	}

	function Invoke-TweakById {
		param(
			[Parameter(Mandatory = $true)][string]$Id,
			[Parameter(Mandatory = $true)]$Backup,
			[Parameter(Mandatory = $true)][hashtable]$BackupSeen
		)

		switch ($Id) {
			'delete_temp_files' {
				Invoke-DeleteTempFiles
			}
			'flush_dns' {
				Invoke-FlushDns
			}
			'set_dns_cloudflare' {
				Set-DnsServers -Servers @('1.1.1.1', '1.0.0.1')
			}
			'set_dns_google' {
				Set-DnsServers -Servers @('8.8.8.8', '8.8.4.4')
			}
			'keyboard_input_lag' {
				$Backup.KeyboardApplied = $true
				Invoke-KeyboardInputLagApply
			}
			'disable_usb_power_saving' {
				Set-DisableUsbPowerSaving
			}
			'raw_input_priority' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' -Name 'GPU Priority'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' -Name 'Priority'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' -Name 'Scheduling Category'
				Set-RawInputPriority
			}
			'disable_keyboard_repeat_delay' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Control Panel\Keyboard' -Name 'KeyboardDelay'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Control Panel\Keyboard' -Name 'KeyboardSpeed'
				Set-KeyboardRepeatDelayMin
			}
			'disable_activity_history' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'EnableActivityFeed'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'PublishUserActivities'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'UploadUserActivities'
				Set-ActivityHistoryDisabled
			}
			'disable_consumer_features' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures'
				Set-ConsumerFeaturesDisabled
			}
			'disable_location_tracking' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' -Name 'Value'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation'
				Set-LocationTrackingDisabled
			}
			'disable_telemetry' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry'
				Set-TelemetryDisabled
			}
			'enable_endtask_taskbar' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' -Name 'TaskbarEndTask'
				Set-TaskbarEndTaskEnabled
			}
			'remove_widgets' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests'
				Set-WidgetsDisabled
			}
			'run_disk_cleanup' {
				Invoke-DiskCleanup
			}
			'disable_mouse_accel' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold1'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold2'
				Set-MouseAccelerationDisabled
			}
			'disable_gamebar' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\SOFTWARE\Microsoft\GameBar' -Name 'ShowStartupPanel'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\SOFTWARE\Microsoft\GameBar' -Name 'AutoGameModeEnabled'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR'
				Set-GameBarDisabled
			}
			'game_mode_on' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AllowAutoGameMode'
				Set-GameModeForcedOn
			}
			'disable_mpo' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' -Name 'OverlayTestMode'
				Set-DisableMPO
			}
			'hw_scheduling' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode'
				Set-HardwareSchedulingEnabled
			}
			'ultimate_power_plan' {
				$Backup.Power.ActiveGuid = Get-ActivePowerSchemeGuid
				$Backup.Power.HadValue = $null -ne $Backup.Power.ActiveGuid
				Set-UltimatePerformancePlan
			}
			'cpu_core_parking_disable' {
				Disable-CPUCoresParking
			}
			'disable_dynamic_tick' {
				Disable-DynamicTick
			}
			'disable_hpet' {
				Disable-HPET
			}
			'set_timer_resolution_05ms' {
				Set-SystemTimerResolution -Microseconds 500
			}
			'set_timer_resolution_1ms' {
				Set-SystemTimerResolution -Microseconds 1000
			}
			'set_interrupt_affinity_gpu_nic' {
				Set-PciInterruptAffinityGpuNic -Backup $Backup -BackupSeen $BackupSeen
			}
			'enable_gpu_msi_mode' {
				Set-GpuMsiModeEnabled -Backup $Backup -BackupSeen $BackupSeen
			}
			'disable_pcie_link_state_power_management' {
				Set-PcieLinkStatePowerManagementDisabled
			}
			'set_tcp_ack_frequency' {
				Set-TcpAckFrequencyOnly
			}
			'disable_qos_packet_scheduler' {
				Set-QoSPacketSchedulerDisabled
			}
			'clear_standby_memory' {
				Clear-StandbyMemoryList
			}
			'usb_polling_rate_optimization' {
				Set-UsbPollingOptimization
			}
			'auto_game_process_priority_high' {
				$prioBase = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
				$prioExes = @(
					'cs2.exe',
					'valorant.exe',
					'fortniteclient-win64-shipping.exe',
					'cod.exe',
					'apexlegends.exe',
					'r5apex.exe',
					'overwatch.exe',
					'leagueoflegends.exe',
					'dota2.exe',
					'rocketleague.exe'
				)

				foreach ($exe in $prioExes) {
					$perfPath = Join-Path (Join-Path $prioBase $exe) 'PerfOptions'
					Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path $perfPath -Name 'CpuPriorityClass'
				}

				Set-GameProcessPriorityAutoHigh
			}
			'bcd_useplatformtick' {
				Set-BcdUsePlatformTickEnabled
			}
			'bcd_tscsyncpolicy_enhanced' {
				Set-BcdTscSyncPolicyEnhanced
			}
			'disable_hibernation' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled'
				Set-HibernationDisabled
			}
			'disable_startup_delay' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name 'StartupDelayInMSec'
				Set-StartupDelayDisabled
			}
			'disable_transparency' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency'
				Set-TransparencyDisabled
			}
			'disable_fullscreen_optimizations' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_FSEBehaviorMode'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_HonorUserFSEBehaviorMode'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_DXGIHonorFSEWindowsCompatible'
				Set-FullscreenOptimizationsDisabled
			}
			'network_profile' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex'
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'SystemResponsiveness'
				Set-NetworkLatencyProfile
			}
			'power_throttling' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -Name 'PowerThrottlingOff'
				Set-PowerThrottlingDisabled
			}
			'disable_power_throttling' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -Name 'PowerThrottlingOff'
				Set-PowerThrottlingDisabled
			}
			'disable_nagle_algorithm' {
				Set-NagleDisabled
			}
			'disable_delivery_optimization' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' -Name 'DODownloadMode'
				Set-DeliveryOptimizationDisabled
			}
			'disable_background_apps' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled'
				Set-BackgroundAppsLimited
			}
			'disable_sysmain' {
				Set-ServiceStartupTypeByName -ServiceNames @('SysMain') -StartupType 'Disabled'
			}
			'disable_memory_compression' {
				Set-MemoryCompressionDisabled
			}
			'large_system_cache' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'LargeSystemCache'
				Set-LargeSystemCacheEnabled
			}
			'disable_windows_search' {
				Set-ServiceStartupTypeByName -ServiceNames @('WSearch') -StartupType 'Disabled'
			}
			'disable_print_spooler' {
				Set-ServiceStartupTypeByName -ServiceNames @('Spooler') -StartupType 'Disabled'
			}
			'disable_bluetooth_services' {
				Set-ServiceStartupTypeByName -ServiceNames @('bthserv', 'BthAvctpSvc') -StartupType 'Disabled'
			}
			'disable_xbox_services' {
				Set-ServiceStartupTypeByName -ServiceNames @('XblAuthManager', 'XblGameSave', 'XboxGipSvc', 'XboxNetApiSvc') -StartupType 'Disabled'
			}
			'disable_diagtrack_service' {
				Set-ServiceStartupTypeByName -ServiceNames @('DiagTrack') -StartupType 'Disabled'
			}
			'disable_ntfs_last_access' {
				Set-NtfsLastAccessDisabled
			}
			'disable_defrag_schedule' {
				Set-DefragScheduleDisabled
			}
			'trim_optimization' {
				Invoke-TrimOptimization
			}
			'max_cpu_state_100' {
				Set-MaxCpuState
			}
			'disable_sleep_states' {
				Set-DisableSleepStates
			}
			'disable_defender_realtime' {
				Set-DefenderRealtimeDisabled
			}
			'disable_ipv6' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisabledComponents'
				Set-IPv6Disabled
			}
			'prefer_ipv4_over_ipv6' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisabledComponents'
				Set-PreferIPv4OverIPv6
			}
			'disable_copilot' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot'
				Set-CopilotDisabled
			}
			'disable_storage_sense' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' -Name '01'
				Set-StorageSenseDisabled
			}
			'disable_teredo' {
				Set-TeredoDisabled
			}
			'set_classic_right_click_menu' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' -Name '(default)'
				Set-ClassicContextMenu
			}
			'set_display_for_performance' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting'
				Set-VisualEffectsBestPerformance
			}
			'set_time_utc_dualboot' {
				Backup-RegistryEntry -Backup $Backup -Seen $BackupSeen -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Name 'RealTimeIsUniversal'
				Set-UTCDualBoot
			}
			default {
				throw "Unknown tweak id: $Id"
			}
		}

		$Backup.AppliedTweaks += $Id
	}

	function Get-CheckedServiceNames {
		$names = @()
		foreach ($child in $pnlServices.Children) {
			if (($child -is [System.Windows.Controls.CheckBox]) -and $child.IsEnabled -and $child.IsChecked) {
				$names += [string]$child.Tag
			}
		}
		return $names
	}

	function Refresh-ServicePanel {
		$pnlServices.Children.Clear()
		foreach ($serviceName in $serviceTargets) {
			$checkBox = New-Object System.Windows.Controls.CheckBox
			$checkBox.Tag = $serviceName
			$checkBox.Margin = New-Object System.Windows.Thickness(0, 2, 0, 2)

			$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
			if (-not $service) {
				$checkBox.Content = "$serviceName (not available on this system)"
				$checkBox.IsEnabled = $false
			}
			else {
				$cim = Get-CimInstance Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue
				$startupType = if ($cim) { $cim.StartMode } else { 'Unknown' }
				$checkBox.Content = "{0} ({1}) - Startup: {2}, Status: {3}" -f $serviceName, $service.DisplayName, $startupType, $service.Status
			}

			$pnlServices.Children.Add($checkBox) | Out-Null
		}
	}

	function Set-SelectedServicesStartupType {
		param([Parameter(Mandatory = $true)][ValidateSet('Disabled', 'Manual')][string]$StartupType)
		$selected = Get-CheckedServiceNames
		if ($selected.Count -eq 0) {
			Write-Log 'No services selected.'
			return
		}

		foreach ($serviceName in $selected) {
			try {
				Set-Service -Name $serviceName -StartupType $StartupType -ErrorAction Stop
				if ($StartupType -eq 'Disabled') {
					$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
					if ($svc -and $svc.Status -eq 'Running') {
						Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
					}
				}
				Write-Log ("Service {0} set to {1}." -f $serviceName, $StartupType)
			}
			catch {
				Write-Log ("Service {0} failed: {1}" -f $serviceName, $_.Exception.Message)
			}
		}

		Refresh-ServicePanel
	}

	$btnApplyProfile.Add_Click({
		if ($cmbProfile.SelectedItem -is [System.Windows.Controls.ComboBoxItem]) {
			Set-Profile -ProfileName ([string]$cmbProfile.SelectedItem.Content)
		}
	})

	$btnApplyFilters.Add_Click({
		$selectedByRisk = Apply-RiskSelection
		Render-Tweaks
		if ($selectedByRisk -gt 0) {
			$riskText = Get-ComboSelectedText -Combo $cmbRiskFilter -DefaultText 'No Auto-Select'
			Write-Log ("Selected {0} tweaks with risk: {1}." -f $selectedByRisk, $riskText)
		}
		Write-Log 'Filters applied.'
	})

	$btnClearFilters.Add_Click({
		$cmbCategoryFilter.SelectedIndex = 0
		$cmbRiskFilter.SelectedIndex = 0
		$txtSearchFilter.Text = ''
		Render-Tweaks
		Write-Log 'Filters cleared.'
	})

	$cmbCategoryFilter.Add_SelectionChanged({ Render-Tweaks })
	$cmbRiskFilter.Add_SelectionChanged({
		$selectedByRisk = Apply-RiskSelection
		Render-Tweaks
		if ($selectedByRisk -gt 0) {
			$riskText = Get-ComboSelectedText -Combo $cmbRiskFilter -DefaultText 'No Auto-Select'
			Write-Log ("Selected {0} tweaks with risk: {1}." -f $selectedByRisk, $riskText)
		}
	})
	$txtSearchFilter.Add_TextChanged({ Render-Tweaks })

	$btnExportPreset.Add_Click({
		try {
			Export-Preset
		}
		catch {
			Write-Log ("Error: " + $_.Exception.Message)
		}
	})

	$btnImportPreset.Add_Click({
		try {
			Import-Preset
		}
		catch {
			Write-Log ("Error: " + $_.Exception.Message)
		}
	})

	$btnRefreshServices.Add_Click({
		Refresh-ServicePanel
		Write-Log 'Service list refreshed.'
	})

	$btnDisableSelectedServices.Add_Click({ Set-SelectedServicesStartupType -StartupType 'Disabled' })
	$btnManualSelectedServices.Add_Click({ Set-SelectedServicesStartupType -StartupType 'Manual' })

	$btnInstallProcessLasso.Add_Click({
		try {
			Install-ToolWithWinget -ToolName 'Process Lasso' -PackageId 'Bitsum.ProcessLasso' -FallbackUrl 'https://bitsum.com/'
		}
		catch {
			Write-Log ("Error installing Process Lasso: " + $_.Exception.Message)
		}
	})

	$btnOpenProcessLasso.Add_Click({
		try {
			Open-ToolUrl -Url 'https://bitsum.com/'
			Write-Log 'Opened Process Lasso website.'
		}
		catch {
			Write-Log ("Error opening Process Lasso website: " + $_.Exception.Message)
		}
	})

	$btnInstallISLC.Add_Click({
		try {
			Install-ToolWithWinget -ToolName 'ISLC' -PackageId 'Wagnardsoft.ISLC' -FallbackUrl 'https://www.wagnardsoft.com/forums/viewtopic.php?t=1256'
		}
		catch {
			Write-Log ("Error installing ISLC: " + $_.Exception.Message)
		}
	})

	$btnOpenISLC.Add_Click({
		try {
			Open-ToolUrl -Url 'https://www.wagnardsoft.com/forums/viewtopic.php?t=1256'
			Write-Log 'Opened ISLC download page.'
		}
		catch {
			Write-Log ("Error opening ISLC page: " + $_.Exception.Message)
		}
	})

	$btnApplyTimer05.Add_Click({
		try {
			Set-SystemTimerResolution -Microseconds 500
			Write-Log 'Applied built-in timer resolution request: 0.5 ms.'
		}
		catch {
			Write-Log ("Error applying 0.5 ms timer resolution: " + $_.Exception.Message)
		}
	})

	$btnApplyTimer1.Add_Click({
		try {
			Set-SystemTimerResolution -Microseconds 1000
			Write-Log 'Applied built-in timer resolution request: 1.0 ms.'
		}
		catch {
			Write-Log ("Error applying 1.0 ms timer resolution: " + $_.Exception.Message)
		}
	})

	$btnInstallAfterburner.Add_Click({
		try {
			Install-ToolWithWinget -ToolName 'MSI Afterburner' -PackageId 'Guru3D.Afterburner' -FallbackUrl 'https://www.msi.com/Landing/afterburner/graphics-cards'
		}
		catch {
			Write-Log ("Error installing MSI Afterburner: " + $_.Exception.Message)
		}
	})

	$btnInstallHWMonitor.Add_Click({
		try {
			Install-ToolWithWinget -ToolName 'HWMonitor' -PackageId 'CPUID.HWMonitor' -FallbackUrl 'https://www.cpuid.com/softwares/hwmonitor.html'
		}
		catch {
			Write-Log ("Error installing HWMonitor: " + $_.Exception.Message)
		}
	})

	$btnGenerateAutoToolProfiles.Add_Click({
		try {
			Write-Log 'Generating personalized Process Lasso and ISLC profiles from hardware/peripheral detection.'
			$snapshot = Get-HardwareProfileSnapshot
			$profiles = New-ExternalToolProfilesFromSnapshot -Snapshot $snapshot
			$saved = Save-ExternalToolProfiles -Profiles $profiles
			Write-Log ("Auto profiles generated in: {0}" -f $saved.directory)
			Write-Log ("Process Lasso profile: {0}" -f $saved.processLassoPath)
			Write-Log ("ISLC profile: {0}" -f $saved.islcPath)
			Write-Log ("Detected: CPU={0}, RAM={1} GB, GPU={2}, HID devices={3}" -f $snapshot.cpuName, $snapshot.ramGb, $snapshot.gpuName, $snapshot.hidPeripheralCount)
			[System.Windows.MessageBox]::Show('Auto profiles generated successfully. Use Open Folder to access them.', 'Gaming Optimizer', 'OK', 'Information') | Out-Null
		}
		catch {
			Write-Log ("Error generating auto profiles: " + $_.Exception.Message)
			[System.Windows.MessageBox]::Show(('Failed to generate profiles.`n' + $_.Exception.Message), 'Gaming Optimizer', 'OK', 'Error') | Out-Null
		}
	})

	$btnOpenAutoProfilesFolder.Add_Click({
		try {
			$dir = Get-ExternalProfilesDirectory
			Start-Process explorer.exe $dir
			Write-Log ("Opened profiles folder: {0}" -f $dir)
		}
		catch {
			Write-Log ("Error opening profiles folder: " + $_.Exception.Message)
		}
	})

	$btnApplyAutoToolProfile.Add_Click({
		try {
			Write-Log 'Building and applying auto gaming profile from detected hardware/peripherals.'
			$snapshot = Get-HardwareProfileSnapshot
			$profiles = New-ExternalToolProfilesFromSnapshot -Snapshot $snapshot
			$saved = Save-ExternalToolProfiles -Profiles $profiles
			$result = Apply-AutoToolProfileNow -Snapshot $snapshot

			if (-not [bool]$result.Applied) {
				Write-Log 'Auto profile apply canceled by user.'
				return
			}

			Write-Log ("Auto profile applied: {0} tweaks." -f [int]$result.AppliedCount)
			if ($result.BackupFile) {
				Write-Log ("Rollback backup: {0}" -f [string]$result.BackupFile)
			}
			Write-Log ("Generated profile files: {0}" -f $saved.directory)
			[System.Windows.MessageBox]::Show('Auto profile applied and profile files generated successfully.', 'Gaming Optimizer', 'OK', 'Information') | Out-Null
		}
		catch {
			Write-Log ("Error applying auto profile: " + $_.Exception.Message)
			[System.Windows.MessageBox]::Show(('Failed to apply auto profile.`n' + $_.Exception.Message), 'Gaming Optimizer', 'OK', 'Error') | Out-Null
		}
	})

	$btnApply.Add_Click({
		$btnApply.IsEnabled = $false
		$backup = New-ApplyBackup
		$backupSeen = @{}
		$backupSaved = $false
		try {
			$selectedTweaks = Get-SelectedTweakIds
			if ($selectedTweaks.Count -eq 0) {
				Write-Log 'No tweaks selected.'
				return
			}

			$highRiskSelected = @($selectedTweaks | Where-Object { $catalogById[$_].risk -eq 'high' })
			if ($highRiskSelected.Count -gt 0) {
				$names = ($highRiskSelected | ForEach-Object { [string]$catalogById[$_].label }) -join "`n- "
				$confirm = [System.Windows.MessageBox]::Show("High-risk tweaks selected:`n- $names`n`nContinue?", 'High-risk confirmation', 'YesNo', 'Warning')
				if ($confirm -ne 'Yes') {
					Write-Log 'Apply canceled by user due to high-risk selection.'
					return
				}
			}

			Write-Log 'Starting tweak execution.'

			if ($chkCreateRestorePoint.IsChecked) {
				Write-Log 'Creating system restore point.'
				$created = New-SystemRestorePoint -Description 'GamingOptimizer utility pre-apply'
				if ($created) { Write-Log 'Restore point created.' } else { Write-Log 'Restore point was not created.' }
			}

			foreach ($tweakId in $selectedTweaks) {
				Write-Log ("Applying tweak: {0}" -f $catalogById[$tweakId].label)
				Invoke-TweakById -Id $tweakId -Backup $backup -BackupSeen $backupSeen
				Write-Log ("Applied: {0}" -f $catalogById[$tweakId].label)
			}

			if (Test-BackupHasData -Backup $backup) {
				$backupFile = Save-ApplyBackup -Backup $backup
				$backupSaved = $true
				Write-Log ("Rollback backup saved: {0}" -f $backupFile)
			}

			Write-Log 'All selected tweaks completed.'
			[System.Windows.MessageBox]::Show('Selected tweaks were applied successfully.', 'Gaming Optimizer', 'OK', 'Information') | Out-Null
		}
		catch {
			Write-Log ("Error: " + $_.Exception.Message)
			[System.Windows.MessageBox]::Show(("Failed to apply tweaks. Details:`n" + $_.Exception.Message), 'Gaming Optimizer', 'OK', 'Error') | Out-Null
		}
		finally {
			if ((-not $backupSaved) -and (Test-BackupHasData -Backup $backup)) {
				$backupFile = Save-ApplyBackup -Backup $backup
				Write-Log ("Rollback backup saved after partial apply: {0}" -f $backupFile)
			}
			$btnApply.IsEnabled = $true
		}
	})

	$btnRollbackAll.Add_Click({
		try {
			$backupFile = Get-LatestApplyBackupFile
			if (-not $backupFile) {
				throw 'No global backup found.'
			}

			Write-Log ("Starting rollback from backup: {0}" -f $backupFile)
			$backup = Get-Content -Path $backupFile -Raw | ConvertFrom-Json

			if ($backup.KeyboardApplied) {
				Write-Log 'Restoring keyboard tweak.'
				Invoke-KeyboardInputLagRestore
				Write-Log 'Keyboard tweak restored.'
			}

			foreach ($entry in $backup.Registry) {
				Restore-RegistryValue -Path $entry.Path -Name $entry.Name -Exists ([bool]$entry.Exists) -Kind $entry.Kind -Value $entry.Value
			}

			if ($backup.Power -and [bool]$backup.Power.HadValue -and -not [string]::IsNullOrWhiteSpace([string]$backup.Power.ActiveGuid)) {
				powercfg -setactive ([string]$backup.Power.ActiveGuid) | Out-Null
				Write-Log ("Restored previous power plan: {0}" -f $backup.Power.ActiveGuid)
			}

			$hasHibernateRestore = $backup.Registry | Where-Object { $_.Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -and $_.Name -eq 'HibernateEnabled' }
			if ($hasHibernateRestore) {
				$hibernateValue = ($hasHibernateRestore | Select-Object -First 1).Value
				if ($null -ne $hibernateValue -and [int]$hibernateValue -eq 1) {
					powercfg -h on | Out-Null
					Write-Log 'Hibernation restored to enabled state.'
				}
			}

			Write-Log 'Global rollback completed.'
			[System.Windows.MessageBox]::Show('Rollback completed from latest backup.', 'Gaming Optimizer', 'OK', 'Information') | Out-Null
		}
		catch {
			Write-Log ("Error: " + $_.Exception.Message)
			[System.Windows.MessageBox]::Show(("Failed to rollback tweaks. Details:`n" + $_.Exception.Message), 'Gaming Optimizer', 'OK', 'Error') | Out-Null
		}
	})

	Load-TweakCatalog
	Populate-FilterControls
	Render-Tweaks
	Set-Profile -ProfileName 'Balanced'
	Refresh-ServicePanel
	Write-Log 'Utility ready.'
	$window.ShowDialog() | Out-Null
}
