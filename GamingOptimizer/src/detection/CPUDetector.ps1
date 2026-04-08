# Detalhes do processador (Intel/AMD)

function Get-CPUVendor {
	$cpu = Get-WmiObject Win32_Processor | Select-Object -ExpandProperty Manufacturer
	return $cpu
}

function Is-IntelCPU {
	$vendor = Get-CPUVendor
	return ($vendor -eq 'GenuineIntel')
}
