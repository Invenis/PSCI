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

function Deploy-MsDeployPackage {
    <#
    .SYNOPSIS
    Deploys a msdeploy package.

    .DESCRIPTION
    Deploys a package created with cmdlet Build-WebPackage or Build-MsBuildPackage.
    If $TokensForConfigFiles is provided, it resolves all token placeholders '${Name}' in all .config files inside the msdeploy package. 
    Then it runs msdeploy.exe for the package $PackagePath\$PackageName.zip.

    .PARAMETER PackageName
    Name of the package. It determines PackagePath if it's not provided.

    .PARAMETER PackageType
    Type of the package - Web or Dir (used e.g. for console application).

    .PARAMETER Node
    Server where the package will be deployed to.

    .PARAMETER Environment
    Name of the environment where the package will be deployed to. Used for applying XDT transformations by convention (*.<EnvOrNodeName>.config).

    .PARAMETER MsDeployDestinationString
    Destination string for msdeploy. Created with cmdlet New-MsDeployDestinationString.

    .PARAMETER MsDeployAddParameters
    Additional parameters that will be passed to msdeploy.exe command line.

    .PARAMETER PackagePath
    Path to the package containing the msdeploy package. If not provided, $PackagePath = $PackagesPath\$PackageName, where $PackagesPath is taken from global variable.

    .PARAMETER TokensForConfigFiles
    A hashtable containing tokens that will be used for replacing placeholders '${Name}' in all .config files inside the msdeploy package.

    .PARAMETER ValidateTokensExistence
    If true and a placeholder that not exists in $TokensForConfigFiles table is found, an exception will be thrown.

    .PARAMETER SkipDir
    List of directories to skip. Passed in '-skip:Directory' msdeploy parameter.

    .PARAMETER SkipFile
    List of files to skip. Passed in '-skip:File' msdeploy parameter.

    .PARAMETER UseChecksum
    Whether to use checksum for directory sync. Note checksum sometimes causes issues in msdeploy - see http://stackoverflow.com/questions/20240261/notimplementedexception-in-msdeploy-when-using-usechecksum.

    .PARAMETER Website
    IIS website where the package will be deployed to. Only used if PackageType = Web.

    .PARAMETER WebApplication
    IIS web application name under which the package will be deployed to. Only used if PackageType = Web.

    .PARAMETER PhysicalPath
    Physical path where the package will be copied to. Only used if PackageType = Dir.
    If PackageType = Web, physical path is taken from web application (IIS should be provisioned first).

    .PARAMETER FilesToIgnoreTokensExistence
    List of .config files which will not have token placeholders replaced. 
    Useful especially if another application uses the same variable placeholder as PSCI (e.g. NLog).

    .PARAMETER TokenWildcard
    Wildcard to use to recognize config files where tokens should be replaced.

    .PARAMETER TokenRegex
    Regex used to find tokens in the file. Whole tokenRegex should match whole string to replace, first capture group should match name of the token.

    .PARAMETER TokenUpdateMode
    Mode of tokens update:
    ReplaceInConfigFiles - traverses all $TokenWildcard (.config) files and replaces $TokenRegex (${var})
    SetParam - passes tokens as -setParam to msdeploy command line.

    .LINK
    Build-WebPackage
    New-MsDeployDestinationString

    .EXAMPLE
    Deploy-MsDeployPackage -PackageName 'MyProject' -PackageType 'Web' -Node 'localhost' -MsDeployDestinationString (New-MsDeployDestinationString ...)

    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $PackageName, 

        [Parameter(Mandatory=$true)]
        [ValidateSet('Web', 'Dir')]
        [string] 
        $PackageType, 

        [Parameter(Mandatory=$true)]
        [string] 
        $Node,

        [Parameter(Mandatory=$true)]
        [string] 
        $MsDeployDestinationString, 

        [Parameter(Mandatory=$false)]
        [string] 
        $Environment, 

        [Parameter(Mandatory=$false)]
        [string] 
        $MsDeployAddParameters, 

        [Parameter(Mandatory=$false)]
        [string] 
        $PackagePath,        

        [Parameter(Mandatory=$false)]
        [hashtable] 
        $TokensForConfigFiles,

        [Parameter(Mandatory=$false)]
        [switch] 
        $ValidateTokensExistence = $true,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $SkipDir,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $SkipFile,

        [Parameter(Mandatory=$false)]
        [switch] 
        $UseChecksum,

        [Parameter(Mandatory=$false)]
        [string] 
        $Website,

        [Parameter(Mandatory=$false)]
        [string] 
        $WebApplication,

        [Parameter(Mandatory=$false)]
        [string] 
        $PhysicalPath,

        [Parameter(Mandatory=$false)]
        [string[]] 
        $FilesToIgnoreTokensExistence,

        [Parameter(Mandatory=$false)]
        [string] 
        $TokenWildcard = '*.config',

        [Parameter(Mandatory=$false)]
        [string] 
        $TokenRegex = '\$\{(\w+)\}',

        [Parameter(Mandatory=$false)]
        [ValidateSet('ReplaceInConfigFiles', 'SetParam')]
        [string] 
        $TokenUpdateMode = 'ReplaceInConfigFiles'
    )

    if ($PackageType -eq "Dir") {
        if (!$PhysicalPath -or [String]::IsNullOrEmpty($PhysicalPath)) {
            throw "You need to specify 'PhysicalPath' parameter for packages of type 'Dir' (package '$PackageName')."
        }
        if ($Website -or $WebApplication) {
            throw "You cannot specify 'Website' or 'WebApplication' parameters for packages of type 'Dir' (package '$PackageName')."
        }
    } elseif ($PackageType -eq "Web") {
        if ($PhysicalPath) {
           throw "You cannot specify 'PhysicalPath' parameter for packages of type 'Web' (package '$PackageName'). You need to provision IIS to setup proper PhysicalPath (using e.g. xWebAdministration)."
        }
        if (!$Website -and $WebApplication) {
           throw "You cannot specify 'WebApplication' parameter if 'Website' parameter is not provided."
        }
    }

    $configPaths = Get-ConfigurationPaths

    $packageNameLeaf = Split-Path -Path $PackageName -Leaf

    $PackagePath = Resolve-PathRelativeToProjectRoot `
                    -Path $PackagePath `
                    -DefaultPath (Join-Path -Path (Join-Path -Path $configPaths.PackagesPath -ChildPath $PackageName) -ChildPath "${packageNameLeaf}.zip") `
                    -ErrorMsg "Cannot find file '{0}' required for deployment of package '$PackageName'. Please ensure you have run the build and the package exists."
   
    if ($SkipDir) {
        foreach ($dir in $SkipDir) { 
            $MsDeployAddParameters += "-skip:Directory=`"$dir`" "
        }
    }

    if ($SkipFile) {
        foreach ($file in $SkipFile) { 
            $MsDeployAddParameters += "-skip:File=`"$file`" "
        }
    }
   
    $packageCopyPath = $PackagePath
    $removeCopy = $false

    if ($TokensForConfigFiles) {
        if ($TokenUpdateMode -eq 'SetParam') {
            $TokensForConfigFiles.GetEnumerator() | foreach { $MsDeployAddParameters += "-setParam:name='{0}',value='{1}' " -f $_.Key, $_.Value }
        } else {
            $packageDir = Split-Path -Parent $PackagePath
            $packageFile = Split-Path -Leaf $PackagePath
            $packageCopyPath = Join-Path -Path $packageDir -ChildPath ($packageFile -ireplace "zip$", "temp.zip")

            Update-TokensInZipFile -ZipFile $PackagePath -OutputFile $packageCopyPath -Tokens $TokensForConfigFiles -ValidateTokensExistence:$ValidateTokensExistence -FilesToIgnoreTokensExistence $FilesToIgnoreTokensExistence `
                -TokenWildcard $TokenWildcard -TokenRegex $TokenRegex -Environment $Environment
            $removeCopy = $true
        }
    }

    if ($PackageType -eq "Web") {
        if (!$PackagePath.ToLower().EndsWith("zip")) {
           throw "Invalid package: '$PackagePath' - expecting zip"
        }
        if ($Website -and $WebApplication) {
            $MsDeployAddParameters += "-setParam:name='IIS Web Application Name',value='${Website}\${WebApplication}' "
        } elseif ($Website) {
            $MsDeployAddParameters += "-setParam:name='IIS Web Application Name',value='${Website}' "
        } else {
            Write-Log -Warn "IISWebApplicationName not specified for package '$PackageName'. MsDeploy will use the default defined in package's SetParameters.xml."
        }

        Write-Log -Info "Deploying web package '$PackageName' to server '$Node'" -Emphasize
        Sync-MsDeployDirectory -SourcePath $packageCopyPath -DestString $MsDeployDestinationString -AddParameters $MsDeployAddParameters -UseChecksum:$UseChecksum
    } elseif ($PackageType -eq "Dir") {
        Write-Log -Info "Deploying directory package '$PackageName' to server '$Node'" -Emphasize
        if ($packageCopyPath.ToLower().EndsWith("zip")) {
            $tempDir = New-TempDirectory
            Expand-Zip -ArchiveFile $packageCopyPath -OutputDirectory $tempDir
        } else {
            $tempDir = $PackagePath
        }
        Sync-MsDeployDirectory -SourcePath $tempDir -DestinationDir $PhysicalPath -DestString $MsDeployDestinationString -AddParameters $MsDeployAddParameters -UseChecksum:$UseChecksum
        Remove-TempDirectory
    }

    if ($removeCopy) {
        Remove-Item -LiteralPath $packageCopyPath -Force
    }
}