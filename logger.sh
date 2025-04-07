#!/bin/bash

## Logger Basique - 3 Niveaux ##

# Configuration
NIVEAU_LOG="INFO"  # DEBUG, INFO ou ERREUR
FICHIER_LOG=""     # Chemin vers un fichier (vide = console seulement)

# Fonction de log interne
_log() {
    local niveau=$1
    local message=$2
    local date_heure=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Format de sortie
    local sortie="[$date_heure] [$niveau] $message"
    
    # Écriture dans le fichier si spécifié
    [ -n "$FICHIER_LOG" ] && echo "$sortie" >> "$FICHIER_LOG"
    
    # Affichage console
    case $niveau in
        "ERREUR") echo "$sortie" >&2 ;;  # Sortie d'erreur
        *)        echo "$sortie" ;;       # Sortie standard
    esac
}

# Fonctions exportées
debug() { 
    [ "$NIVEAU_LOG" = "DEBUG" ] && _log "DEBUG" "$1" 
}

info() { 
    [ "$NIVEAU_LOG" != "ERREUR" ] && _log "INFO" "$1" 
}

erreur() { 
    _log "ERREUR" "$1" 
}

## Exemple d'utilisation ##
# debug "Message de debug"   # Visible seulement si NIVEAU_LOG=DEBUG
# info "Message d'info"      # Visible si NIVEAU_LOG=DEBUG ou INFO
# erreur "Message d'erreur"  # Toujours visible
