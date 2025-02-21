<#
.SYNOPSIS
    Post-deployment cleanup script to remove specific files and directories.

.DESCRIPTION
    This script cleans up a system by deleting files and directories listed in a configuration file.
    It supports multiple components (Python, R, Java, etc.) and allows excluding specific files or directories.
    The script can run in dry-run mode to display actions without executing them.

.PARAMETER component
    The component to clean up (e.g., "python", "R", "java"). Default is "python".

.PARAMETER configPath
    The path to the configuration file containing the deletion and exclusion lists. Default is "post-deploy-cleanup.config".

.PARAMETER logPath
    The path to the log file to record script actions. Default is "post-deploy-cleanup.log".

.PARAMETER DryRun
    Enables dry-run mode. No deletions will be performed, but actions will be displayed.

.PARAMETER Help
    Displays help and usage information for the script.

.EXAMPLE
    .\post-deploy-cleanup.ps1 -component python
    Cleans up files and directories specified for the Python component.

.EXAMPLE
    .\post-deploy-cleanup.ps1 -component R -DryRun
    Displays cleanup actions for the R component without executing them.

.EXAMPLE
    .\post-deploy-cleanup.ps1 -component java -configPath "C:\Path\To\custom.config" -logPath "C:\Path\To\custom.log"
    Cleans up files and directories specified for the Java component using a custom configuration and log file.

.EXAMPLE
    .\post-deploy-cleanup.ps1 -Help
    Displays help and usage information for the script.

.NOTES
    Author: Your Name
    Version: 1.2
    Created: 2023-10-10
    Last Modified: 2023-10-10
#>

param (
    [string]$component = "python",  # Component to clean up
    [string]$configPath = "post-deploy-cleanup.config",  # Path to the configuration file
    [string]$logPath = "post-deploy-cleanup.log",  # Path to the log file
    [switch]$DryRun = $false,  # Dry-run mode
    [switch]$Help = $false  # Display help
)

# Display help
if ($Help) {
    Get-Help $PSCommandPath -Full
    exit
}

# Function to write to the log
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
        Write-Host "Error writing to log file: $_" -ForegroundColor Red
    }
}

# Function to validate paths in the configuration file
function Test-ValidPath {
    param (
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Log -Message "Empty or invalid path: $Path" -Level "ERROR"
        return $false
    }
    if (-not (Test-Path -Path $Path)) {
        Write-Log -Message "Path not found: $Path" -Level "ERROR"
        return $false
    }
    return $true
}

# Function to check for conflicts between files and directories
function Test-PathConflict {
    param (
        [string]$Path
    )
    $isFile = Test-Path -Path $Path -PathType Leaf
    $isDirectory = Test-Path -Path $Path -PathType Container
    if ($isFile -and $isDirectory) {
        Write-Log -Message "Conflict detected: $Path corresponds to both a file and a directory." -Level "ERROR"
        return $true
    }
    return $false
}

# Function to convert relative paths to absolute paths
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

# Function to check if a path is excluded
function Is-Excluded {
    param (
        [string]$Path
    )
    # Check simple exclusions
    foreach ($excludeFile in $excludeFiles) {
        if ($Path -like "*$excludeFile*") {
            return $true
        }
    }
    # Check regex exclusions
    foreach ($regex in $regexExclude) {
        if ($Path -match $regex) {
            return $true
        }
    }
    return $false
}

# Check if the configuration file exists
if (-not (Test-Path -Path $configPath)) {
    Write-Log -Message "Configuration file not found: $configPath" -Level "ERROR"
    exit
}

# Read the configuration file
try {
    $config = Get-Content -Path $configPath -ErrorAction Stop
} catch {
    Write-Log -Message "Error reading configuration file: $_" -Level "ERROR"
    exit
}

# Check if the component exists in the configuration file
if (-not ($config -match "\[$component\]")) {
    Write-Log -Message "Component '$component' not found in the configuration file." -Level "ERROR"
    exit
}

# Initialize lists
$deleteFiles = @()
$deleteDirectories = @()
$excludeFiles = @()
$excludeDirectories = @()
$regexExclude = @()

# Parse the configuration file
$section = ""
foreach ($line in $config) {
    if ($line -match "^\[(.+)\]$") {
        $section = $matches[1]
    } elseif ($line -match "^file=(.+)$") {
        if ($section -eq $component) {
            $deleteFiles += $matches[1]
        } elseif ($section -eq "$component-exclude" -or $section -eq "global-exclude") {
            $excludeFiles += $matches[1]
        }
    } elseif ($line -match "^directory=(.+)$") {
        if ($section -eq $component) {
            $deleteDirectories += $matches[1]
        } elseif ($section -eq "$component-exclude" -or $section -eq "global-exclude") {
            $excludeDirectories += $matches[1]
        }
    } elseif ($line -match "^regex-exclude=(.+)$") {
        $regexExclude += [regex]$matches[1]
    }
}

# Dry-run mode
if ($DryRun) {
    Write-Log -Message "Dry-run mode enabled. No deletions will be performed." -Level "INFO"
}

# Delete listed files
foreach ($file in $deleteFiles) {
    $absolutePath = Get-AbsolutePath -Path $file)
    if (Test-ValidPath -Path $absolutePath) -and -not (Test-PathConflict -Path $absolutePath)) {
        if (-not (Is-Excluded -Path $absolutePath)) {
            try {
                if (-not $DryRun) {
                    Remove-Item -Path $absolutePath -Force -ErrorAction Stop
                }
                Write-Log -Message "File deleted: $absolutePath" -Level "INFO"
            } catch {
                Write-Log -Message "Error deleting file $absolutePath: $_" -Level "ERROR"
            }
        } else {
            Write-Log -Message "File excluded: $absolutePath" -Level "WARNING"
        }
    } else {
        Write-Log -Message "File not found or conflict: $absolutePath" -Level "ERROR"
    }
}

# Delete listed directories
foreach ($directory in $deleteDirectories) {
    $absolutePath = Get-AbsolutePath -Path $directory)
    if (Test-ValidPath -Path $absolutePath) -and -not (Test-PathConflict -Path $absolutePath)) {
        # Recursively process the directory
        Get-ChildItem -Path $absolutePath -Recurse | ForEach-Object {
            if (-not (Is-Excluded -Path $_.FullName)) {
                try {
                    if (-not $DryRun) {
                        Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction Stop
                    }
                    Write-Log -Message "Item deleted: $($_.FullName)" -Level "INFO"
                } catch {
                    Write-Log -Message "Error deleting item $($_.FullName): $_" -Level "ERROR"
                }
            } else {
                Write-Log -Message "Item excluded: $($_.FullName)" -Level "WARNING"
            }
        }
        # Delete the main directory if it is empty
        if (-not $DryRun -and -not (Get-ChildItem -Path $absolutePath)) {
            try {
                Remove-Item -Path $absolutePath -Force -ErrorAction Stop
                Write-Log -Message "Directory deleted: $absolutePath" -Level "INFO"
            } catch {
                Write-Log -Message "Error deleting directory $absolutePath: $_" -Level "ERROR"
            }
        }
    } else {
        Write-Log -Message "Directory not found or conflict: $absolutePath" -Level "ERROR"
    }
}

Write-Log -Message "Cleanup completed for component: $component" -Level "INFO"
