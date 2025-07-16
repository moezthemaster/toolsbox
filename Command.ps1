$scriptPath = "C:\chemin\scripttest.ps1"
$arguments = "-File `"$scriptPath`""

$scriptCode = @"
\$proc = Start-Process -FilePath 'powershell.exe' `
                       -ArgumentList '$arguments' `
                       -WindowStyle Hidden `
                       -PassThru
\$proc.Id
"@

$scriptBlock = [scriptblock]::Create($scriptCode)
