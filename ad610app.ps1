
$ErrorActionPreference = 'SilentlyContinue'

while ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -eq $false)

{
sleep 120
$passwordAD = ConvertTo-SecureString "AD661!Pa55w.rd" -AsPlainText -Force
$adcred = New-Object System.Management.Automation.PSCredential ("saplab\ad-adm", $passwordAD )
#DomainJoin
Add-Computer -DomainName saplab.local -Credential $adcred

}

#Restart Server
Restart-Computer -Delay 20 -Force