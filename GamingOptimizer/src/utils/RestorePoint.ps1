# Criação de pontos de restauração

function New-SystemRestorePoint {
	param(
		[string]$Description = "GamingOptimizer - Pré-Tweaks"
	)
	try {
		Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS"
		Write-Output "Ponto de restauro criado com sucesso."
		return $true
	} catch {
		Write-Output "Erro ao criar ponto de restauro: $_"
		return $false
	}
}
