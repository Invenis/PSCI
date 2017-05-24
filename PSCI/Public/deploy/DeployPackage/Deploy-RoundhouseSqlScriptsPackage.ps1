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

function Deploy-RoundhouseSqlScriptsPackage {
    <#
    .SYNOPSIS
    Deploys a package containing Roundhouse scripts.
    
    .PARAMETER PackageName
    Name of the package. It determines PackagePath if it's not provided.

    .PARAMETER RoundhousePath
    Path to Roundhouse executable.
    Default dir is the parent and exectuable name is rh.exe, e.g. \..\rh.exe

    .PARAMETER Credential
    Credentials to use for running Roundhouse and connecting to database (if Integrated Security).

    .PARAMETER RoundhouseArgs
    Hashtable containing Roundhouse parametres including DB name and Server.
    Full list of parameters available at: https://github.com/chucknorris/roundhouse/wiki/ConfigurationOptions

    .EXAMPLE   
    $rhArgs = @{'connectionstring' = '"Server=localhost;Database=MyDb;Integrated Security=SSPI;"'
              'sqlfilesdirectory' = 'SqlDir'
              'commandtimeout' = 32000
              'versionfile' = "version.txt"
              'env' = 'LOCAL'
              'output' = '.'
              'silent' = 'true'
             }
    
     $dbParams = @{ PackageName = 'MySqlScriptsPackage';
                    RoundhouseArgs = $rhArgs
                  }

     Deploy-RoundhouseSqlScriptsPackage @dbParams 

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $PackageName,

        [Parameter(Mandatory=$false)]
        [string] 
        $RoundhousePath,

        [Parameter(Mandatory=$true)]
        [hashtable] 
        $RoundhouseArgs,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] 
        $Credential

    )

    $configPaths = Get-ConfigurationPaths
    
    $RoundhousePath = Resolve-PathRelativeToProjectRoot `
                -Path $RoundhousePath `
                -DefaultPath (Join-Path -Path $configPaths.PackagesPath -ChildPath "$PackageName\..\rh.exe") `
                -ErrorMsg "Cannot find Roundhouse package at '{0}', which required for deployment of package '$PackageName'. Please ensure you have run the build and the package exists."
    
    $RoundhouseDir = Split-Path -Path $RoundhousePath -Parent
    
    $roundhouseArguments = ''
    
    foreach ($param in $RoundhouseArgs.GetEnumerator()) { 
        $roundhouseArguments += " /$($param.Key)=$($param.Value)" 
    }

    Start-ExternalProcess -Command $RoundhousePath -ArgumentList $roundhouseArguments -Credential $Credential -WorkingDirectory $RoundhouseDir


}