#!/bin/ksh

##############################################################################
# Script Name: vault_ldap_script.ksh
# Description: Ce script permet de s'authentifier à HashiCorp Vault via LDAP,
#              de récupérer un secret, et de révoquer le token après utilisation.
#              Les arguments peuvent être lus depuis un fichier de configuration
#              avec des sections pour chaque environnement, ou passés en ligne de commande.
#              Le mot de passe peut être passé en clair, en mode interactif, ou chiffré.
#              Si le mot de passe commence par 'enc:', il est déchiffré automatiquement.
#
# Auteur: Votre Nom
# Date de création: 2023-10-15
# Version: 3.1
#
# Utilisation:
#   - Avec fichier de configuration et environnement :
#     ./vault_ldap_script.ksh -c /chemin/vers/config.conf -e INT
#
#   - Avec arguments en ligne de commande :
#     ./vault_ldap_script.ksh -a VAULT_ADDR -u LDAP_USER -w MOT_DE_PASSE -s SECRET_PATH [--decrypt DECRYPT_KEY] [--debug]
#
#   -a : URL de HashiCorp Vault (ex: http://vault.example.com:8200)
#   -u : Nom d'utilisateur LDAP
#   -w : Mot de passe (en clair, 'interactif', ou chiffré avec 'enc:')
#   -s : Chemin du secret dans Vault (ex: secret/data/myapp/config)
#   -c : Fichier de configuration (optionnel)
#   -e : Environnement (ex: INT, PROD) (optionnel)
#   --decrypt : Déchiffrer le mot de passe avant utilisation (avec DECRYPT_KEY)
#   --debug : Activer le mode DEBUG pour des logs détaillés
#
# Prérequis:
#   - Accès à un serveur HashiCorp Vault configuré pour l'authentification LDAP.
#   - Les outils `curl`, `grep`, `sed`, et `awk` doivent être installés.
#   - `openssl` pour le déchiffrement (si --decrypt est utilisé).
#
# Remarques:
#   - Ce script est conçu pour être simple et portable.
#   - Pour une gestion plus avancée des JSON, envisagez d'installer `jq`.
##############################################################################

# Variables globales
VAULT_ADDR=""
LDAP_USER=""
LDAP_PASSWORD=""
SECRET_PATH=""
DECRYPT_MODE=false
CONFIG_FILE=""
ENVIRONMENT=""
DECRYPT_KEY=""
DEBUG_MODE=false
LOG_FILE="vault_ldap_script.log"

# Fonction pour afficher l'aide
usage() {
    echo "Utilisation: $0 [-a VAULT_ADDR] [-u LDAP_USER] [-w MOT_DE_PASSE] [-s SECRET_PATH] [-c CONFIG_FILE] [-e ENVIRONMENT] [--decrypt DECRYPT_KEY] [--debug]"
    echo "  -a : URL de HashiCorp Vault (ex: http://vault.example.com:8200)"
    echo "  -u : Nom d'utilisateur LDAP"
    echo "  -w : Mot de passe (en clair, 'interactif', ou chiffré avec 'enc:')"
    echo "  -s : Chemin du secret dans Vault (ex: secret/data/myapp/config)"
    echo "  -c : Fichier de configuration (optionnel)"
    echo "  -e : Environnement (ex: INT, PROD) (optionnel)"
    echo "  --decrypt : Déchiffrer le mot de passe avant utilisation (avec DECRYPT_KEY)"
    echo "  --debug : Activer le mode DEBUG pour des logs détaillés"
    exit 1
}

# Fonction pour logger les messages
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local log_entry="[$timestamp] [$level] $message"

    # Afficher le message sur la sortie standard
    echo "$log_entry"

    # Écrire le message dans le fichier de log
    echo "$log_entry" >> "$LOG_FILE"
}

# Fonction pour déchiffrer un mot de passe chiffré
decrypt_password() {
    local encrypted_password="$1"
    local decrypted_password

    # Supprimer le préfixe 'enc:' si présent
    if [[ "$encrypted_password" == enc:* ]]; then
        encrypted_password="${encrypted_password#enc:}"
    fi

    # Déchiffrer avec openssl
    decrypted_password=$(echo "$encrypted_password" | openssl enc -d -aes-256-cbc -a -salt -pass pass:"$DECRYPT_KEY" 2>/dev/null)

    if [ $? -ne 0 ]; then
        log "ERROR" "Erreur: Impossible de déchiffrer le mot de passe. Vérifiez la clé de déchiffrement."
        return 1
    fi

    echo "$decrypted_password"
}

# Fonction pour charger la configuration depuis un fichier
load_config() {
    local config_file="$1"
    local environment="$2"

    if [ -f "$config_file" ] && [ -r "$config_file" ]; then
        log "INFO" "Chargement de la configuration pour l'environnement $environment depuis $config_file..."

        # Lire la section correspondant à l'environnement
        in_section=false
        while IFS= read -r line; do
            # Ignorer les commentaires et les lignes vides
            if [[ "$line" =~ ^# || -z "$line" ]]; then
                continue
            fi

            # Détecter la section de l'environnement
            if [[ "$line" =~ ^\[$environment\] ]]; then
                in_section=true
                continue
            elif [[ "$line" =~ ^\[.*\] ]]; then
                in_section=false
                continue
            fi

            # Charger les variables dans la section
            if [ "$in_section" = true ]; then
                eval "$line"
            fi
        done < "$config_file"
    else
        log "ERROR" "Erreur: Fichier de configuration $config_file introuvable ou inaccessible."
        return 1
    fi
}

# Fonction pour lire la clé de déchiffrement
get_decrypt_key() {
    local key="$1"

    if [ -f "$key" ]; then
        log "INFO" "Lecture de la clé de déchiffrement depuis le fichier $key..."
        DECRYPT_KEY=$(cat "$key")
    else
        log "INFO" "Utilisation de la clé de déchiffrement fournie directement."
        DECRYPT_KEY="$key"
    fi
}

# Fonction pour lire les paramètres
read_parameters() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a) VAULT_ADDR="$2"; shift 2 ;;
            -u) LDAP_USER="$2"; shift 2 ;;
            -w) 
                if [ "$2" = "interactif" ]; then
                    echo -n "Entrez le mot de passe LDAP : "
                    stty -echo  # Masquer la saisie
                    read LDAP_PASSWORD
                    stty echo   # Réactiver l'affichage
                    echo ""     # Nouvelle ligne
                else
                    LDAP_PASSWORD="$2"
                fi
                shift 2
                ;;
            -s) SECRET_PATH="$2"; shift 2 ;;
            -c) CONFIG_FILE="$2"; shift 2 ;;
            -e) ENVIRONMENT="$2"; shift 2 ;;
            --decrypt) DECRYPT_MODE=true; DECRYPT_KEY="$2"; shift 2 ;;
            --debug) DEBUG_MODE=true; shift ;;
            *) usage ;;
        esac
    done
}

# Fonction pour valider les paramètres
validate_parameters() {
    if [ -z "$VAULT_ADDR" ] || [ -z "$LDAP_USER" ] || [ -z "$LDAP_PASSWORD" ] || [ -z "$SECRET_PATH" ]; then
        log "ERROR" "Erreur: Les paramètres -a, -u, -w et -s sont obligatoires."
        usage
    fi

    if [ "$DECRYPT_MODE" = true ] && [ -z "$DECRYPT_KEY" ]; then
        log "ERROR" "Erreur: La clé de déchiffrement (DECRYPT_KEY) est requise en mode --decrypt."
        usage
    fi
}

# Fonction pour s'authentifier avec LDAP
authenticate() {
    local username="$1"
    local password="$2"
    local response

    log "INFO" "Authentification avec LDAP..."
    response=$(curl -s -X POST -d "{\"password\": \"$password\"}" \
        -H "Content-Type: application/json" \
        "$VAULT_ADDR/v1/auth/ldap/login/$username")

    if echo "$response" | grep -q "errors"; then
        log "ERROR" "Erreur d'authentification: $response"
        return 1
    fi

    VAULT_TOKEN=$(echo "$response" | grep -o '"client_token":"[^"]*"' | sed 's/"client_token":"\(.*\)"/\1/')
    if [ -z "$VAULT_TOKEN" ]; then
        log "ERROR" "Erreur: Token non trouvé dans la réponse."
        return 1
    fi

    log "INFO" "Authentification réussie. Token récupéré."
}

# Fonction pour récupérer un secret
get_secret() {
    local secret_path="$1"
    local response

    log "INFO" "Récupération du secret depuis $secret_path..."
    response=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" -X GET "$VAULT_ADDR/v1/$secret_path")

    if echo "$response" | grep -q "errors"; then
        log "ERROR" "Erreur lors de la récupération du secret: $response"
        return 1
    fi

    secret_data=$(echo "$response" | grep -o '"data":\{[^}]+\}')
    if [ -z "$secret_data" ]; then
        log "ERROR" "Erreur: Données du secret non trouvées dans la réponse."
        return 1
    fi

    log "INFO" "Secret récupéré avec succès:"
    echo "$secret_data"
}

# Fonction pour révoquer le token
revoke_token() {
    local token="$1"
    local response

    log "INFO" "Révocation du token..."
    response=$(curl -s -X POST -H "X-Vault-Token: $token" "$VAULT_ADDR/v1/auth/token/revoke-self")

    if echo "$response" | grep -q "errors"; then
        log "ERROR" "Erreur lors de la révocation du token: $response"
        return 1
    fi

    log "INFO" "Token révoqué avec succès."
}

# Fonction principale
main() {
    log "INFO" "Début du script."

    # Lire les paramètres de la ligne de commande
    read_parameters "$@"

    # Charger la configuration si un fichier et un environnement sont spécifiés
    if [ -n "$CONFIG_FILE" ] && [ -n "$ENVIRONMENT" ]; then
        load_config "$CONFIG_FILE" "$ENVIRONMENT" || { log "ERROR" "Échec du chargement de la configuration. Arrêt du script."; exit 1; }
    fi

    # Valider les paramètres
    validate_parameters

    # Déchiffrer le mot de passe si nécessaire
    if [[ "$LDAP_PASSWORD" == enc:* ]]; then
        log "INFO" "Déchiffrement du mot de passe chiffré..."
        get_decrypt_key "$DECRYPT_KEY"  # Lire la clé de déchiffrement
        LDAP_PASSWORD=$(decrypt_password "$LDAP_PASSWORD") || { log "ERROR" "Échec du déchiffrement. Arrêt du script."; exit 1; }
    fi

    # Authentification
    authenticate "$LDAP_USER" "$LDAP_PASSWORD" || { log "ERROR" "Échec de l'authentification. Arrêt du script."; exit 1; }

    # Récupérer le secret
    secret=$(get_secret "$SECRET_PATH") || { revoke_token "$VAULT_TOKEN"; log "ERROR" "Échec de la récupération du secret. Arrêt du script."; exit 1; }

    # Afficher le secret
    echo "$secret"

    # Révoquer le token
    revoke_token "$VAULT_TOKEN" || { log "ERROR" "Erreur lors de la révocation du token."; exit 1; }

    log "INFO" "Script terminé avec succès."
}

# Point d'entrée du script
main "$@"
