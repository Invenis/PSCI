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

Configuration ConfigureIISWebApp {
    param ($NodeName, $Environment, $Tokens)
    
    Import-DSCResource -Module cIIS
    Import-DSCResource -Module xWebAdministration

    Node $NodeName {

        xWebAppPool PSCITestAppPool { 
            Name   = $Tokens.WebServerProvision.AppPoolName 
            managedRuntimeVersion = 'v4.0'
            managedPipelineMode = 'Integrated'
            Ensure = 'Present' 
        }

        File PSCITestWebsiteDir {
            DestinationPath = $Tokens.WebServerProvision.WebsitePhysicalPath
            Ensure = 'Present'
            Type = 'Directory'
            DependsOn = @('[xWebAppPool]PSCITestAppPool')
        }

        xWebsite PSCIWebsite { 
            Name   = $Tokens.WebServerProvision.WebsiteName
            ApplicationPool = $Tokens.WebServerProvision.AppPoolName 
            Ensure = 'Present' 
            BindingInfo = MSFT_xWebBindingInformation { 
                Protocol = 'http'
                Port = $Tokens.WebServerProvision.WebsitePort
            } 
            PhysicalPath = $Tokens.WebServerProvision.WebsitePhysicalPath
            State = 'Started' 
            DependsOn = @('[File]PSCITestWebsiteDir')
        } 
        

        cIISWebsiteAuthentication PSCIWebsiteWindowsAuth {
            WebsiteName =  $Tokens.WebServerProvision.WebsiteName
            Ensure = 'Present'
            AuthenticationMethod = 'Windows'
            DependsOn = @('[xWebsite]PSCIWebsite')
        }

        cIISWebsiteAuthentication PSCIWebsiteAnonymousAuth {
            WebsiteName =  $Tokens.WebServerProvision.WebsiteName
            Ensure = 'Present'
            AuthenticationMethod = 'Anonymous'
            DependsOn = @('[xWebsite]PSCIWebsite')
        }

    }
}