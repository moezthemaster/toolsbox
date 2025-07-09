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

$scriptBlock = [scriptblock]::Create("& `"$scriptPath`" $argumentList")

if ($background) {
	$job = Invoke-Command -Session $session -ScriptBlock $scriptBlock -AsJob
	Write-Host "'$scriptPath' is running in background with the ID $($job.Id). You can use Receive-Job to fetch results"
}
else {
	Invoke-Command -Session $session -ScriptBlock $scriptBlock
	Write-Host "script '$scriptPath' successfully invoked"
}
