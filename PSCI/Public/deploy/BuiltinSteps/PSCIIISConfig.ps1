<#
The MIT License (MIT)

Copyright (c) 2015 Objectivity Bespoke Software Specialists

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

Configuration PSCIIISConfig {

    <#
    .SYNOPSIS
    Configures IIS - creates application pools / websites / virtual directories / web applications.

    .DESCRIPTION
    This is DSC configuration, so it should be invoked locally (but can also be invoked with -RunRemotely).
    It uses token `IISConfig`, which should be a hashtable (or array of hashtables) with following keys:
    - **ApplicationPool** - hashtable (or array of hashtables) describing configuration of Application Pools, each entry should contain following keys:
      - **Name** (required)
      - **Identity** - one of ApplicationPoolIdentity, LocalSystem, LocalService, NetworkService, SpecificUser (default: ApplicationPoolIdentity)
      - **Credential** - PSCredential, used only if Identity = SpecificUser

    - **Website** - hashtable (or array of hashtables) describing configuration of Websites, each entry should contain following keys:
      - **Name** (required)
      - **Binding** (required) - hashtable (or array of hashtables) describing binding:
        - **Port** (required)
        - **Protocol** - http (default) or https
        - **HostName**
        - **IPAddress**
        - **CertificateStoreName** - for https only - allowed values: My (default), WebHosting
        - **CertificateThumbprint** - for https only
        - **CertificateSelfSigned** - if $true, self-signed certificate will be created (if doesn't exist) and bound to https (this should NOT be used together with CertificateStoreName or CertificateThumbprint)
      - **PhysicalPath** (required)
      - **ApplicationPool** (default: DefaultAppPool) - note if application pool is configured in the same step, also proper ACLs to PhysicalPath will be added.
      - **AuthenticationMethodsToEnable** - list of authentication methods to enable (e.g. Windows) - note it should not be normally used (you should put it into Web.config of your web application)
      - **AuthenticationMethodsToDisable** - list of authentication methods to disable (e.g. Anonymous) - note it should not be normally used (you should put it into Web.config of your web application)
    
    - **VirtualDirectory** - hashtable (or array of hashtables) describing configuration of Virtual Directories created under websites, each entry should contain following keys:
      - **Name** (required)
      - **PhysicalPath** (required)
      - **Website** (required)

    - **WebApplication** - hashtable (or array of hashtables) describing configuration of Web Applications, each entry should contain following keys:
      - **Name** (required)
      - **PhysicalPath** (required)
      - **Website** (required)
      - **ApplicationPool** (default: <inherited from site>) - note if application pool is configured in the same step, also proper ACLs to PhysicalPath will be added.

    See also [xWebAdministration](https://github.com/PowerShell/xWebAdministration).

    .EXAMPLE
    ```
    Import-Module "$PSScriptRoot\..\PSCI\PSCI.psd1" -Force

    # clear any old Environment definitions - required only for -NoConfigFiles deployments
    $Global:Environments = @{}

    Environment Local { 
        ServerConnection WebServer -Nodes localhost
        ServerRole Web -Steps 'PSCIIISConfig' -ServerConnection WebServer

        Tokens Web @{
            IISConfig = @{
                ApplicationPool = @( @{ Name = 'MyWebAppPool'; Identity = 'ApplicationPoolIdentity' },
                                     @{ Name = 'MySecondAppPool'; Identity = 'ApplicationPoolIdentity' }
                                     #@{ Name = 'MyThirdAppPool'; Identity = 'SpecificUser'; Credential = { $Tokens.Credentials.MyCredential } }
                                  )
                Website = @( @{ Name = 'MyWebsite'; 
                                Binding = @{ Port = 801 }; 
                                PhysicalPath = 'c:\inetpub\wwwroot\MyWebsite'; 
                                ApplicationPool = 'MyWebAppPool' 
                             },
                             @{ Name = 'MySecondWebsite'; 
                                Binding = @{ Port = 802; Protocol = 'https'; CertificateSelfSigned = $true }; 
                                PhysicalPath = 'c:\inetpub\wwwroot\MySecondWebsite'; 
                                ApplicationPool = 'MySecondAppPool' 
                             }
                           )
                #VirtualDirectory = @{ Name = 'MyVirtualDir'; PhysicalPath = 'c:\inetpub\wwwroot\MyWebSite\VirtualDir'; Website = 'MyWebsite' }
                WebApplication = @{ Name = 'MyApp'; PhysicalPath = 'c:\inetpub\wwwroot\MyApp'; Website = 'MyWebsite'; ApplicationPool = 'MyWebAppPool' }
            }
        }

    }

    Install-DscResources -ModuleNames 'cIIS', 'cACL', 'cCertificate'

    try { 
        Start-Deployment -Environment Local -NoConfigFiles
    } catch {
        Write-ErrorRecord
    }
    ```
    Configures IIS according to the settings specified in 'Web' tokens section.

    #>

    Import-DSCResource -ModuleName cIIS
    Import-DSCResource -ModuleName cACL
    Import-DSCResource -ModuleName cCertificate
    Import-DscResource –ModuleName PSDesiredStateConfiguration

    Node $AllNodes.NodeName {

        $iisConfigs = Get-TokenValue -Name 'IISConfig'

        if (!$iisConfigs) {
            Write-Log -Warn "No IISConfig defined in tokens."
            return
        }

        foreach ($iisConfig in $iisConfigs) { 
            $applicationPool = @($iisConfig.ApplicationPool | Where-Object { $_ })
            $website = @($iisConfig.Website | Where-Object { $_ })
            $virtualDirectory = @($iisConfig.VirtualDirectory | Where-Object { $_ })
            $webApplication = @($iisConfig.WebApplication | Where-Object { $_ })

            # we need to ensure each File resource has unique key
            $directoriesToCreate = @{}

            foreach ($webAppPool in $applicationPool) {
                if (!$webAppPool.Name) {
                    throw "Missing web application pool name - token 'ApplicationPool', key 'Name'"
                }
                $username = ''
                $password = ''
                if (!$webAppPool.Identity) {
                    $webAppPool.Identity = 'ApplicationPoolIdentity'
                } elseif ($webAppPool.Identity -eq 'SpecificUser') {
                    if (!$webAppPool.Credential) {
                        throw "Identity is set to 'SpecificUser' but Credential has not been provided - token 'ApplicationPool' (name '$($webAppPool.Name)'), key 'Credential'."
                    }
                    if ($webAppPool.Credential -isnot [PSCredential]) {
                        throw "Invalid credential type: $($webAppPool.Credential.GetType().ToString()) - token 'ApplicationPool' (name '$($webAppPool.Name)'), key 'Credential'."
                    }
                    $username = $webAppPool.Credential.UserName
                    $password = $webAppPool.Credential.GetNetworkCredential().Password
                }

                Write-Log -Info "Preparing application pool '$($webAppPool.Name)', IdentityType '$($webAppPool.Identity)', Username '$username'"

                if ($username) { 
                    cAppPool "AppPool_$($webappPool.Name)" { 
                        Name = $webAppPool.Name
                        Ensure = 'Present'
                        ManagedRuntimeVersion = 'v4.0'
                        ManagedPipelineMode = 'Integrated'
                        StartMode = 'AlwaysRunning'
                        IdentityType = $webAppPool.Identity
                        UserName = $username
                        Password = $password
                    }
                } else {
                    cAppPool "AppPool_$($webappPool.Name)" { 
                        Name = $webAppPool.Name
                        Ensure = 'Present'
                        ManagedRuntimeVersion = 'v4.0'
                        ManagedPipelineMode = 'Integrated'
                        StartMode = 'AlwaysRunning'
                        IdentityType = $webAppPool.Identity
                    }
                }
            }

            $addSelfSignedCert = $false
            foreach ($site in $Website) {
                if (@($site.Binding).Where({ $_.CertificateSelfSigned -eq $true})) {
                    $addSelfSignedCert = $true
                }
            }

            if ($addSelfSignedCert) {
                Write-Log -Info 'Preparing self-signed certificate'
                cSelfSignedCert MyCert {
                    StoreLocation = 'My'
                    AutoRenew = $true
                }
            }

            foreach ($site in $Website) {
                if (!$site.Name) {
                    throw "Missing site name - token 'Website', key 'Name'"
                }
                if (!$site.PhysicalPath) {
                    throw "Missing site physical path - token 'Website' (name '$($site.Name)'), key 'PhysicalPath'"
                }
                if (!$site.Binding -or $site.Binding -isnot [hashtable]) {
                    throw "Missing / invalid binding information - token 'Website' (name '$($site.Name)'), key 'Binding'"
                }
                if (!$site.ApplicationPool) {
                    $site.ApplicationPool = 'DefaultAppPool'
                }

                $matchingWebAppPool = $applicationPool.Where({ $_.Name -ieq $site.ApplicationPool })

                Write-Log -Info "Preparing website '$($site.Name)', Port '$($site.Port)', PhysicalPath '$($site.PhysicalPath)', ApplicationPool '$($site.ApplicationPool)'"

                $depends = @()
                if (!$directoriesToCreate.ContainsKey($site.PhysicalPath)) { 
                    File "WebsiteDir_$($site.Name)" {
                        DestinationPath = $site.PhysicalPath
                        Ensure = 'Present'
                        Type = 'Directory'
                    }
                    $directoriesToCreate[$site.PhysicalPath] = $true
                    $depends += "[File]WebsiteDir_$($site.Name)"
                }

                if ($matchingWebAppPool) {
                    $depends += "[cAppPool]AppPool_$($matchingWebAppPool.Name)"
                }

                if ($binding.CertificateSelfSigned) {
                    $depends += "[cSelfSignedCert]MyCert"
                }

                cWebsite "Website_$($site.Name)" { 
                    Name   = $site.Name
                    Ensure = 'Present'
                    State  = 'Started'
                    BindingInfo = foreach ($binding in $site.Binding) {
                        if (!$binding.Port) {
                            throw "Missing binding port - token 'Website' (name '$($site.Name)'), key 'Binding'"
                        }
                        if ($binding.Protocol -ne 'https' -and ($binding.CertificateSelfSigned -or $binding.CertificateStoreName -or $binding.CertificateThumbprint)) {
                            throw "Binding protocol is not https but has certificate settings, please set protocol to https or remove certificate settings - token 'Website' (name '$($site.Name)'), key 'Binding'"
                        }
                        if ($binding.CertificateSelfSigned) { 
                            OBJ_cWebBindingInformation {
                                Port = $binding.Port
                                Protocol = if ($binding.ContainsKey('Protocol')) { $binding.Protocol } else { 'http' }
                                HostName = $binding.HostName
                                IPAddress = $binding.IPAddress
                                SelfSignedCertificate = $true
                            }
                        } else {
                            OBJ_cWebBindingInformation {
                                Port = $binding.Port
                                Protocol = if ($binding.ContainsKey('Protocol')) { $binding.Protocol } else { 'http' }
                                HostName = $binding.HostName
                                IPAddress = $binding.IPAddress
                                CertificateStoreName = if ($binding.ContainsKey('CertificateStoreName')) { $binding.CertificateStoreName } else { 'My' }
                                CertificateThumbprint = $binding.CertificateThumbprint
                            }
                        }
                    }
                    PhysicalPath = $site.PhysicalPath
                    ApplicationPool = $site.ApplicationPool
                    DependsOn = $depends
                }

                if (!$matchingWebAppPool) { 
                    Write-Log -Warn "Web application pool ('$($site.ApplicationPool)') is not configured (website '$($site.Name)') - ACL will not be set. Please add this pool to 'ApplicationPool' token."
                } else {
                    $aclUserName = $null
                    if ($matchingWebAppPool.Identity -eq 'ApplicationPoolIdentity') {
                        $aclUserName = "IIS AppPool\$($matchingWebAppPool.Name)"
                    } elseif ($matchingWebAppPool.Identity -eq 'SpecificUser') {
                        $aclUserName = $matchingWebAppPool.Credential.UserName
                    } 

                    if ($aclUserName) { 
                        Write-Log -Info "Preparing ACL - R for directory '$($site.PhysicalPath)' to user '$aclUserName'"

                        cSimpleAcl "WebsiteAcl_$($site.Name)" {
                            Path = $site.PhysicalPath
                            Ensure = 'Present'
                            Username = $aclUserName
                            Permission = 'Read'
                            Type = 'Allow'
                            Inherit = $true
                            DependsOn = "[cWebsite]Website_$($site.Name)"
                        }
                    }
                }

                if ($site.AuthenticationMethodsToEnable) {
                    Write-Log -Info "Enabling following authentication methods: $($site.AuthenticationMethodsToEnable -join ', ') on site '$($site.Name)'"
                    foreach ($authMethodToEnable in $site.AuthenticationMethodsToEnable) {
                        cIISWebsiteAuthentication "$($site.Name)_Auth$authMethodToEnable" {
                            WebsiteName = $site.Name
                            Ensure = 'Present'
                            AuthenticationMethod = $authMethodToEnable
                        }
                    }
                }

                if ($site.AuthenticationMethodsToDisable) {
                    Write-Log -Info "Enabling following authentication methods: $($site.AuthenticationMethodsToDisable -join ', ') on site '$($site.Name)'"
                    foreach ($authMethodToDisable in $site.AuthenticationMethodsToDisable) {
                        cIISWebsiteAuthentication "$($site.Name)_Auth$authMethodToDisable" {
                            WebsiteName = $site.Name
                            Ensure = 'Absent'
                            AuthenticationMethod = $authMethodToDisable
                        }
                    }
                }
            
            }

            foreach ($virtualDir in $virtualDirectory) {
                if (!$virtualDir.Name) {
                    throw "Missing virtual directory name - token 'VirtualDirectory', key 'Name'"
                }
                if (!$virtualDir.PhysicalPath) {
                    throw "Missing virtual directory physical path - token 'VirtualDirectory' (name '$($virtualDir.Name)'), key 'PhysicalPath'"
                }
                if (!$virtualDir.Website) {
                    throw "Missing virtual directory website - token 'VirtualDirectory' (name '$($virtualDir.Name)'), key 'Website'"
                }

                $depends = @()
                $matchingWebsite = $website.Where({ $_.Name -ieq $virtualDir.Website })

                if ($matchingWebsite) {
                    $depends += "[cWebsite]Website_$($matchingWebsite.Name)"
                }

                if (!$directoriesToCreate.ContainsKey($virtualDir.PhysicalPath)) { 
                    File "VirtualDirectoryDir_$($virtualDir.Name)" {
                        DestinationPath = $virtualDir.PhysicalPath
                        Ensure = 'Present'
                        Type = 'Directory'
                    }
                    $directoriesToCreate[$virtualDir.PhysicalPath] = $true
                    $depends += "[File]VirtualDirectoryDir_$($virtualDir.Name)"
                }

                cWebVirtualDirectory "VirtualDirectory_$($virtualDir.Name)" {
                    Name = $virtualDir.Name
                    Website = $virtualDir.Website
                    WebApplication = ''
                    PhysicalPath = $virtualDir.PhysicalPath
                    Ensure = 'Present'
                    DependsOn = $depends
                }

            }
      
            foreach ($webApp in $webApplication) {
                if (!$webApp.Name) {
                    throw "Missing web application name - token 'WebApplication', key 'Name'"
                }
                if (!$webApp.PhysicalPath) {
                    throw "Missing web application physical path - token 'WebApplication' (name '$($webApp.Name)'), key 'PhysicalPath'"
                }
                if (!$webApp.Website) {
                    throw "Missing web application website - token 'WebApplication' (name '$($webApp.Name)'), key 'Website'"
                }
            
                $matchingWebsite = $website.Where({ $_.Name -ieq $webApp.Website })
                $matchingWebAppPool = $applicationPool.Where({ $_.Name -ieq $webApp.ApplicationPool })

                Write-Log -Info "Preparing web application '$($webApp.Name)', PhysicalPath '$($webApp.PhysicalPath)', Website '$($webApp.Website)', ApplicationPool '$($webApp.ApplicationPool)'"

                $depends = @()

                if ($matchingWebsite) {
                    $depends += "[cWebsite]Website_$($matchingWebsite.Name)"
                }

                if ($matchingWebAppPool) {
                    $depends += "[cAppPool]AppPool_$($matchingWebAppPool.Name)"
                }

                if (!$directoriesToCreate.ContainsKey($webApp.PhysicalPath)) { 
                    File "WebApplicationDir_$($webApp.Name)" {
                        DestinationPath = $webApp.PhysicalPath
                        Ensure = 'Present'
                        Type = 'Directory'
                    }
                    $directoriesToCreate[$webApp.PhysicalPath] = $true
                    $depends += "[File]WebApplicationDir_$($webApp.Name)"
                }
                cWebApplication "WebApplication_$($webApp.Name)" {
                    Name = $webApp.Name
                    Ensure = 'Present'
                    Website = $webApp.Website
                    WebAppPool = $webApp.ApplicationPool
                    PhysicalPath = $webApp.PhysicalPath
                    DependsOn = $depends
                }

                if (!$matchingWebAppPool) { 
                    Write-Log -Warn "Web application pool ('$($webAppPool.ApplicationPool)') is not configured (web application '$($webApp.Name)') - ACL will not be set. Please add this pool to 'ApplicationPool' token."
                } else {
                    $aclUserName = $null
                    if ($matchingWebAppPool.Identity -eq 'ApplicationPoolIdentity') {
                        $aclUserName = "IIS AppPool\$($matchingWebAppPool.Name)"
                    } elseif ($matchingWebAppPool.Identity -eq 'SpecificUser') {
                        $aclUserName = $matchingWebAppPool.Credential.UserName
                    } 

                    if ($aclUserName) { 
                        Write-Log -Info "Preparing ACL - R for directory '$($site.PhysicalPath)' to user '$aclUserName'"

                        cSimpleAcl "WebApplicationAcl_$($webApp.Name)" {
                            Path = $webApp.PhysicalPath
                            Ensure = 'Present'
                            Username = $aclUserName
                            Permission = 'Read'
                            Type = 'Allow'
                            Inherit = $true
                            DependsOn = "[cWebApplication]WebApplication_$($webApp.Name)"
                        }
                    }
                }
            }
        }
    }
}