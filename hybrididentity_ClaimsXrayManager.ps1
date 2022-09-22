Param(
  [switch] $SkipSetup
  )
$global:SelRP = $null
$global:SelOp = $null
  
$dateObj = Get-Date
$Logfile = $PWD.Path + "\ClaimsXray_"+$dateObj.Year+$dateObj.Month+$dateObj.Day+$dateObj.Hour+$dateObj.Minute+$dateObj.Second+".log"
$defaultIssuanceRule = "@RuleName = `"Issue all claims`"`nx:[]=>issue(claim = x); "
$defaultAuthzRules = "=>issue(Type = `"http://schemas.microsoft.com/authorization/claims/permit`", Value = `"true`"); "

$allClaimRules = "Default: Issue all claims"
$copyToXray = "Copy claims to Claims X-Ray"
$copyFromXray = "Copy claims from Claims X-Ray"
        
Function LogWrite 
{
   Param (
    [switch]$Err,
    [switch]$Success,
    [switch]$LogOnly,
    [string]$logstring
    
   )
   
   if ($LogOnly -eq $false) {
       if ($err) 
	   { 
		Write-Host -ForegroundColor Red $logstring
       }
       elseif ($success) 
	   {
		Write-Host -ForegroundColor Green $logstring
	   }
       else 
	   {
		Write-Host $logstring
	   } 
   }
   
   Add-content $Logfile -value $logstring
}

$claimsXRayName = "ClaimsXray"
$claimsXRayIdentifier = "urn:microsoft:adfs:claimsxray"

if ($SkipSetup -eq $false) {
	LogWrite "Checking current configuration..."
	
    ##################################################################
    #
    # Verify that the ADFS Server service is running.  
    #
    ##################################################################
    LogWrite "  - Verifying that the AD FS service is running..."
    $srvc = Get-Service -Name "adfssrv"
    if ($srvc.Status.ToString().ToLower() -ne "running") {
        LogWrite -Err "AD FS service is not running on this box. Please execute the script on the primary AD FS server"
        exit 100
    }

    ##################################################################
    #
    # Configure the Claims X-Ray RP and oAuth client
    #
    ##################################################################

    LogWrite "  - Checking to see if the Claims X-Ray RP is already configured..."

    $claimsXRayRP = Get-AdfsRelyingPartyTrust -Name $claimsXRayName
    if ($claimsXRayRP -eq $null) {
        LogWrite "    - The Claims X-Ray RP is not configured."
        LogWrite "    - Creating the Claims X-Ray RP..."

        $authzRules = $defaultAuthzRules
        $issuanceRules = $defaultIssuanceRule
        $redirectUrl = "https://adfshelp.microsoft.com/ClaimsXray/TokenResponse"
        $samlEndpoint = New-AdfsSamlEndpoint -Binding POST -Protocol SAMLAssertionConsumer -Uri $redirectUrl

        Add-ADFSRelyingPartyTrust -Name $claimsXRayName -Identifier $claimsXRayIdentifier -IssuanceAuthorizationRules $authzRules -IssuanceTransformRules $issuanceRules -WSFedEndpoint $redirectUrl -SamlEndpoint $samlEndpoint
    }
    LogWrite "    - Claims X-Ray RP configured."

    LogWrite "  - Checking to see if the Claims X-Ray oAuth client is configured..."

	if (([System.Environment]::OSVersion.Version.major -lt 6) -or 
		(([System.Environment]::OSVersion.Version.major -eq 6) -and ([System.Environment]::OSVersion.Version.minor -lt 3)))
	{
			LogWrite "    - Windows Server version doesn't support oAuth."
	}
	else
	{
		$claimsXRayClient = Get-AdfsClient -ClientId "claimsxrayclient"
		if ($claimsXRayClient -eq $null)
		{
			LogWrite "    - The Claims X-Ray oAuth client is not configured."
			LogWrite "    - Creating the Claims X-Ray oAuth client..."

			Add-AdfsClient -Name "ClaimsXrayClient" -ClientId "claimsxrayclient" -RedirectUri https://adfshelp.microsoft.com/ClaimsXray/TokenResponse
			if ([System.Environment]::OSVersion.Version.major -gt 6) 
			{ 
				Grant-AdfsApplicationPermission -ServerRoleIdentifier $claimsXRayIdentifier -AllowAllRegisteredClients -ScopeNames "openid","profile" 
			}
		}    
		LogWrite "    - Claims X-Ray oAuth Client configured."
	}
}

##################################################################
#
# Get the AD FS Relying party trusts.
#
##################################################################

LogWrite "  - Getting the current RP trusts..."
	
$AllRPS = Get-ADFSRelyingPartyTrust
$HostName = (Get-ADFSProperties).hostname.ToString()
$RPIdentifiers  = @()
LogWrite ("    - Number of RP trusts found: " + $AllRPS.Count)
foreach ($RPitem in $AllRPs){
    $RPIdentifiers += $RPItem.Name
    LogWrite -LogOnly $RPitem.Name
}

##################################################################
#
# Show the UI to select the UI
#
##################################################################

#Import the Assemblies
Add-Type -AssemblyName System.Windows.Forms
  
#Form Objects
$Form = New-Object system.Windows.Forms.Form
$comboBoxOperation = New-Object system.windows.Forms.ComboBox
$labelOperation = New-Object system.windows.Forms.Label
$labelRP = New-Object system.windows.Forms.Label
$comboBoxRP = New-Object system.windows.Forms.ComboBox
$buttonOk = New-Object system.windows.Forms.Button

##################################################################
#
# Event Script Blocks
#
##################################################################

$buttonOK_OnClick=
{
    $global:SelRP = $comboBoxRP.SelectedItem
    $global:SelOp = $comboBoxOperation.SelectedItem
    $Form.close()
}
     
$OnLoadForm_StateCorrection=
{
	#Correct the initial state of the form to prevent the .Net maximized form issue
    $Form.WindowState = $InitialFormWindowState

    $RPIdentifiers | Foreach {
        $comboBoxRP.items.add($_)
        $comboBoxRP.SelectedIndex=0
    }
    $comboBoxRP.visible = $true
    $labelRP.visible = $true
    $buttonOK.visible = $true
    $comboBoxOperation.Visible = $true
    $Form.Text = "ADFS Help Claims X-Ray Manager"
}

##################################################################
#
# Generating UI
#
##################################################################  

$Form.Text = "Form"
$Form.TopMost = $true
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false
$Form.Width = 500
$Form.Height = 180

$comboBoxOperation.Text = ""
$comboBoxOperation.Width = 336
$comboBoxOperation.Height = 20
$comboBoxOperation.location = new-object system.drawing.point(134,13)
$comboBoxOperation.Font = "Segoe UI,10"
$comboBoxOperation.Items.Add($copyToXray) | Out-Null
$comboBoxOperation.Items.Add($copyFromXray) | Out-Null
$comboBoxOperation.SelectedIndex = 0
$Form.controls.Add($comboBoxOperation)

$labelOperation.Text = "Select Operation"
$labelOperation.AutoSize = $true
$labelOperation.Width = 25
$labelOperation.Height = 10
$labelOperation.location = new-object system.drawing.point(7,12)
$labelOperation.Font = "Segoe UI,10"
$Form.controls.Add($labelOperation)

$labelRP.Text = "Select Relying Party"
$labelRP.AutoSize = $true
$labelRP.Width = 25
$labelRP.Height = 10
$labelRP.location = new-object system.drawing.point(6,49)
$labelRP.Font = "Segoe UI,10"
$Form.controls.Add($labelRP)

$comboBoxRP.Text = ""
$comboBoxRP.Width = 336
$comboBoxRP.Height = 20
$comboBoxRP.location = new-object system.drawing.point(135,48)
$comboBoxRP.Items.Add($allClaimRules) | Out-Null
$comboBoxRP.Font = "Segoe UI,10"
$comboBoxRP.SelectedIndex = 0
$Form.controls.Add($comboBoxRP)

$buttonOk.Text = "Apply changes"
$buttonOk.Width = 150
$buttonOk.Height = 30
$buttonOk.Add_MouseClick(
    $buttonOK_OnClick
)
$buttonOk.location = new-object system.drawing.point(160,100)
$buttonOk.Font = "Segoe UI,10"
$Form.controls.Add($buttonOk)

##################################################################
#
# Save the initial state of the form
#
##################################################################    
$InitialFormWindowState = $Form.WindowState
#Init the OnLoad event to correct the initial state of the form
$Form.add_Load($OnLoadForm_StateCorrection)
  
#Show the Form
$Form.ShowDialog()| Out-Null

if ([string]::IsNullOrEmpty($global:SelRP) -or [string]::IsNullOrEmpty($global:SelOp))
{
    LogWrite "User canceled the operation."
    exit 0
}

LogWrite ("Selected Operation: " + $SelOp)
LogWrite ("Selected RP: " + $SelRP)
$sourceRP = ""
$targetRP = ""

if (($global:SelOp -eq $copyFromXray) -and ($global:SelRP -eq $allClaimRules))
{
	LogWrite "Cannot copy All Claims from Claims X-Ray"
	exit 1
}
  
if ($SelOp -eq $copyToXray) 
{
    $sourceRP = $SelRP
    $targetRP = $claimsXRayName
}
else 
{
    $sourceRP = $claimsXRayName
    $targetRP = $SelRP
}

LogWrite ("Copying claims...")
try 
{        
    if ($sourceRP -eq $allClaimRules)
	{
        $IssuanceTransformRules = $defaultIssuanceRule
        $IssuanceAuthzRules = $defaultAuthzRules
        $DelegationAuthzRules = ""
    }
    else 
	{
        $IssuanceTransformRules = (Get-AdfsRelyingPartyTrust -Name $sourceRP).IssuanceTransformRules
        $IssuanceAuthzRules = (Get-AdfsRelyingPartyTrust -Name $sourceRP).IssuanceAuthorizationRules
        $DelegationAuthzRules = (Get-AdfsRelyingPartyTrust -Name $sourceRP).DelegationAuthorizationRules
    }

    LogWrite -LogOnly $IssuanceTransformRules
    LogWrite -LogOnly $IssuanceAuthzRules
    LogWrite -LogOnly $DelegationAuthzRules
        
    Set-AdfsRelyingPartyTrust -TargetName $targetRP -IssuanceTransformRules $IssuanceTransformRules

    #We don't want to accidentally overwrite some temporary authorization and delegation rules from Claims X-Ray
    if ($targetRP -eq $claimsXRayName) 
	{
        Set-AdfsRelyingPartyTrust -TargetName $targetRP -IssuanceAuthorizationRules $IssuanceAuthzRules #$IssuanceAuthzRules.ClaimsRulesString
        if ($DelegationAuthzRules.ClaimRules.Length -gt 0 )
		{
            Set-AdfsRelyingPartyTrust -TargetName $targetRP -DelegationAuthorizationRules $DelegationAuthzRules            
        }
    }
	
    ## At this point we are done
    LogWrite "Operation completed."
}
catch 
{
    $errorMessage = $_.Exception.Message
    LogWrite -Err "Operation was not completed successfully."
    LogWrite -Err $errorMessage        
}
# SIG # Begin signature block
# MIIjhgYJKoZIhvcNAQcCoIIjdzCCI3MCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDUfzymEMNxtlcw
# Z3Anj/M08ayGLp0yQ72fqqj7pEdKMaCCDYEwggX/MIID56ADAgECAhMzAAACUosz
# qviV8znbAAAAAAJSMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjEwOTAyMTgzMjU5WhcNMjIwOTAxMTgzMjU5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDQ5M+Ps/X7BNuv5B/0I6uoDwj0NJOo1KrVQqO7ggRXccklyTrWL4xMShjIou2I
# sbYnF67wXzVAq5Om4oe+LfzSDOzjcb6ms00gBo0OQaqwQ1BijyJ7NvDf80I1fW9O
# L76Kt0Wpc2zrGhzcHdb7upPrvxvSNNUvxK3sgw7YTt31410vpEp8yfBEl/hd8ZzA
# v47DCgJ5j1zm295s1RVZHNp6MoiQFVOECm4AwK2l28i+YER1JO4IplTH44uvzX9o
# RnJHaMvWzZEpozPy4jNO2DDqbcNs4zh7AWMhE1PWFVA+CHI/En5nASvCvLmuR/t8
# q4bc8XR8QIZJQSp+2U6m2ldNAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUNZJaEUGL2Guwt7ZOAu4efEYXedEw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDY3NTk3MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAFkk3
# uSxkTEBh1NtAl7BivIEsAWdgX1qZ+EdZMYbQKasY6IhSLXRMxF1B3OKdR9K/kccp
# kvNcGl8D7YyYS4mhCUMBR+VLrg3f8PUj38A9V5aiY2/Jok7WZFOAmjPRNNGnyeg7
# l0lTiThFqE+2aOs6+heegqAdelGgNJKRHLWRuhGKuLIw5lkgx9Ky+QvZrn/Ddi8u
# TIgWKp+MGG8xY6PBvvjgt9jQShlnPrZ3UY8Bvwy6rynhXBaV0V0TTL0gEx7eh/K1
# o8Miaru6s/7FyqOLeUS4vTHh9TgBL5DtxCYurXbSBVtL1Fj44+Od/6cmC9mmvrti
# yG709Y3Rd3YdJj2f3GJq7Y7KdWq0QYhatKhBeg4fxjhg0yut2g6aM1mxjNPrE48z
# 6HWCNGu9gMK5ZudldRw4a45Z06Aoktof0CqOyTErvq0YjoE4Xpa0+87T/PVUXNqf
# 7Y+qSU7+9LtLQuMYR4w3cSPjuNusvLf9gBnch5RqM7kaDtYWDgLyB42EfsxeMqwK
# WwA+TVi0HrWRqfSx2olbE56hJcEkMjOSKz3sRuupFCX3UroyYf52L+2iVTrda8XW
# esPG62Mnn3T8AuLfzeJFuAbfOSERx7IFZO92UPoXE1uEjL5skl1yTZB3MubgOA4F
# 8KoRNhviFAEST+nG8c8uIsbZeb08SeYQMqjVEmkwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVWzCCFVcCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAlKLM6r4lfM52wAAAAACUjAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgaKqxeBGC
# /e+FVv0EX6xeTZza6PlscLLVAAylOhG6F7MwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQCR8y2JHp9i+NMqTQUALxiLNlGmGnTbBF8UeAEdIioG
# mBFdTNCT2lrlnbtBwgOUrETko0ehUiwomDgaoXb99/mf+JAEvkPh0pMgNuG418Df
# T1FgPeMyKP6GBsKmXWyazPddjPqFHRToEdUbBxq13cuDf3gX/e3t/iyJQ97ipSzL
# 0xGXloAKpQxDMd+GfX/1DjDU1ROCqoyh6GH7tBHGntzGYVUI1FGObureeQTW1uJu
# for/g0Eanz/VWknsV8Od59YvULdJue+4PhYNkn1ijaY5fCArtA8cKTvtrOQoU+K9
# 66pQo9PEyDl2JHbVQJyhgSgUg6CEE93n6qJtVU4GbEU6oYIS5TCCEuEGCisGAQQB
# gjcDAwExghLRMIISzQYJKoZIhvcNAQcCoIISvjCCEroCAQMxDzANBglghkgBZQME
# AgEFADCCAVEGCyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIDulrewKLfNgcapvEfkBquDisp5tgZeElPoRLI52
# AS9WAgZhktZRk2gYEzIwMjExMjAyMTgzOTMxLjE2OFowBIACAfSggdCkgc0wgcox
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOkU1QTYtRTI3Qy01OTJFMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIOPDCCBPEwggPZoAMCAQICEzMAAAFHnY/x5t4xg1kAAAAAAUcw
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MjAxMTEyMTgyNTU1WhcNMjIwMjExMTgyNTU1WjCByjELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046RTVBNi1FMjdDLTU5
# MkUxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCtBQNM6X32KFk/BJ8YaprfzEt6Lj34
# G+VLjzgfEgOGSVd1Mu7nCphK0K4oyPrzItgNRjB4gUiKq6GzgxdDHgZPgTEvm57z
# sascyGrybWkf3VVr8bqf2PIgGvwKDNEgVcygsEbuWwXz9Li6M7AOoD4TB8fl4ATm
# +L7b4+lYDUMJYMLzpiJzM745a0XHiriUaOpYWfkwO9Hz6uf+k2Hq7yGyguH8naPL
# MnYfmYIt2PXAwWVvG4MD4YbjXBVZ14ueh7YlqZTMua3n9kT1CZDsHvz+o58nsoam
# XRwRFOb7LDjVV++cZIZLO29usiI0H79tb3fSvh9tU7QC7CirNCBYagNJAgMBAAGj
# ggEbMIIBFzAdBgNVHQ4EFgQUtPjcb95koYZXGy9DPxN49dSCsLowHwYDVR0jBBgw
# FoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDov
# L2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljVGltU3RhUENB
# XzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAx
# MC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDCDAN
# BgkqhkiG9w0BAQsFAAOCAQEAUMQOyjV+ea2kEtXqD0cOfD2Z2PFUIy5kLkGU53RD
# GcfhlzIR9QlTgZLqTEhgLLuCSy6jcma+nPg7e5Xg1oqCZcZJRwtRPzS1F6/M6YR3
# 5H3brN0maVnPrmrQ91kkfsNqDTtuWDiAIBfkNEgCpQZCb4OV3HMu5L8eZzg5dUaJ
# 7XE+LBuphJSLFJtabxYt4fkCQxnTD2z50Y32ZuXiNmFFia7qVq+3Yc3mmW02+/KW
# H8P1HPiobJG8crGYgSEkxtkUXGdoutwGWW88KR9RRcM/4GKLqt2OQ8AWEQb7shgM
# 8pxNvu30TxejRApa4WAfOAejTG4+KzBm67XjVZ2IlXAPkjCCBnEwggRZoAMCAQIC
# CmEJgSoAAAAAAAIwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRp
# ZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTEwMDcwMTIxMzY1NVoXDTI1MDcwMTIx
# NDY1NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQCpHQ28dxGKOiDs/BOX9fp/aZRrdFQQ1aUKAIKF
# ++18aEssX8XD5WHCdrc+Zitb8BVTJwQxH0EbGpUdzgkTjnxhMFmxMEQP8WCIhFRD
# DNdNuDgIs0Ldk6zWczBXJoKjRQ3Q6vVHgc2/JGAyWGBG8lhHhjKEHnRhZ5FfgVSx
# z5NMksHEpl3RYRNuKMYa+YaAu99h/EbBJx0kZxJyGiGKr0tkiVBisV39dx898Fd1
# rL2KQk1AUdEPnAY+Z3/1ZsADlkR+79BL/W7lmsqxqPJ6Kgox8NpOBpG2iAg16Hgc
# sOmZzTznL0S6p/TcZL2kAcEgCZN4zfy8wMlEXV4WnAEFTyJNAgMBAAGjggHmMIIB
# 4jAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU1WM6XIoxkPNDe3xGG8UzaFqF
# bVUwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1Ud
# EwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYD
# VR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwv
# cHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEB
# BE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9j
# ZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwgaAGA1UdIAEB/wSBlTCB
# kjCBjwYJKwYBBAGCNy4DMIGBMD0GCCsGAQUFBwIBFjFodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vUEtJL2RvY3MvQ1BTL2RlZmF1bHQuaHRtMEAGCCsGAQUFBwICMDQe
# MiAdAEwAZQBnAGEAbABfAFAAbwBsAGkAYwB5AF8AUwB0AGEAdABlAG0AZQBuAHQA
# LiAdMA0GCSqGSIb3DQEBCwUAA4ICAQAH5ohRDeLG4Jg/gXEDPZ2joSFvs+umzPUx
# vs8F4qn++ldtGTCzwsVmyWrf9efweL3HqJ4l4/m87WtUVwgrUYJEEvu5U4zM9GAS
# inbMQEBBm9xcF/9c+V4XNZgkVkt070IQyK+/f8Z/8jd9Wj8c8pl5SpFSAK84Dxf1
# L3mBZdmptWvkx872ynoAb0swRCQiPM/tA6WWj1kpvLb9BOFwnzJKJ/1Vry/+tuWO
# M7tiX5rbV0Dp8c6ZZpCM/2pif93FSguRJuI57BlKcWOdeyFtw5yjojz6f32WapB4
# pm3S4Zz5Hfw42JT0xqUKloakvZ4argRCg7i1gJsiOCC1JeVk7Pf0v35jWSUPei45
# V3aicaoGig+JFrphpxHLmtgOR5qAxdDNp9DvfYPw4TtxCd9ddJgiCGHasFAeb73x
# 4QDf5zEHpJM692VHeOj4qEir995yfmFrb3epgcunCaw5u+zGy9iCtHLNHfS4hQEe
# gPsbiSpUObJb2sgNVZl6h3M7COaYLeqN4DMuEin1wC9UJyH3yKxO2ii4sanblrKn
# QqLJzxlBTeCG+SqaoxFmMNO7dDJL32N79ZmKLxvHIa9Zta7cRDyXUHHXodLFVeNp
# 3lfB0d4wwP3M5k37Db9dT+mdHhk4L7zPWAUu7w2gUDXa7wknHNWzfjUeCLraNtvT
# X4/edIhJEqGCAs4wggI3AgEBMIH4oYHQpIHNMIHKMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBP
# cGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpFNUE2LUUyN0MtNTky
# RTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUAq6fBtEENocNASMqL03zGJS0wZd2ggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIFAOVTFSswIhgPMjAy
# MTEyMDIxNzQ5MzFaGA8yMDIxMTIwMzE3NDkzMVowdzA9BgorBgEEAYRZCgQBMS8w
# LTAKAgUA5VMVKwIBADAKAgEAAgIIigIB/zAHAgEAAgIRcTAKAgUA5VRmqwIBADA2
# BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIB
# AAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBACF+5igbSm2jZzwsoatw6XtDoT5ivrFQ
# Bz2H9y1mWH7c3JxEf9Pl/YTxgIl1Xxk0lDGVf5r7DicjDaJoqSwFNpjcCJFyh2QB
# Pfu5ieE0hXKVP8f5KNG0WdG6oGrr3fnIhU6Pp0mBV29aFlTmF5DM8YpjW/5ZXo/B
# ZsHo5olvRe3WMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTACEzMAAAFHnY/x5t4xg1kAAAAAAUcwDQYJYIZIAWUDBAIBBQCgggFKMBoG
# CSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgThA16n6r
# 2DbWJMUKtsIIy+c33Rwi15WU7ogmWEZsGUYwgfoGCyqGSIb3DQEJEAIvMYHqMIHn
# MIHkMIG9BCB72zwSA5TPugbIiZO/2H1hrisAVItwzDscb0WqihjphTCBmDCBgKR+
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABR52P8ebeMYNZAAAA
# AAFHMCIEIDBAiisYEq2hqDnZbLBKwtldAoO7yiivJuDzwTHB6ttSMA0GCSqGSIb3
# DQEBCwUABIIBACuOhismaPkLQ6LF8OT9l7dKXDWqYtLsts26AIirN+gDXfTHGS5U
# cCTiqZJg4oVNHbb/bUG+iypLPwoIErFx6wqDXH3R1oBesIMx+F9TmNI/PnHxrSQO
# v0+MCT826F/uVt3NFGm3pHxe8FeRRjnHd3nIoArGMSIEdPbklq1mz7S0lCV9iOKM
# fqQVP7l7Ss1a8Ppu3f4wrWNOuHcPmtJ0CysR2RqTMwb28Nyr5WjRYwHjb6isbJ/2
# k6cBLFV0p/ZcEQwiLkV9f1cmomPbO8j6P7fmMBXHAxliYHLdB2vBNB0mDb/qp6ZS
# U0+7aHHFF/MaJlRFaDxnlZrkoCjqEbaEitM=
# SIG # End signature block
