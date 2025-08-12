# Variables à adapter
$aliasToAdd = "trt.01.app.private"

# 1. Récupérer le certificat WinRM actuel
$listener = winrm get winrm/config/Listener?Address=*+Transport=HTTPS
$thumbprint = ($listener | Select-String "CertificateThumbprint").ToString().Split('=')[1].Trim()

if (-not $thumbprint) {
    Write-Error "Aucun certificat WinRM HTTPS trouvé."
    exit
}

$cert = Get-ChildItem "Cert:\LocalMachine\My\$thumbprint"

# 2. Extraire les noms DNS existants (SAN)
$dnsNames = @()
try {
    $ext = $cert.Extensions | Where-Object { $_.Oid.FriendlyName -eq "Subject Alternative Name" }
    if ($ext) {
        $sanText = $ext.Format($true)
        $dnsNames = ($sanText -split "\s*,\s*") -replace "DNS Name=", ""
    }
} catch { }

# Ajouter le CN si non présent
$cn = ($cert.Subject -replace "^CN=", "")
if ($cn -and ($dnsNames -notcontains $cn)) {
    $dnsNames += $cn
}

# Ajouter l’alias si non présent
if ($dnsNames -notcontains $aliasToAdd) {
    $dnsNames += $aliasToAdd
}

Write-Host "Noms DNS pour le nouveau certificat : $($dnsNames -join ', ')"

# 3. Créer un nouveau certificat avec SAN mis à jour
$newCert = New-SelfSignedCertificate `
    -DnsName $dnsNames `
    -CertStoreLocation "Cert:\LocalMachine\My"

Write-Host "Nouveau certificat créé avec Thumbprint : $($newCert.Thumbprint)"

# 4. Réassocier au listener WinRM
Write-Host "Réassociation du certificat au listener WinRM HTTPS..."
winrm delete winrm/config/Listener?Address=*+Transport=HTTPS | Out-Null
winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=$dnsNames[0]; CertificateThumbprint=$newCert.Thumbprint} | Out-Null

Write-Host "Terminé. WinRM HTTPS utilise maintenant un certificat contenant l'alias."
