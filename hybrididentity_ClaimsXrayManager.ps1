$authzRules = "=>issue(Type = `"http://schemas.microsoft.com/authorization/claims/permit`", Value = `"true`"); "
$issuanceRules = "@RuleName = `"Issue all claims`"`nx:[]=>issue(claim = x); "
$redirectUrl = "https://adfshelp.microsoft.com/ClaimsXray/TokenResponse"
$samlEndpoint = New-AdfsSamlEndpoint -Binding POST -Protocol SAMLAssertionConsumer -Uri $redirectUrl

Add-ADFSRelyingPartyTrust -Name "ClaimsXray" -Identifier "urn:microsoft:adfs:claimsxray" -IssuanceAuthorizationRules $authzRules -IssuanceTransformRules $issuanceRules -WSFedEndpoint $redirectUrl -SamlEndpoint $samlEndpoint

Add-AdfsClient -Name "ClaimsXrayClient" -ClientId "claimsxrayclient" -RedirectUri https://adfshelp.microsoft.com/ClaimsXray/TokenResponse

if ([System.Environment]::OSVersion.Version.major -gt 6) { Grant-AdfsApplicationPermission -ServerRoleIdentifier urn:microsoft:adfs:claimsxray -AllowAllRegisteredClients -ScopeNames "openid","profile" }
