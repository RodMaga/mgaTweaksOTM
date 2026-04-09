# Verificacao/execucao como admin

function Ensure-Admin {
	param(
		[string]$ScriptPath = $PSCommandPath
	)

	$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	if (-not $isAdmin) {
		if ([string]::IsNullOrWhiteSpace($ScriptPath) -or -not (Test-Path -Path $ScriptPath)) {
			throw "Cannot elevate: invalid script path '$ScriptPath'."
		}

		Write-Output "Reiniciando script com privilegios de administrador..."
		Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" -Verb RunAs
		exit
	}
	else {
		Write-Output "Permissoes de administrador confirmadas."
	}
}
