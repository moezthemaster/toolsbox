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
# Version: 2.8
#
# Utilisation:
#   - Avec fichier de configuration et environnement :
#     ./vault_ldap_script.ksh -c /chemin/vers/config.conf -e INT
#
#   - Avec arguments en ligne de commande :
#     ./vault_ldap_script.ksh -a VAULT_ADDR -u LDAP_USER -w MOT_DE_PASSE -s SECRET_PATH [--decrypt]
#     ./vault_ldap_script.ksh -a VAULT_ADDR -u LDAP_USER -w interactif -s SECRET_PATH [--decrypt]
#
#   -a : URL de HashiCorp Vault (ex: http://vault.example.com:8200)
#   -u : Nom d'utilisateur LDAP
#   -w : Mot de passe (en clair, 'interactif', ou chiffré avec 'enc:')
#   -s : Chemin du secret dans Vault (ex: secret/data/myapp/config)
#   -c : Fichier de configuration (optionnel)
#   -e : Environnement (ex: INT, PROD) (optionnel)
#   --decrypt : Déchiffrer le mot de passe avant utilisation
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

# Fonction pour afficher l'aide
usage() {
    echo "Utilisation: $0 [-a VAULT_ADDR] [-u LDAP_USER] [-w MOT_DE_PASSE] [-s SECRET_PATH] [-c CONFIG_FILE] [-e ENVIRONMENT] [--decrypt]"
    echo "  -a : URL de HashiCorp Vault (ex: http://vault.example.com:8200)"
    echo "  -u : Nom d'utilisateur LDAP"
    echo "  -w : Mot de passe (en clair, 'interactif', ou chiffré avec 'enc:')"
    echo "  -s : Chemin du secret dans Vault (ex: secret/data/myapp/config)"
    echo "  -c : Fichier de configuration (optionnel)"
    echo "  -e : Environnement (ex: INT, PROD) (optionnel)"
    echo "  --decrypt : Déchiffrer le mot de passe avant utilisation"
    exit 1
}

# Fonction pour logger les messages
log() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message"
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
        log "Erreur: Impossible de déchiffrer le mot de passe. Vérifiez la clé de déchiffrement."
        return 1
    fi

    echo "$decrypted_password"
}

# Fonction pour charger la configuration depuis un fichier
load_config() {
    local config_file="$1"
    local environment="$2"

    if [ -f "$config_file" ] && [ -r "$config_file" ]; then
        log "Chargement de la configuration pour l'environnement $environment depuis $config_file..."

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
        log "Erreur: Fichier de configuration $config_file introuvable ou inaccessible."
        return 1
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
            --decrypt) DECRYPT_MODE=true; shift ;;
            *) usage ;;
        esac
    done
}

# Fonction pour valider les paramètres
validate_parameters() {
    if [ -z "$VAULT_ADDR" ] || [ -z "$LDAP_USER" ] || [ -z "$LDAP_PASSWORD" ] || [ -z "$SECRET_PATH" ]; then
        log "Erreur: Les paramètres -a, -u, -w et -s sont obligatoires."
        usage
    fi
}

# Fonction pour s'authentifier avec LDAP
authenticate() {
    local username="$1"
    local password="$2"
    local response

    log "Authentification avec LDAP..."
    response=$(curl -s -X POST -d "{\"password\": \"$password\"}" \
        -H "Content-Type: application/json" \
        "$VAULT_ADDR/v1/auth/ldap/login/$username")

    if echo "$response" | grep -q "errors"; then
        log "Erreur d'authentification: $response"
        return 1
    fi

    VAULT_TOKEN=$(echo "$response" | grep -o '"client_token":"[^"]*"' | sed 's/"client_token":"\(.*\)"/\1/')
    if [ -z "$VAULT_TOKEN" ]; then
        log "Erreur: Token non trouvé dans la réponse."
        return 1
    fi

    log "Authentification réussie. Token récupéré."
}

# Fonction pour récupérer un secret
get_secret() {
    local secret_path="$1"
    local response

    log "Récupération du secret depuis $secret_path..."
    response=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" -X GET "$VAULT_ADDR/v1/$secret_path")

    if echo "$response" | grep -q "errors"; then
        log "Erreur lors de la récupération du secret: $response"
        return 1
    fi

    secret_data=$(echo "$response" | grep -o '"data":\{[^}]+\}')
    if [ -z "$secret_data" ]; then
        log "Erreur: Données du secret non trouvées dans la réponse."
        return 1
    fi

    log "Secret récupéré avec succès:"
    echo "$secret_data"
}

# Fonction pour révoquer le token
revoke_token() {
    local token="$1"
    local response

    log "Révocation du token..."
    response=$(curl -s -X POST -H "X-Vault-Token: $token" "$VAULT_ADDR/v1/auth/token/revoke-self")

    if echo "$response" | grep -q "errors"; then
        log "Erreur lors de la révocation du token: $response"
        return 1
    fi

    log "Token révoqué avec succès."
}

# Fonction principale
main() {
    log "Début du script."

    # Lire les paramètres
    read_parameters "$@"

    # Charger la configuration si un fichier et un environnement sont spécifiés
    if [ -n "$CONFIG_FILE" ] && [ -n "$ENVIRONMENT" ]; then
        load_config "$CONFIG_FILE" "$ENVIRONMENT" || { log "Échec du chargement de la configuration. Arrêt du script."; exit 1; }
    fi

    # Valider les paramètres
    validate_parameters

    # Déchiffrer le mot de passe si nécessaire
    if [[ "$LDAP_PASSWORD" == enc:* ]]; then
        log "Déchiffrement du mot de passe chiffré..."
        LDAP_PASSWORD=$(decrypt_password "$LDAP_PASSWORD") || { log "Échec du déchiffrement. Arrêt du script."; exit 1; }
    fi

    # Authentification
    authenticate "$LDAP_USER" "$LDAP_PASSWORD" || { log "Échec de l'authentification. Arrêt du script."; exit 1; }

    # Récupérer le secret
    secret=$(get_secret "$SECRET_PATH") || { revoke_token "$VAULT_TOKEN"; log "Échec de la récupération du secret. Arrêt du script."; exit 1; }

    # Afficher le secret
    echo "$secret"

    # Révoquer le token
    revoke_token "$VAULT_TOKEN" || { log "Erreur lors de la révocation du token."; exit 1; }

    log "Script terminé avec succès."
}

# Point d'entrée du script
main "$@"
