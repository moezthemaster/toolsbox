<#
.SYNOPSIS
Standalone PowerShell script for remote session management with {{VARIABLE}} placeholders

.DESCRIPTION
Features:
- Remote script execution in foreground/background modes
- 24-hour session persistence in background mode
- Secure credential handling via placeholders
- Simple and effective logging
#>

param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$ScriptPath,

    [string]$ArgumentList,
    [switch]$Background,
    [string]$LogPath = "{{LOG_PATH}}"
)

### CONFIGURATION ###
$username    = "{{SVC_USERNAME}}"
$password    = "{{SVC_PASSWORD}}"
$environment = "{{ENV_TYPE}}"

### INTEGRATED FUNCTIONS ###
function Test-Placeholders {
    param([hashtable]$Vars)
    foreach ($key in $Vars.Keys) {
        if ($Vars[$key] -match '^\{\{.+}}$') {
            throw "ERROR: Unreplaced placeholder detected ($key = $($Vars[$key]))"
        }
    }
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARNING","ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$Level] $Message"
    
    Write-Host $logEntry
    if (-not [string]::IsNullOrEmpty($LogPath)) {
        Add-Content -Path $LogPath -Value $logEntry
    }
}

function New-RemoteSession {
    param(
        [PSCredential]$Credential,
        [string]$EnvironmentType,
        [int]$TimeoutHours = 24
    )
    
    $sessionParams = @{
        Credential     = $Credential
        SessionOption  = New-PSSessionOption -IdleTimeout ($TimeoutHours * 3600 * 1000)
        ErrorAction    = 'Stop'
    }

    if ($EnvironmentType -ne "D") {
        $sessionParams.Add("Authentication", "CredSSP")
        Write-Log "CredSSP authentication enabled" -Level "INFO"
    }

    try {
        $session = New-PSSession @sessionParams
        Write-Log "Session created on $($session.ComputerName)" -Level "INFO"
        return $session
    }
    catch {
        Write-Log "Failed to create session: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Start-KeepAliveJob {
    param(
        [System.Management.Automation.Runspaces.PSSession]$Session,
        [string]$ScriptPath,
        [string]$Arguments,
        [string]$JobName
    )
    
    $scriptBlock = {
        param($path, $args)
        try {
            & $path $args
            Write-Output "Script executed successfully - Maintaining session for 24h"
            Start-Sleep -Seconds 86400
        }
        catch {
            Write-Output "ERROR: $($_.Exception.Message)"
            throw
        }
    }

    $job = Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList $ScriptPath, $Arguments -AsJob -JobName $JobName
    Write-Log "Background job started (JobID: $($job.Id))" -Level "INFO"
    return $job
}

### MAIN EXECUTION ###
try {
    # Validate placeholders
    Test-Placeholders @{
        Username = $username
        Password = $password
        EnvType  = $environment
    }

    # Prepare credentials
    $securePass = ConvertTo-SecureString $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($username, $securePass)

    # Create session
    $session = New-RemoteSession -Credential $credential -EnvironmentType $environment

    # Execution
    if ($Background) {
        $jobName = "RemoteJob_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        $job = Start-KeepAliveJob -Session $session -ScriptPath $ScriptPath -Arguments $ArgumentList -JobName $jobName
        Write-Host "→ Job started with ID: $($job.Id)"
    }
    else {
        Invoke-Command -Session $session -ScriptBlock {
            param($path, $args)
            & $path $args
        } -ArgumentList $ScriptPath, $ArgumentList
    }
}
catch {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
finally {
    # Cleanup session in foreground mode
    if ((-not $Background) -and ($null -ne $session)) {
        Remove-PSSession $session -ErrorAction SilentlyContinue
        Write-Log "Session closed" -Level "INFO"
    }
}
