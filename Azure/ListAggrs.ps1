Import-Module DataONTAP
$password = ConvertTo-SecureString "Netapp1!" -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "admin",$password
Connect-NcController 192.168.0.40 -Credential $cred
Get-NcAggr
