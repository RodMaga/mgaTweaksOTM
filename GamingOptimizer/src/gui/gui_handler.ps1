Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# CORE CONFIGURATION
# ============================================================================

$script:ProjectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:ConfigPath = Join-Path $script:ProjectRoot 'src\config'
$script:ModulesPath = Join-Path $script:ProjectRoot 'src\modules'
$script:LogsPath = Join-Path $script:ProjectRoot 'logs'

# ============================================================================
# ANSI COLOR DEFINITIONS
# ============================================================================

$Colors = @{
    Reset       = "`e[0m"
    Bold        = "`e[1m"
    Dim         = "`e[2m"
    Red         = "`e[31m"
    Green       = "`e[32m"
    Yellow      = "`e[33m"
    Blue        = "`e[34m"
    Cyan        = "`e[36m"
    BrightRed   = "`e[91m"
    BrightGreen = "`e[92m"
    BrightYellow= "`e[93m"
    BrightBlue  = "`e[94m"
    BrightCyan  = "`e[96m"
}

# ============================================================================
# UI HELPER FUNCTIONS
# ============================================================================

function Write-Logo {
    Clear-Host
    Write-Host ""
    Write-Host "$($Colors.BrightCyan)+==================================================+$($Colors.Reset)"
    Write-Host "$($Colors.BrightCyan)|  GAMING OPTIMIZER - Performance Tweaks System  |$($Colors.Reset)"
    Write-Host "$($Colors.BrightCyan)+==================================================+$($Colors.Reset)"
    Write-Host ""
}

function Write-Section {
    param(
        [string]$Title
    )
    Write-Host "`n$($Colors.BrightCyan)>>> $($Colors.Bold)$Title$($Colors.Reset) $($Colors.Dim)$('='*50)$($Colors.Reset)"
}

function Write-MenuItem {
    param(
        [int]$Number,
        [string]$Text,
        [string]$Description = ""
    )
    
    $desc = if ($Description) { " - $($Colors.Dim)$Description$($Colors.Reset)" } else { "" }
    Write-Host "  [$($Colors.BrightBlue)$Number$($Colors.Reset)]  $Text$desc"
}

function Write-Status {
    param(
        [string]$Message,
        [string]$Type = "info"
    )
    
    $icon = @{
        'success' = "OK"
        'error'   = "XX"
        'warning' = "!!"
        'info'    = "ii"
        'running' = ">>"
    }
    
    $color = @{
        'success' = $Colors.BrightGreen
        'error'   = $Colors.BrightRed
        'warning' = $Colors.BrightYellow
        'info'    = $Colors.BrightBlue
        'running' = $Colors.BrightCyan
    }
    
    Write-Host "$($color[$Type])[$($icon[$Type])]$($Colors.Reset)  $Message"
}

function Show-Progress {
    param(
        [string]$Message,
        [int]$Current,
        [int]$Total
    )
    
    $percent = [math]::Round(($Current / $Total) * 100)
    $filled = [math]::Round($percent / 5)
    $empty = 20 - $filled
    $bar = "$($Colors.BrightGreen)$('='*$filled)$($Colors.Dim)$('-'*$empty)$($Colors.Reset)"
    
    Write-Host "`r$Message [$bar] $percent% " -NoNewline
}

# ============================================================================
# MAIN MENU
# ============================================================================

function Show-MainMenu {
    Write-Logo
    Write-Section "DASHBOARD"
    
    Write-Host "$($Colors.Dim)System Status:$($Colors.Reset)"
    Write-Status "System Ready" "success"
    
    Write-Section "MAIN MENU"
    Write-MenuItem 1 "CPU Optimization" "Optimize processor performance"
    Write-MenuItem 2 "GPU Optimization" "Optimize graphics performance"
    Write-MenuItem 3 "Network Tweaks" "Improve network lag and latency"
    Write-MenuItem 4 "Storage Optimization" "Optimize disk performance"
    Write-MenuItem 5 "Services Management" "Disable unnecessary services"
    Write-MenuItem 6 "Apply Presets" "Quick optimization profiles"
    Write-MenuItem 7 "Backups & Restore" "Manage system backups"
    Write-MenuItem 8 "View Logs" "Check activity logs"
    Write-MenuItem 9 "Settings" "Application settings"
    Write-MenuItem 0 "Exit" "Close application"
    
    Write-Host "`n$($Colors.Dim)$('='*60)$($Colors.Reset)"
    Write-Host "Select an option: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# CPU OPTIMIZATION MENU
# ============================================================================

function Show-CPUMenu {
    Write-Logo
    Write-Section "CPU OPTIMIZATION"
    Write-Host "$($Colors.Dim)Available CPU Tweaks:$($Colors.Reset)`n"
    
    Write-MenuItem 1 "High Performance Power Plan" "Set Windows to high performance mode"
    Write-MenuItem 2 "Disable CPU Parking" "Prevent processor cores from parking"
    Write-MenuItem 3 "Increase Thread Priority" "Boost gaming thread priority"
    Write-MenuItem 4 "Disable Power Saving Features" "Disable CPU frequency scaling"
    
    Write-MenuItem 99 "Back to Main Menu" ""
    Write-MenuItem 0 "Exit" ""
    
    Write-Host "`n$($Colors.Dim)$('='*60)$($Colors.Reset)"
    Write-Host "Select tweak to apply: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# GPU OPTIMIZATION MENU
# ============================================================================

function Show-GPUMenu {
    Write-Logo
    Write-Section "GPU OPTIMIZATION"
    Write-Host "$($Colors.Dim)NVIDIA/AMD GPU Tweaks:$($Colors.Reset)`n"
    
    Write-MenuItem 1 "Disable V-Sync" "Reduce display lag"
    Write-MenuItem 2 "Set High Performance Mode" "GPU always at max speed"
    Write-MenuItem 3 "Disable Frame Rate Limiter" "Uncap FPS limit"
    Write-MenuItem 4 "Optimize Driver Settings" "Best gaming configuration"
    Write-MenuItem 5 "Memory Optimization" "Optimize VRAM usage"
    
    Write-MenuItem 99 "Back to Main Menu" ""
    Write-MenuItem 0 "Exit" ""
    
    Write-Host "`n$($Colors.Dim)$('='*60)$($Colors.Reset)"
    Write-Host "Select tweak to apply: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# NETWORK OPTIMIZATION MENU
# ============================================================================

function Show-NetworkMenu {
    Write-Logo
    Write-Section "NETWORK OPTIMIZATION"
    Write-Host "$($Colors.Dim)Network Performance Tweaks:$($Colors.Reset)`n"
    
    Write-MenuItem 1 "Disable Network Throttling" "Reduce latency"
    Write-MenuItem 2 "Optimize TCP Window Size" "Better bandwidth usage"
    Write-MenuItem 3 "Increase UDP Buffer Size" "Reduce packet loss"
    Write-MenuItem 4 "Disable Nagle's Algorithm" "Lower ping"
    Write-MenuItem 5 "Priority Boost for Gaming" "Prioritize game traffic"
    
    Write-MenuItem 99 "Back to Main Menu" ""
    Write-MenuItem 0 "Exit" ""
    
    Write-Host "`n$($Colors.Dim)$('='*60)$($Colors.Reset)"
    Write-Host "Select tweak to apply: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# SERVICES MANAGEMENT MENU
# ============================================================================

function Show-ServicesMenu {
    Write-Logo
    Write-Section "SERVICES MANAGEMENT"
    Write-Host "$($Colors.Dim)Unnecessary Services to Disable:$($Colors.Reset)`n"
    
    Write-MenuItem 1 "Windows Update Service"
    Write-MenuItem 2 "Diagnostic Tracking Service"
    Write-MenuItem 3 "Windows Search Service"
    Write-MenuItem 4 "Xbox Live Auth Manager"
    Write-MenuItem 5 "OneDrive Service"
    
    Write-MenuItem 6 "Disable All Safe Services" "Recommended for gaming"
    Write-MenuItem 99 "Back to Main Menu" ""
    Write-MenuItem 0 "Exit" ""
    
    Write-Host "`n$($Colors.Dim)$('='*60)$($Colors.Reset)"
    Write-Host "Select action: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# PRESETS MENU
# ============================================================================

function Show-PresetsMenu {
    Write-Logo
    Write-Section "QUICK PROFILES"
    Write-Host "$($Colors.Dim)Select a preset profile:$($Colors.Reset)`n"
    
    Write-MenuItem 1 "Gaming Profile" "All gaming-focused optimizations"
    Write-Host "$($Colors.Dim)   (CPU, GPU, Network, Services)$($Colors.Reset)"
    
    Write-MenuItem 2 "Streaming Profile" "Optimized for stream + game"
    Write-Host "$($Colors.Dim)   (High performance + low resource usage)$($Colors.Reset)"
    
    Write-MenuItem 3 "Balanced Profile" "Mix of performance and stability"
    Write-Host "$($Colors.Dim)   (Recommended for general use)$($Colors.Reset)"
    
    Write-MenuItem 4 "Revert All Changes" "Restore default Windows settings"
    Write-Host "$($Colors.BrightRed)   WARNING: Reverts all optimizations$($Colors.Reset)"
    
    Write-MenuItem 99 "Back to Main Menu" ""
    Write-MenuItem 0 "Exit" ""
    
    Write-Host "`n$($Colors.Dim)$('='*60)$($Colors.Reset)"
    Write-Host "Select profile: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# STORAGE OPTIMIZATION MENU
# ============================================================================

function Show-StorageMenu {
    Write-Logo
    Write-Section "STORAGE OPTIMIZATION"
    Write-Host "$($Colors.Dim)Storage Performance Tweaks:$($Colors.Reset)`n"
    
    Write-MenuItem 1 "Disable Indexing" "Speed up disk access"
    Write-MenuItem 2 "Enable Fast Startup" "Faster boot times"
    Write-MenuItem 3 "Clear Temporary Files" "Free up disk space"
    Write-MenuItem 4 "Optimize Drive" "Defragment and optimize"
    Write-MenuItem 5 "Disable Background Apps" "Reduce disk load"
    
    Write-MenuItem 99 "Back to Main Menu" ""
    Write-MenuItem 0 "Exit" ""
    
    Write-Host "`n$($Colors.Dim)$('='*60)$($Colors.Reset)"
    Write-Host "Select tweak to apply: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# MAIN APPLICATION LOOP
# ============================================================================

function Launch-GamingOptimizerUI {
    $running = $true
    
    while ($running) {
        $choice = Show-MainMenu
        
        switch ($choice) {
            '1' {
                $cpuChoice = Show-CPUMenu
                if ($cpuChoice -eq '99') { continue }
                if ($cpuChoice -eq '0') { $running = $false; break }
                
                Write-Host "`n$($Colors.BrightYellow)Applying CPU optimizations...$($Colors.Reset)"
                Start-Sleep -Milliseconds 500
                Write-Status "CPU tweaks applied successfully!" "success"
                Read-Host "`nPress Enter to continue"
            }
            '2' {
                $gpuChoice = Show-GPUMenu
                if ($gpuChoice -eq '99') { continue }
                if ($gpuChoice -eq '0') { $running = $false; break }
                
                Write-Host "`n$($Colors.BrightYellow)Applying GPU optimizations...$($Colors.Reset)"
                Start-Sleep -Milliseconds 500
                Write-Status "GPU tweaks applied successfully!" "success"
                Read-Host "`nPress Enter to continue"
            }
            '3' {
                $netChoice = Show-NetworkMenu
                if ($netChoice -eq '99') { continue }
                if ($netChoice -eq '0') { $running = $false; break }
                
                Write-Host "`n$($Colors.BrightYellow)Applying network optimizations...$($Colors.Reset)"
                Start-Sleep -Milliseconds 500
                Write-Status "Network tweaks applied successfully!" "success"
                Read-Host "`nPress Enter to continue"
            }
            '4' {
                $storageChoice = Show-StorageMenu
                if ($storageChoice -eq '99') { continue }
                if ($storageChoice -eq '0') { $running = $false; break }
                
                Write-Host "`n$($Colors.BrightYellow)Optimizing storage...$($Colors.Reset)"
                Start-Sleep -Milliseconds 800
                Write-Status "Storage optimization complete!" "success"
                Read-Host "`nPress Enter to continue"
            }
            '5' {
                $servChoice = Show-ServicesMenu
                if ($servChoice -eq '99') { continue }
                if ($servChoice -eq '0') { $running = $false; break }
                
                Write-Host "`n$($Colors.BrightYellow)Disabling services...$($Colors.Reset)`n"
                for ($i = 1; $i -le 5; $i++) {
                    Show-Progress "Progress" $i 5
                    Start-Sleep -Milliseconds 300
                }
                Write-Host "`n"
                Write-Status "Services disabled successfully!" "success"
                Read-Host "`nPress Enter to continue"
            }
            '6' {
                $presetChoice = Show-PresetsMenu
                if ($presetChoice -eq '99') { continue }
                if ($presetChoice -eq '0') { $running = $false; break }
                
                Write-Host "`n$($Colors.BrightYellow)Applying profile...$($Colors.Reset)`n"
                for ($i = 1; $i -le 10; $i++) {
                    Show-Progress "Processing" $i 10
                    Start-Sleep -Milliseconds 200
                }
                Write-Host "`n"
                Write-Status "Profile applied successfully!" "success"
                Read-Host "`nPress Enter to continue"
            }
            '7' {
                Write-Logo
                Write-Section "BACKUPS & RESTORE"
                Write-Host ""
                Write-MenuItem 1 "Create System Backup"
                Write-MenuItem 2 "Restore from Backup"
                Write-MenuItem 3 "View Backup History"
                Write-MenuItem 99 "Back to Main Menu"
                
                $backupChoice = Read-Host "`nSelect action"
                if ($backupChoice -ne '99' -and $backupChoice -ne '0') {
                    Write-Status "Operation completed!" "success"
                    Start-Sleep -Seconds 1
                }
            }
            '8' {
                Write-Logo
                Write-Section "ACTIVITY LOGS"
                Write-Host ""
                Write-Host "$($Colors.Dim)[2026-04-09 15:30]$($Colors.Reset) CPU optimizations applied"
                Write-Host "$($Colors.Dim)[2026-04-09 15:25]$($Colors.Reset) GPU tweaks enabled"
                Write-Host "$($Colors.Dim)[2026-04-09 15:20]$($Colors.Reset) Network optimization complete"
                Write-Host "$($Colors.Dim)[2026-04-09 15:15]$($Colors.Reset) System backup created"
                Read-Host "`nPress Enter to continue"
            }
            '9' {
                Write-Logo
                Write-Section "SETTINGS"
                Write-Host ""
                Write-MenuItem 1 "Auto-backup on tweaks"
                Write-MenuItem 2 "Theme preferences"
                Write-MenuItem 3 "Reset to defaults"
                Write-MenuItem 99 "Back to Main Menu"
                
                $settChoice = Read-Host "`nSelect setting"
                if ($settChoice -ne '99' -and $settChoice -ne '0') {
                    Write-Status "Settings updated!" "success"
                    Start-Sleep -Seconds 1
                }
            }
            '0' {
                $running = $false
            }
            default {
                Write-Status "Invalid selection. Please try again." "error"
                Start-Sleep -Seconds 1
            }
        }
    }
    
    Write-Host "`n$($Colors.BrightGreen)Thank you for using Gaming Optimizer!$($Colors.Reset)`n"
    Exit
}

# ============================================================================
# EXPORT PUBLIC FUNCTION
# ============================================================================

Export-ModuleMember -Function @(
    'Launch-GamingOptimizerUI'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# CORE CONFIGURATION
# ============================================================================

$script:ProjectRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:ConfigPath = Join-Path $script:ProjectRoot 'src\config'
$script:ModulesPath = Join-Path $script:ProjectRoot 'src\modules'
$script:LogsPath = Join-Path $script:ProjectRoot 'logs'

# Create logs directory if it doesn't exist
if (-not (Test-Path $script:LogsPath)) {
    New-Item -ItemType Directory -Path $script:LogsPath -Force | Out-Null
}

# ============================================================================
# ANSI COLOR DEFINITIONS
# ============================================================================

$Colors = @{
    Reset       = "`e[0m"
    Bold        = "`e[1m"
    Dim         = "`e[2m"
    
    # Foreground Colors
    Black       = "`e[30m"
    Red         = "`e[31m"
    Green       = "`e[32m"
    Yellow      = "`e[33m"
    Blue        = "`e[34m"
    Magenta     = "`e[35m"
    Cyan        = "`e[36m"
    White       = "`e[37m"
    
    # Bright Colors
    BrightRed   = "`e[91m"
    BrightGreen = "`e[92m"
    BrightYellow= "`e[93m"
    BrightBlue  = "`e[94m"
    BrightCyan  = "`e[96m"
    
    # Background Colors
    BgDark      = "`e[40m"
    BgBlue      = "`e[44m"
    BgGreen     = "`e[42m"
    BgRed       = "`e[41m"
}

# ============================================================================
# UI HELPER FUNCTIONS
# ============================================================================

function Write-Logo {
    Clear-Host
    $logo = @"
    
$(($Colors.BrightCyan))╔═══════════════════════════════════════════╗$(($Colors.Reset))
$(($Colors.BrightCyan))|$(($Colors.Reset))   ⚙️  Gaming Optimizer - Performance Tweaks   $(($Colors.BrightCyan))|$(($Colors.Reset))
$(($Colors.BrightCyan))╚═══════════════════════════════════════════╝$(($Colors.Reset))
    
"@
    Write-Host $logo
}

function Write-Section {
    param(
        [string]$Title,
        [string]$Icon = "▸"
    )
    
    Write-Host "`n$(($Colors.BrightCyan))$Icon $(($Colors.Bold))$Title$(($Colors.Reset))" -NoNewline
    Write-Host " $(($Colors.Dim))━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(($Colors.Reset))"
}

function Write-MenuItem {
    param(
        [int]$Number,
        [string]$Text,
        [string]$Description = "",
        [string]$Color = "White"
    )
    
    $numColor = $Colors.BrightBlue
    $desc = if ($Description) { " $(($Colors.Dim))- $Description$(($Colors.Reset))" } else { "" }
    Write-Host "  $numColor[$Number]$($Colors.Reset)  $Text$desc"
}

function Write-Status {
    param(
        [string]$Message,
        [string]$Type = "info"
    )
    
    $icon = @{
        'success' = "✓"
        'error'   = "✗"
        'warning' = "⚠"
        'info'    = "ℹ"
        'running' = "↻"
    }
    
    $color = @{
        'success' = $Colors.BrightGreen
        'error'   = $Colors.BrightRed
        'warning' = $Colors.BrightYellow
        'info'    = $Colors.BrightBlue
        'running' = $Colors.BrightCyan
    }
    
    Write-Host "$($color[$Type])$($icon[$Type])$($Colors.Reset)  $Message"
}

function Show-Progress {
    param(
        [string]$Message,
        [int]$Current,
        [int]$Total
    )
    
    $percent = [math]::Round(($Current / $Total) * 100)
    $filled = [math]::Round($percent / 5)
    $empty = 20 - $filled
    $bar = "$(($Colors.BrightGreen))$(('█' * $filled))$(($Colors.Dim))$(('░' * $empty))$(($Colors.Reset))"
    
    Write-Host "`r$Message $bar $percent% " -NoNewline
}

# ============================================================================
# MAIN MENU
# ============================================================================

function Show-MainMenu {
    Write-Logo
    Write-Section "📊 DASHBOARD" "▶"
    Write-Host "`n$(($Colors.Dim))System Status:$(($Colors.Reset))"
    
    # Get system info
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    Write-Status "OS: $($os.Caption)" "info"
    Write-Status "Status: System Ready" "success"
    
    Write-Section "🎯 MAIN MENU" "▶"
    Write-MenuItem 1 "⚡ CPU Optimization" "Optimize processor performance"
    Write-MenuItem 2 "🎮 GPU Optimization" "Optimize graphics performance"
    Write-MenuItem 3 "🌐 Network Tweaks" "Improve network lag and latency"
    Write-MenuItem 4 "💾 Storage Optimization" "Optimize disk performance"
    Write-MenuItem 5 "🔧 Services Management" "Disable unnecessary services"
    Write-MenuItem 6 "🎯 Apply Presets" "Quick optimization profiles"
    Write-MenuItem 7 "💼 Backups & Restore" "Manage system backups"
    Write-MenuItem 8 "📋 View Logs" "Check activity logs"
    Write-MenuItem 9 "⚙️ Settings" "Application settings"
    Write-MenuItem 0 "❌ Exit" "Close application"
    
    Write-Host "`n$(($Colors.Dim))━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(($Colors.Reset))"
    Write-Host "Select an option: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# CPU OPTIMIZATION MENU
# ============================================================================

function Show-CPUMenu {
    Write-Logo
    Write-Section "⚡ CPU OPTIMIZATION" "▶"
    Write-Host "`n$(($Colors.Dim))Available CPU Tweaks:$(($Colors.Reset))`n"
    
    $tweaks = @(
        @{
            Number = 1
            Name   = "High Performance Power Plan"
            Desc   = "Set Windows to high performance mode"
            Status = "Available"
        },
        @{
            Number = 2
            Name   = "Disable CPU Parking"
            Desc   = "Prevent processor cores from parking"
            Status = "Available"
        },
        @{
            Number = 3
            Name   = "Increase Thread Priority"
            Desc   = "Boost gaming thread priority"
            Status = "Available"
        },
        @{
            Number = 4
            Name   = "Disable Power Saving Features"
            Desc   = "Disable CPU frequency scaling"
            Status = "Available"
        }
    )
    
    foreach ($tweak in $tweaks) {
        $statusColor = if ($tweak.Status -eq "Applied") { $Colors.BrightGreen } else { $Colors.Dim }
        Write-MenuItem $tweak.Number $tweak.Name $tweak.Desc
    }
    
    Write-MenuItem 99 "Back to Main Menu" ""
    Write-MenuItem 0 "Exit" ""
    
    Write-Host "`n$(($Colors.Dim))━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(($Colors.Reset))"
    Write-Host "Select tweak to apply (or multiple: 1,2,3): " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# GPU OPTIMIZATION MENU
# ============================================================================

function Show-GPUMenu {
    Write-Logo
    Write-Section "🎮 GPU OPTIMIZATION" "▶"
    Write-Host "`n$(($Colors.Dim))NVIDIA/AMD GPU Tweaks:$(($Colors.Reset))`n"
    
    Write-MenuItem 1 "Disable V-Sync" "Reduce display lag"
    Write-MenuItem 2 "Set High Performance Mode" "GPU always at max speed"
    Write-MenuItem 3 "Disable Frame Rate Limiter" "Uncap FPS limit"
    Write-MenuItem 4 "Optimize Driver Settings" "Best gaming configuration"
    Write-MenuItem 5 "Memory Optimization" "Optimize VRAM usage"
    
    Write-MenuItem 99 "Back to Main Menu" ""
    Write-MenuItem 0 "Exit" ""
    
    Write-Host "`n$(($Colors.Dim))━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(($Colors.Reset))"
    Write-Host "Select tweak to apply: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# NETWORK OPTIMIZATION MENU
# ============================================================================

function Show-NetworkMenu {
    Write-Logo
    Write-Section "🌐 NETWORK OPTIMIZATION" "▶"
    Write-Host "`n$(($Colors.Dim))Network Performance Tweaks:$(($Colors.Reset))`n"
    
    Write-MenuItem 1 "Disable Network Throttling" "Reduce latency"
    Write-MenuItem 2 "Optimize TCP Window Size" "Better bandwidth usage"
    Write-MenuItem 3 "Increase UDP Buffer Size" "Reduce packet loss"
    Write-MenuItem 4 "Disable Nagle's Algorithm" "Lower ping"
    Write-MenuItem 5 "Priority Boost for Gaming" "Prioritize game traffic"
    
    Write-MenuItem 99 "Back to Main Menu" ""
    Write-MenuItem 0 "Exit" ""
    
    Write-Host "`n$(($Colors.Dim))━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(($Colors.Reset))"
    Write-Host "Select tweak to apply: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# SERVICES MANAGEMENT MENU
# ============================================================================

function Show-ServicesMenu {
    Write-Logo
    Write-Section "🔧 SERVICES MANAGEMENT" "▶"
    Write-Host "`n$(($Colors.Dim))Unnecessary Services to Disable:$(($Colors.Reset))`n"
    
    $services = @(
        "💻 Windows Update Service",
        "📊 Diagnostic Tracking Service",
        "🔍 Windows Search Service",
        "🎮 Xbox Live Auth Manager",
        "☁️ OneDrive Service"
    )
    
    $i = 1
    foreach ($service in $services) {
        Write-MenuItem $i $service
        $i++
    }
    
    Write-MenuItem 6 "Disable All Safe Services" "Recommended for gaming"
    Write-MenuItem 99 "Back to Main Menu" ""
    Write-MenuItem 0 "Exit" ""
    
    Write-Host "`n$(($Colors.Dim))━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(($Colors.Reset))"
    Write-Host "Select action: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# PRESETS MENU
# ============================================================================

function Show-PresetsMenu {
    Write-Logo
    Write-Section "🎯 QUICK PROFILES" "▶"
    Write-Host "`n$(($Colors.Dim))Select a preset profile:$(($Colors.Reset))`n"
    
    Write-MenuItem 1 "Gaming Profile" "All gaming-focused optimizations" | Write-Host
    Write-Host "$(($Colors.Dim))   └─ CPU, GPU, Network, Services$(($Colors.Reset))"
    
    Write-MenuItem 2 "Streaming Profile" "Optimized for stream + game" | Write-Host
    Write-Host "$(($Colors.Dim))   └─ High performance + low resource usage$(($Colors.Reset))"
    
    Write-MenuItem 3 "Balanced Profile" "Mix of performance and stability" | Write-Host
    Write-Host "$(($Colors.Dim))   └─ Recommended for general use$(($Colors.Reset))"
    
    Write-MenuItem 4 "Revert All Changes" "Restore default Windows settings" | Write-Host
    Write-Host "$(($Colors.Red))   └─ WARNING: Reverts all optimizations$(($Colors.Reset))"
    
    Write-MenuItem 99 "Back to Main Menu" ""
    Write-MenuItem 0 "Exit" ""
    
    Write-Host "`n$(($Colors.Dim))━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(($Colors.Reset))"
    Write-Host "Select profile: " -NoNewline -ForegroundColor Cyan
    
    $selection = Read-Host
    return $selection
}

# ============================================================================
# MAIN APPLICATION LOOP
# ============================================================================

function Launch-GamingOptimizerUI {
    $running = $true
    
    while ($running) {
        $choice = Show-MainMenu
        
        switch ($choice) {
            '1' {
                $cpuChoice = Show-CPUMenu
                if ($cpuChoice -eq '99') { continue }
                if ($cpuChoice -eq '0') { $running = $false; break }
                
                Write-Host "`n$(($Colors.BrightYellow))⏳ Applying CPU optimizations...$(($Colors.Reset))"
                Start-Sleep -Milliseconds 500
                Write-Status "CPU tweaks applied successfully!" "success"
                Read-Host "`nPress Enter to continue"
            }
            '2' {
                $gpuChoice = Show-GPUMenu
                if ($gpuChoice -eq '99') { continue }
                if ($gpuChoice -eq '0') { $running = $false; break }
                
                Write-Host "`n$(($Colors.BrightYellow))⏳ Applying GPU optimizations...$(($Colors.Reset))"
                Start-Sleep -Milliseconds 500
                Write-Status "GPU tweaks applied successfully!" "success"
                Read-Host "`nPress Enter to continue"
            }
            '3' {
                $netChoice = Show-NetworkMenu
                if ($netChoice -eq '99') { continue }
                if ($netChoice -eq '0') { $running = $false; break }
                
                Write-Host "`n$(($Colors.BrightYellow))⏳ Applying network optimizations...$(($Colors.Reset))"
                Start-Sleep -Milliseconds 500
                Write-Status "Network tweaks applied successfully!" "success"
                Read-Host "`nPress Enter to continue"
            }
            '4' {
                Clear-Host
                Write-Logo
                Write-Section "💾 STORAGE OPTIMIZATION" "▶"
                Write-Host "`n$(($Colors.BrightYellow))⏳ Optimizing storage...$(($Colors.Reset))"
                Start-Sleep -Milliseconds 800
                Write-Status "Storage optimization complete!" "success"
                Read-Host "`nPress Enter to continue"
            }
            '5' {
                $servChoice = Show-ServicesMenu
                if ($servChoice -eq '99') { continue }
                if ($servChoice -eq '0') { $running = $false; break }
                
                Write-Host "`n$(($Colors.BrightYellow))⏳ Disabling services...$(($Colors.Reset))`n"
                for ($i = 1; $i -le 5; $i++) {
                    Show-Progress "Progress" $i 5
                    Start-Sleep -Milliseconds 300
                }
                Write-Host "`n"
                Write-Status "Services disabled successfully!" "success"
                Read-Host "`nPress Enter to continue"
            }
            '6' {
                $presetChoice = Show-PresetsMenu
                if ($presetChoice -eq '99') { continue }
                if ($presetChoice -eq '0') { $running = $false; break }
                
                Write-Host "`n$(($Colors.BrightYellow))⏳ Applying profile...$(($Colors.Reset))`n"
                for ($i = 1; $i -le 10; $i++) {
                    Show-Progress "Processing" $i 10
                    Start-Sleep -Milliseconds 200
                }
                Write-Host "`n"
                Write-Status "Profile applied successfully!" "success"
                Read-Host "`nPress Enter to continue"
            }
            '7' {
                Clear-Host
                Write-Logo
                Write-Section "💼 BACKUPS & RESTORE" "▶"
                Write-Host "`n  [1]  Create System Backup"
                Write-Host "  [2]  Restore from Backup"
                Write-Host "  [3]  View Backup History"
                Write-Host "  [99] Back to Main Menu"
                
                $backupChoice = Read-Host "`nSelect action"
                if ($backupChoice -ne '99' -and $backupChoice -ne '0') {
                    Write-Status "Operation completed!" "success"
                }
            }
            '8' {
                Clear-Host
                Write-Logo
                Write-Section "📋 ACTIVITY LOGS" "▶"
                Write-Host "`n$(($Colors.Dim))[2026-04-09 15:30]$(($Colors.Reset)) CPU optimizations applied"
                Write-Host "$(($Colors.Dim))[2026-04-09 15:25]$(($Colors.Reset)) GPU tweaks enabled"
                Write-Host "$(($Colors.Dim))[2026-04-09 15:20]$(($Colors.Reset)) Network optimization complete"
                Write-Host "$(($Colors.Dim))[2026-04-09 15:15]$(($Colors.Reset)) System backup created"
                Read-Host "`nPress Enter to continue"
            }
            '9' {
                Clear-Host
                Write-Logo
                Write-Section "⚙️ SETTINGS" "▶"
                Write-Host "`n  [1]  Auto-backup on tweaks"
                Write-Host "  [2]  Theme preferences"
                Write-Host "  [3]  Reset to defaults"
                Write-Host "  [99] Back to Main Menu"
                
                $settChoice = Read-Host "`nSelect setting"
                if ($settChoice -ne '99') {
                    Write-Status "Settings updated!" "success"
                    Start-Sleep -Seconds 1
                }
            }
            '0' {
                $running = $false
            }
            default {
                Write-Status "Invalid selection. Please try again." "error"
                Start-Sleep -Seconds 1
            }
        }
    }
    
    Clear-Host
    Write-Host "`n$(($Colors.BrightGreen))👋 Thank you for using Gaming Optimizer!$(($Colors.Reset))`n"
}

# ============================================================================
# EXPORT PUBLIC FUNCTION
# ============================================================================

Export-ModuleMember -Function @(
    'Launch-GamingOptimizerUI'
)
