# Restart the script as administrator if it's not already
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Restarting script with administrator privileges..."
    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Configuration
$firewallRuleName = "Block Steam Network"
$steamPath = "C:\Program Files (x86)\Steam\Steam.exe"  # Change if Steam is elsewhere

function Remove-SteamFirewallRule {
    if (Get-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue) {
        Write-Host ""
        Write-Host "Removing firewall rule..."
        Remove-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue
    }
}

# Set console title
$Host.UI.RawUI.WindowTitle = "Steam Network Isolated"

Write-Host ""
Write-Host "=== Steam Offline Mode Script ==="
Write-Host ""

# Close Steam if it's already running
$steamProcesses = Get-Process steam -ErrorAction SilentlyContinue
if ($steamProcesses) {
    Write-Host "Steam is already running. Forcing shutdown..."
    $steamProcesses | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Check Steam path
if (!(Test-Path $steamPath)) {
    Write-Host "Steam.exe not found at: $steamPath"
    pause
    exit 1
}

try {
    # Add firewall rule
    Write-Host "Adding firewall rule to block Steam..."
    New-NetFirewallRule -DisplayName $firewallRuleName `
        -Direction Outbound `
        -Program $steamPath `
        -Action Block `
        -Profile Any `
        -Enabled True | Out-Null

    # Launch Steam
    Write-Host "Launching Steam..."
    Start-Process -FilePath $steamPath

    Write-Host ""
    Write-Host "Steam is running in isolated network mode."
    Write-Host "Press Enter to close Steam manually."
    Write-Host "Or close Steam yourself to let the script continue."
    Write-Host ""

    # Monitoring loop
    while ($true) {
        Start-Sleep -Milliseconds 500
        if ($Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.VirtualKeyCode -eq 13) {
                Write-Host ""
                Write-Host "Manual shutdown requested. Closing Steam..."
                Get-Process steam -ErrorAction SilentlyContinue | Stop-Process -Force
                break
            }
        }
        if (-not (Get-Process steam -ErrorAction SilentlyContinue)) {
            Write-Host ""
            Write-Host "Steam has exited."
            break
        }
    }
}
finally {
    Remove-SteamFirewallRule
    Write-Host ""
    $response = Read-Host "Do you want to restart Steam with network enabled? (Y/n)"
    $responseLower = $response.ToLower()

    if ($responseLower -notin @("n", "no")) {
        if (Test-Path $steamPath) {
            Write-Host "Restarting Steam..."
            Start-Process -FilePath $steamPath
        }
        else {
            Write-Host "Cannot restart Steam: executable not found at $steamPath"
        }
    } else {
        Write-Host "Steam will not be restarted."
    }
}
