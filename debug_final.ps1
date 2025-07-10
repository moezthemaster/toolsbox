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

$credentials = New-Object System.Management.Automation.PSCredential -ArgumentList @($username, (ConvertTo-SecureString -String $password -AsPlainText -Force))

if ($environnement -eq "D") {
	$session = New-PSSession -Credential ($credentials)
}
else {
	$session = New-PSSession -Credential ($credentials) -Authentication Credssp
}

if ($background) {
	# Envoie un script à distance qui lance un job sur la machine cible
	$scriptBlock = {
		param($path, $args)
		Start-Job -ScriptBlock {
			param($p, $a)
			& $p $a
		} -ArgumentList $path, $args | Out-Null
		Write-Output "Script $path lancé en arrière-plan sur $env:COMPUTERNAME"
	}

	Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $scriptPath, $argumentList
}
else {
	# Exécution directe (synchrone)
	$scriptBlock = [scriptblock]::Create("& `"$scriptPath`" $argumentList")
	Invoke-Command -Session $session -ScriptBlock $scriptBlock
	Write-Host "script '$scriptPath' successfully invoked"
}
