
#Set Credentials
$passwordAD = ConvertTo-SecureString "AD661!Pa55w.rd" -AsPlainText -Force
$adcred = New-Object System.Management.Automation.PSCredential ("saplab\ad-adm", $passwordAD )

#DomainJoin
Add-Computer -DomainName saplab.local -Credential $adcred

#Restart Server
Restart-Computer -Delay 120 -Force

                        