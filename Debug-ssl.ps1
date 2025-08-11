# Paramètres à adapter
$Port = 5986   # Le port à nettoyer et reconfigurer
$OldCertAlias = "*XL Deploy*"  # Nom friendly des certificats auto-signés à supprimer (optionnel)

# 1. Supprimer les bindings SSL sur le port
Write-Host "Suppression des bindings SSL sur le port $Port..."
try {
    netsh http delete sslcert ipport=0.0.0.0:$Port
    Write-Host "Bindings supprimés."
} catch {
    Write-Warning "Pas de binding SSL trouvé ou erreur lors de la suppression."
}

# 2. Supprimer les certificats auto-signés XL Deploy (optionnel)
Write-Host "Recherche et suppression des certificats auto-signés..."
$certs = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.FriendlyName -like $OldCertAlias}
if ($certs.Count -eq 0) {
    Write-Host "Aucun certificat auto-signé XL Deploy trouvé."
} else {
    foreach ($cert in $certs) {
        Write-Host "Suppression certificat : $($cert.Subject) Thumbprint : $($cert.Thumbprint)"
        Remove-Item -Path "Cert:\LocalMachine\My\$($cert.Thumbprint)" -Force
    }
}

# 3. Demander à l'utilisateur le thumbprint du certificat à binder
$thumbprint = Read-Host "Entre le thumbprint EXACT du certificat à binder (sans espaces)"

# Validation du thumbprint
if ([string]::IsNullOrWhiteSpace($thumbprint)) {
    Write-Error "Thumbprint vide. Abandon."
    exit
}

# 4. Créer le binding SSL avec le certificat choisi
$appid = "{00112233-4455-6677-8899-AABBCCDDEEFF}"  # GUID arbitraire unique
Write-Host "Création du binding SSL sur le port $Port avec le certificat $thumbprint..."
try {
    netsh http add sslcert ipport=0.0.0.0:$Port certhash=$thumbprint appid=$appid
    Write-Host "Binding SSL créé avec succès."
} catch {
    Write-Error "Erreur lors de la création du binding SSL : $_"
    exit
}

# 5. Redémarrer le service HTTP
Write-Host "Redémarrage du service HTTP..."
try {
    Restart-Service http -Force
    Write-Host "Service HTTP redémarré."
} catch {
    Write-Warning "Impossible de redémarrer le service HTTP, merci de le faire manuellement."
}

Write-Host "`nTerminé. Vérifie la configuration et teste la connexion."
