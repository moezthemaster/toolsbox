param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        $path = $_
        if (Test-Path $path) {
            $true
        }
        else {
            throw "The path $path for the script to launch does not exist."
        }
    })]
    [string]$scriptPath,

    [string]$argumentList,
    [switch]$background
)

$username = "{{SVC_USERNAME}}"
$password = "{{SVC_PASSWORD}}"
$environnement = "{{TYPE_ENV}}"

# Création des credentials
$credentials = New-Object System.Management.Automation.PSCredential -ArgumentList @(
    $username,
    (ConvertTo-SecureString -String $password -AsPlainText -Force)
)

# Création de la session distante
if ($environnement -eq "D") {
    $session = New-PSSession -Credential $credentials
} else {
    $session = New-PSSession -Credential $credentials -Authentication Credssp
}

# Génère un nom de tâche basé sur le nom du script
$scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
$taskName = "XLDeploy_$scriptName"

# Préparation des arguments
$escapedArgs = if ($argumentList) { "$scriptPath $argumentList" } else { $scriptPath }
$taskCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$escapedArgs`""

# Génère le log
$logFolder = "$PSScriptRoot\logs"
if (!(Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "$logFolder\${scriptName}_$timestamp.log"

Add-Content -Path $logFile -Value "[$(Get-Date)] - Launching task '$taskName'"
Add-Content -Path $logFile -Value "[$(Get-Date)] - Script: $scriptPath"
if ($argumentList) {
    Add-Content -Path $logFile -Value "[$(Get-Date)] - Arguments: $argumentList"
}
Add-Content -Path $logFile -Value "[$(Get-Date)] - Environment: $environnement"
Add-Content -Path $logFile -Value "[$(Get-Date)] - Task command: $taskCommand"

# Script à exécuter à distance
$scriptBlock = {
    param($taskName, $taskCommand)

    # Supprimer la tâche si elle existe
    schtasks /Query /TN $taskName > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        schtasks /Delete /TN $taskName /F | Out-Null
    }

    # Créer et exécuter la tâche
    schtasks /Create /TN $taskName /TR $taskCommand /SC ONCE /ST 00:00 /RL HIGHEST /F | Out-Null
    schtasks /Run /TN $taskName | Out-Null

    Write-Host "Tâche planifiée '$taskName' lancée avec succès : $taskCommand"
}

# Exécution distante
Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $taskName, $taskCommand | Tee-Object -Variable result

# Log du résultat
$result | ForEach-Object { Add-Content -Path $logFile -Value "[$(Get-Date)] - $_" }

Add-Content -Path $logFile -Value "[$(Get-Date)] - Script execution finished"
Write-Host "Log written to: $logFile"
