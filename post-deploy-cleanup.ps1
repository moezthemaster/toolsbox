<#
.SYNOPSIS
    Script de nettoyage pour supprimer des fichiers et répertoires spécifiques après l'installation d'un composant.

.DESCRIPTION
    Ce script permet de nettoyer un système en supprimant des fichiers et répertoires listés dans un fichier de configuration.
    Il prend en charge plusieurs composants (Python, R, Java, etc.) et permet d'exclure des fichiers ou répertoires spécifiques.
    Le script peut fonctionner en mode simulation (dry-run) pour afficher les actions sans les exécuter.

.PARAMETER composant
    Le composant à nettoyer (par exemple, "python", "R", "java"). Par défaut, "python".

.PARAMETER configPath
    Le chemin du fichier de configuration contenant les listes de suppression et d'exclusion. Par défaut, "C:\Chemin\Vers\blacklist.config".

.PARAMETER logPath
    Le chemin du fichier de log pour enregistrer les actions du script. Par défaut, "C:\Chemin\Vers\cleanup_log.txt".

.PARAMETER DryRun
    Active le mode simulation. Aucune suppression ne sera effectuée, mais les actions seront affichées.

.PARAMETER Help
    Affiche l'aide et les informations d'utilisation du script.

.EXAMPLE
    .\cleanup.ps1 -composant python
    Nettoie les fichiers et répertoires spécifiés pour le composant Python.

.EXAMPLE
    .\cleanup.ps1 -composant R -DryRun
    Affiche les actions de nettoyage pour le composant R sans les exécuter.

.EXAMPLE
    .\cleanup.ps1 -composant java -configPath "C:\Chemin\Vers\autre_config.config" -logPath "C:\Chemin\Vers\autre_log.txt"
    Nettoie les fichiers et répertoires spécifiés pour le composant Java en utilisant un fichier de configuration et un fichier de log personnalisés.

.EXAMPLE
    .\cleanup.ps1 -Help
    Affiche l'aide et les informations d'utilisation du script.

.NOTES
    Auteur : Votre Nom
    Version : 1.2
    Date de création : 2023-10-10
    Dernière modification : 2023-10-10
#>

param (
    [string]$composant = "python",  # Composant à nettoyer
    [string]$configPath = "C:\Chemin\Vers\blacklist.config",  # Chemin du fichier de configuration
    [string]$logPath = "C:\Chemin\Vers\cleanup_log.txt",  # Chemin du fichier de log
    [switch]$DryRun = $false,  # Mode simulation
    [switch]$Help = $false  # Afficher l'aide
)

# Afficher l'aide
if ($Help) {
    Get-Help $PSCommandPath -Full
    exit
}

# Fonction pour écrire dans le log
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "$timestamp [$Level] $Message"
        Add-Content -Path $logPath -Value $logEntry -ErrorAction Stop
        if ($Level -eq "ERROR") {
            Write-Host $logEntry -ForegroundColor Red
        } elseif ($Level -eq "WARNING") {
            Write-Host $logEntry -ForegroundColor Yellow
        } else {
            Write-Host $logEntry
        }
    } catch {
        Write-Host "Erreur lors de l'écriture dans le fichier de log : $_" -ForegroundColor Red
    }
}

# Fonction pour valider les chemins dans le fichier de configuration
function Test-ValidPath {
    param (
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Log -Message "Chemin vide ou invalide : $Path" -Level "ERROR"
        return $false
    }
    if (-not (Test-Path -Path $Path)) {
        Write-Log -Message "Chemin introuvable : $Path" -Level "ERROR"
        return $false
    }
    return $true
}

# Fonction pour vérifier les conflits entre fichiers et répertoires
function Test-PathConflict {
    param (
        [string]$Path
    )
    $isFile = Test-Path -Path $Path -PathType Leaf
    $isDirectory = Test-Path -Path $Path -PathType Container
    if ($isFile -and $isDirectory) {
        Write-Log -Message "Conflit détecté : $Path correspond à la fois à un fichier et à un répertoire." -Level "ERROR"
        return $true
    }
    return $false
}

# Fonction pour convertir les chemins relatifs en chemins absolus
function Get-AbsolutePath {
    param (
        [string]$Path,
        [string]$BasePath = $PWD.Path
    )
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    } else {
        return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($BasePath, $Path))
    }
}

# Fonction pour vérifier si un chemin est exclu
function Is-Excluded {
    param (
        [string]$Path
    )
    # Vérifier les exclusions simples
    foreach ($excludeFile in $excludeFiles) {
        if ($Path -like "*$excludeFile*") {
            return $true
        }
    }
    # Vérifier les exclusions regex
    foreach ($regex in $regexExclude) {
        if ($Path -match $regex) {
            return $true
        }
    }
    return $false
}

# Vérifier si le fichier de configuration existe
if (-not (Test-Path -Path $configPath)) {
    Write-Log -Message "Le fichier de configuration n'existe pas : $configPath" -Level "ERROR"
    exit
}

# Lire le fichier de configuration
try {
    $config = Get-Content -Path $configPath -ErrorAction Stop
} catch {
    Write-Log -Message "Erreur lors de la lecture du fichier de configuration : $_" -Level "ERROR"
    exit
}

# Vérifier si le composant existe dans le fichier de configuration
if (-not ($config -match "\[$composant\]")) {
    Write-Log -Message "Le composant '$composant' n'existe pas dans le fichier de configuration." -Level "ERROR"
    exit
}

# Initialiser les listes
$deleteFiles = @()
$deleteDirectories = @()
$excludeFiles = @()
$excludeDirectories = @()
$regexExclude = @()

# Parser le fichier de configuration
$section = ""
foreach ($line in $config) {
    if ($line -match "^\[(.+)\]$") {
        $section = $matches[1]
    } elseif ($line -match "^file=(.+)$") {
        if ($section -eq $composant) {
            $deleteFiles += $matches[1]
        } elseif ($section -eq "$composant-exclude" -or $section -eq "global-exclude") {
            $excludeFiles += $matches[1]
        }
    } elseif ($line -match "^directory=(.+)$") {
        if ($section -eq $composant) {
            $deleteDirectories += $matches[1]
        } elseif ($section -eq "$composant-exclude" -or $section -eq "global-exclude") {
            $excludeDirectories += $matches[1]
        }
    } elseif ($line -match "^regex-exclude=(.+)$") {
        $regexExclude += [regex]$matches[1]
    }
}

# Mode simulation
if ($DryRun) {
    Write-Log -Message "Mode simulation activé. Aucune suppression ne sera effectuée." -Level "INFO"
}

# Supprimer les fichiers listés
foreach ($file in $deleteFiles) {
    $absolutePath = Get-AbsolutePath -Path $file)
    if (Test-ValidPath -Path $absolutePath) -and -not (Test-PathConflict -Path $absolutePath)) {
        if (-not (Is-Excluded -Path $absolutePath)) {
            try {
                if (-not $DryRun) {
                    Remove-Item -Path $absolutePath -Force -ErrorAction Stop
                }
                Write-Log -Message "Fichier supprimé : $absolutePath" -Level "INFO"
            } catch {
                Write-Log -Message "Erreur lors de la suppression de $absolutePath : $_" -Level "ERROR"
            }
        } else {
            Write-Log -Message "Fichier exclu : $absolutePath" -Level "WARNING"
        }
    } else {
        Write-Log -Message "Fichier introuvable ou conflit : $absolutePath" -Level "ERROR"
    }
}

# Supprimer les répertoires listés
foreach ($directory in $deleteDirectories) {
    $absolutePath = Get-AbsolutePath -Path $directory)
    if (Test-ValidPath -Path $absolutePath) -and -not (Test-PathConflict -Path $absolutePath)) {
        # Parcourir récursivement le répertoire
        Get-ChildItem -Path $absolutePath -Recurse | ForEach-Object {
            if (-not (Is-Excluded -Path $_.FullName)) {
                try {
                    if (-not $DryRun) {
                        Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction Stop
                    }
                    Write-Log -Message "Élément supprimé : $($_.FullName)" -Level "INFO"
                } catch {
                    Write-Log -Message "Erreur lors de la suppression de $($_.FullName) : $_" -Level "ERROR"
                }
            } else {
                Write-Log -Message "Élément exclu : $($_.FullName)" -Level "WARNING"
            }
        }
        # Supprimer le répertoire principal s'il est vide
        if (-not $DryRun -and -not (Get-ChildItem -Path $absolutePath)) {
            try {
                Remove-Item -Path $absolutePath -Force -ErrorAction Stop
                Write-Log -Message "Répertoire supprimé : $absolutePath" -Level "INFO"
            } catch {
                Write-Log -Message "Erreur lors de la suppression du répertoire $absolutePath : $_" -Level "ERROR"
            }
        }
    } else {
        Write-Log -Message "Répertoire introuvable ou conflit : $absolutePath" -Level "ERROR"
    }
}

Write-Log -Message "Nettoyage terminé pour le composant : $composant" -Level "INFO"
