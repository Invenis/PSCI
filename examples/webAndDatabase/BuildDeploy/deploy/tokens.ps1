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

<#
This file contains tokens, i.e. variables that can be different across environments or nodes.
Resolved $Tokens variable is available in steps (DSC and functions).
Tokens are inherited from parent environments, so e.g. all Tokens defined in 'Default' environment (default parent of all environments) are available in 'Local' environment,
and child tokens can override parent tokens.

If token value is a string, you can use placeholders ${TokenName} where TokenName is another token name, or predefined 'Node' (destination node name).
If token value is a scriptblock, you can use variables $Tokens, $Node and $Environment.
#>

Environment Default {
   
    # Credentials used during deployment - sensitive data can be stored in separate file (e.g. tokensSensitive.ps1)
    Tokens Remoting @{
        RemotingCredential = { ConvertTo-PSCredential -User $Tokens.Remoting.UserName -Password $Tokens.Remoting.Password }
        MSDeployDestination = { New-MsDeployDestinationString `
							-Url ('http://{0}/MsDeployAgentService' -f $Node) `
							-UserName $Tokens.Remoting.UserName `
                            -Password $Tokens.Remoting.Password }
    }

    # IIS configuration
    Tokens WebConfig @{
        AppPoolName = 'PSCI_TestAppPool'
        WebsiteName = 'PSCI_TestWebsite'
        WebsitePort = 88
        WebsitePhysicalPath = 'c:\inetpub\wwwroot\PSCI_TestWebsite'
    }

    # Tokens used to update Web.config file - all occurrences of '${TestConnectionString}' string will be replaced
    Tokens WebTokens @{
        TestConnectionString = { $Tokens.DatabaseConfig.ConnectionString }
    }

    # Tokens related to database deployment
    Tokens DatabaseConfig @{
        DatabaseName = 'PSCITest'
        ConnectionString = 'Server=(local)\SQL2014;Database=master;User ID=sa;Password=Password12!'
        DropDatabase = $true
    }
}

Environment Test {

}

Environment UAT {
    Tokens WebConfig @{
        AppPoolName = 'PSCI_UATAppPool'
        WebsiteName = 'PSCI_UATWebsite'
        WebsitePort = 888
        WebsitePhysicalPath = 'c:\inetpub\wwwroot\PSCI_UATWebsite'
    }

    Tokens DatabaseConfig @{
        ConnectionString = 'Server=${Node};Database=${DatabaseName};Integrated Security=SSPI'
        DropDatabase = $false
    }
}
