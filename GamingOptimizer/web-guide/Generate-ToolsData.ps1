param(
  [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"

$guidePath = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = Split-Path -Parent $guidePath
}

$dataDir = Join-Path $guidePath "data"
if (-not (Test-Path $dataDir)) {
  New-Item -ItemType Directory -Path $dataDir | Out-Null
}

function Get-Risk([string]$name) {
  if ($name -match "ServiceManager|Apply-KeyboardInputLag") { return "high" }
  if ($name -match "CPU|GPU|Network|Competitive|Streaming") { return "medium" }
  return "low"
}

function Get-Modes([string]$category, [string]$name) {
  if ($name -match "Competitive") { return @("competitive") }
  if ($name -match "Streaming") { return @("streaming") }
  if ($name -match "Apply-KeyboardInputLag") { return @("competitive") }
  if ($name -match "Revert") { return @("safe", "competitive", "streaming") }
  if ($category -eq "Detection" -or $category -eq "Utilities") { return @("safe", "competitive", "streaming") }
  if ($category -eq "Modules") { return @("competitive", "streaming") }
  return @("all")
}

function Get-Tags([string]$path, [string]$name, [string]$category) {
  $tags = New-Object System.Collections.Generic.List[string]

  if ($path -match "cpu") { $tags.Add("CPU") }
  if ($path -match "gpu") { $tags.Add("GPU") }
  if ($path -match "network") { $tags.Add("Network") }
  if ($path -match "storage") { $tags.Add("Storage") }
  if ($path -match "profile") { $tags.Add("Profile") }
  if ($path -match "keyboard") { $tags.Add("Keyboard") }

  if ($category -eq "Detection") { $tags.Add("Detect") }
  if ($category -eq "Utilities") { $tags.Add("Safety") }
  if ($name -match "Service") { $tags.Add("Advanced") }
  if ($name -match "Revert|Restore|Backup|Validation") { $tags.Add("Safety") }

  if ($tags.Count -eq 0) { $tags.Add($category) }
  return @($tags | Select-Object -Unique)
}

function Format-ToolName([string]$rawName) {
  $name = $rawName -replace "-", " "
  $name = $name -creplace "([A-Z]+)([A-Z][a-z])", '$1 $2'
  $name = $name -creplace "([a-z0-9])([A-Z])", '$1 $2'
  return $name.Trim()
}

function New-ToolObject([string]$name, [string]$category, [string]$type, [string]$file, [string]$description, [bool]$admin) {
  return [ordered]@{
    name = $name
    category = $category
    type = $type
    file = $file
    description = $description
    run = ".\\" + ($file -replace "/", "\\")
    risk = Get-Risk $name
    admin = $admin
    tags = @(Get-Tags -path $file -name $name -category $category)
    modes = @(Get-Modes -category $category -name $name)
  }
}

$items = @()

$moduleFiles = Get-ChildItem -Path (Join-Path $ProjectRoot "src/modules") -Filter *.ps1 -ErrorAction SilentlyContinue
foreach ($file in $moduleFiles) {
  $rel = "src/modules/$($file.Name)"
  $name = Format-ToolName ([System.IO.Path]::GetFileNameWithoutExtension($file.Name))
  $items += (New-ToolObject -name $name -category "Modules" -type "PowerShell module" -file $rel -description "Modulo de otimizacao para gaming." -admin $true)
}

$detectionFiles = Get-ChildItem -Path (Join-Path $ProjectRoot "src/detection") -Filter *.ps1 -ErrorAction SilentlyContinue
foreach ($file in $detectionFiles) {
  $rel = "src/detection/$($file.Name)"
  $name = Format-ToolName ([System.IO.Path]::GetFileNameWithoutExtension($file.Name))
  $items += (New-ToolObject -name $name -category "Detection" -type "PowerShell detection" -file $rel -description "Detecao e diagnostico de hardware/sistema." -admin $false)
}

$utilFiles = Get-ChildItem -Path (Join-Path $ProjectRoot "src/utils") -Filter *.ps1 -ErrorAction SilentlyContinue
foreach ($file in $utilFiles) {
  $rel = "src/utils/$($file.Name)"
  $name = Format-ToolName ([System.IO.Path]::GetFileNameWithoutExtension($file.Name))
  $items += (New-ToolObject -name $name -category "Utilities" -type "PowerShell utility" -file $rel -description "Utilitario de suporte e seguranca." -admin $true)
}

$profileManager = Join-Path $ProjectRoot "src/profiles/ProfileManager.ps1"
if (Test-Path $profileManager) {
  $items += (New-ToolObject -name "Profile Manager" -category "Profiles" -type "PowerShell profile" -file "src/profiles/ProfileManager.ps1" -description "Gestao e aplicacao de perfis." -admin $true)
}

$profileFiles = Get-ChildItem -Path (Join-Path $ProjectRoot "src/profiles/default_profiles") -Filter *.json -ErrorAction SilentlyContinue
foreach ($file in $profileFiles) {
  $profileName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
  $title = ($profileName.Substring(0,1).ToUpper() + $profileName.Substring(1)) + " Profile"
  $items += [ordered]@{
    name = $title
    category = "Profiles"
    type = "JSON profile"
    file = "src/profiles/default_profiles/$($file.Name)"
    description = "Perfil predefinido para cenario $profileName."
    run = "Carregado via ProfileManager"
    risk = Get-Risk $title
    admin = $false
    tags = @("Profile", $profileName.Substring(0,1).ToUpper() + $profileName.Substring(1))
    modes = @(Get-Modes -category "Profiles" -name $title)
  }
}

$tweakFiles = Get-ChildItem -Path (Join-Path $ProjectRoot "tweaks") -Recurse -File -Include *.ps1,*.cmd -ErrorAction SilentlyContinue
foreach ($file in $tweakFiles) {
  $relative = $file.FullName.Substring($ProjectRoot.Length + 1).Replace("\\", "/")
  $displayName = Format-ToolName ([System.IO.Path]::GetFileNameWithoutExtension($file.Name))
  $type = if ($file.Extension -eq ".cmd") { "CMD launcher" } else { "PowerShell script" }
  $items += (New-ToolObject -name $displayName -category "Extra Tweaks" -type $type -file $relative -description "Script extra de tweak/revert." -admin $true)
}

$result = [ordered]@{
  generatedAt = (Get-Date).ToString("s")
  tools = $items
}

$outputPath = Join-Path $dataDir "tools.generated.json"
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $outputPath -Encoding UTF8
Write-Host "Generated: $outputPath" -ForegroundColor Green
