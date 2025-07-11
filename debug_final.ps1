<#
.SYNOPSIS
Execute un script PowerShell à distance et maintient la session active pendant 24 heures.

.DESCRIPTION
Ce script permet d'exécuter un script sur une machine distante et maintient délibérément
la session ouverte pendant 24 heures pour des besoins spécifiques.
#>
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "Le chemin $_ pour le script à exécuter n'existe pas."
        }
        if (-not $_.EndsWith('.ps1')) {
            throw "Le fichier spécifié doit être un script PowerShell (.ps1)"
        }
        $true
    })]
    [string]$scriptPath,

    [string]$argumentList,
    [switch]$background,
    [int]$sessionTimeout = 86430, # 24h + 30s marge
    [string]$logFile
)

# Configuration initiale
$ErrorActionPreference = "Stop"
$startTime = Get-Date
$executionId = [guid]::NewGuid().ToString()

function Write-Log {
    param ([string]$message, [string]$level = "INFO")
    $logMessage = "[$level][$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $message"
    if ($logFile) {
        Add-Content -Path $logFile -Value $logMessage
    }
    Write-Host $logMessage
}

try {
    # Récupération des credentials
    $username = $env:SVC_USERNAME
    $securePassword = ConvertTo-SecureString $env:SVC_PASSWORD -AsPlainText -Force
    $environmentType = $env:TYPE_ENV
    
    if (-not $username -or -not $securePassword -or -not $environmentType) {
        throw "Variables d'environnement requises non définies."
    }

    $credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securePassword
    $sessionParams = @{
        Credential = $credentials
        SessionOption = New-PSSessionOption -IdleTimeout ($sessionTimeout * 1000)
    }

    if ($environmentType -ne "D") {
        $sessionParams.Add("Authentication", "Credssp")
    }

    Write-Log "Création de la session avec maintien pour 24h..."
    $session = New-PSSession @sessionParams -ErrorAction Stop

    # Construction du ScriptBlock avec maintien de session
    $scriptContent = Get-Content -Path $scriptPath -Raw
    $scriptBlockContent = @"
        `$startTime = Get-Date
        Write-Output "Début de l'exécution à `$(`$startTime)"
        
        # Execution du script original
        & { $scriptContent } $argumentList
        
        # Maintenance de session
        Write-Output "Mise en veille pour 24 heures pour maintenir la session active..."
        Start-Sleep -Seconds 86400  # 24 heures
        
        Write-Output "Fin de la période de veille à `$(Get-Date)"
        Write-Output "Durée totale: `$((Get-Date) - `$startTime)"
"@

    $scriptBlock = [scriptblock]::Create($scriptBlockContent)

    # Exécution
    if ($background) {
        $job = Invoke-Command -Session $session -ScriptBlock $scriptBlock -AsJob -JobName "RemoteKeepAlive_$executionId"
        Write-Log "Script exécuté en arrière-plan avec maintien de session. Job ID: $($job.Id)"
        Write-Output @{
            JobId = $job.Id
            ExecutionId = $executionId
            Status = "StartedWithKeepAlive"
        }
    }
    else {
        Write-Log "Début de l'exécution avec maintien de session..."
        $output = Invoke-Command -Session $session -ScriptBlock $scriptBlock -ErrorAction Stop
        Write-Output $output
    }
}
catch {
    Write-Log "ERREUR: $_" -level "ERROR"
    throw
}
finally {
    if (-not $background -and $session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}
