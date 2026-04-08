# Verificação/execução como admin

function Ensure-Admin {
	$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	if (-not $isAdmin) {
		Write-Output "Reiniciando script com privilégios de administrador..."
		Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
		exit
	}
	else {
		Write-Output "Permissões de administrador confirmadas."
	}
}
