$file = ((Get-Content 'C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\AADConnectProvisioningAgent.exe.config') -as [Collections.ArrayList])
$file.insert(3,'    <enforceFIPSPolicy enabled='`$false'/>')
$file | Set-Content 'C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\AADConnectProvisioningAgent.exe.config' -force
