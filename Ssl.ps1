# === Paramètres à adapter ===
$Port = 5986  # Mets ici le port utilisé par XL Deploy ou ton service HTTPS
$AppId = "{00112233-4455-6677-8899-AABBCCDDEEFF}" # GUID arbitraire, juste unique

# === Récupération infos machine ===
$FQDN = [System.Net.Dns]::GetHostByName(($env:computerName)).HostName
$ShortName = $env:COMPUTERNAME
$IP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet" | Where-Object {$_.IPAddress -notlike "169.*"} | Select-Object -First 1 -ExpandProperty IPAddress)

Write-Host "Création certificat pour : localhost, $FQDN, $ShortName, $IP"

# === Création du certificat auto-signé ===
$Cert = New-SelfSignedCertificate `
    -DnsName "localhost", $FQDN, $ShortName, $IP `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -FriendlyName "XL Deploy Cert multi-noms" `
    -KeyLength 2048 `
    -KeyExportPolicy Exportable `
    -KeyUsage DigitalSignature, KeyEncipherment `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1") # TLS Web Server Auth

# === Récupération du Thumbprint ===
$Thumbprint = $Cert.Thumbprint
Write-Host "✅ Certificat généré avec Thumbprint : $Thumbprint"

# === Suppression éventuelle de l'ancien binding ===
try {
    netsh http delete sslcert ipport=0.0.0.0:$Port
    Write-Host "Ancien binding supprimé."
} catch {
    Write-Host "Aucun binding précédent trouvé sur le port $Port"
}

# === Ajout du nouveau binding ===
netsh http add sslcert ipport=0.0.0.0:$Port certhash=$Thumbprint appid=$AppId
Write-Host "✅ Nouveau binding SSL ajouté sur le port $Port"

# === Redémarrage du service HTTP ===
Restart-Service http
Write-Host "🚀 Certificat actif. SAN inclut localhost, $FQDN, $ShortName et $IP"
