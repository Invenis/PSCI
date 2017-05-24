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

function New-MarkdownDocModule {
    <#
    .SYNOPSIS
    Generates markdown documentation for each public function from given module.

    .PARAMETER ModuleName
    Module to scan.

    .PARAMETER OutputPath
    Base output path.

    .PARAMETER GitBaseUrl
    Base Git url to generate links to source files.

    .EXAMPLE
    New-MarkdownDocModule -ModuleName 'PSCI' -OutputPath '..\PSCI.wiki'
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $ModuleName,

        [Parameter(Mandatory=$true)]
        [string]
        $OutputPath,

        [Parameter(Mandatory=$false)]
        [string]
        $GitBaseUrl = 'https://github.com/ObjectivityBSS/PSCI/tree/master'
    )

    $outputBasePath = Join-Path $OutputPath -ChildPath "api\$ModuleName"
    if ((Test-Path -Path $outputBasePath)) { 
        Write-Log -Info "Deleting directory '$outputBasePath'"
        Remove-Item -Path $outputBasePath -Recurse -Force
    }
    [void](New-Item -Path $outputBasePath -ItemType Directory -Force)

    $outputIndexString = New-Object -TypeName System.Text.StringBuilder
    $modulePath = Get-PSCIModulePath -ModuleName $ModuleName
    $readmePath = Join-Path -Path $modulePath -ChildPath 'readme.txt'
    [void]($OutputIndexString.Append("## Module $ModuleName`r`n"))
    if ((Test-Path -Path $readmePath)) {
        $readmeContents = Get-Content -Path $readmePath -ReadCount 0 | Out-String
        [void]($outputIndexString.Append($readmeContents))
    }

    $functionsToDocument = Get-AllFunctionsFromModule -ModuleName $ModuleName
    foreach ($funcInfo in $functionsToDocument) {
        $outputString = Generate-MarkdownForFunction -FunctionInfo $funcInfo -OutputIndexString $outputIndexString -ModuleName $moduleName -GitBaseUrl $GitBaseUrl
        
        $outputFilePath = Join-Path -Path $outputBasePath -ChildPath "$($funcInfo.FunctionName).md"
        $outputString.ToString() | Out-File -FilePath $outputFilePath  
    }

    $outputIndexPath = Join-Path -Path $outputBasePath -ChildPath "$ModuleName.md"
    $outputIndexString.ToString() | Out-File -FilePath $OutputIndexPath
}

function New-MarkdownDocDirectory {
    <#
    .SYNOPSIS
    Generates markdown documentation for each function from given directory.

    .PARAMETER Path
    Path to scan.

    .PARAMETER OutputPath
    Base output path.

    .PARAMETER GitBaseUrl
    Base Git url to generate links to source files.

    .EXAMPLE
    New-MarkdownDocDirectory -Path 'BuiltinSteps' -OutputPath '..\PSCI.wiki'
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter(Mandatory=$true)]
        [string]
        $OutputPath,

        [Parameter(Mandatory=$false)]
        [string]
        $GitBaseUrl = 'https://github.com/ObjectivityBSS/PSCI/tree/master'
    )

    $dirName = Split-Path -Path $Path -Leaf
    $outputBasePath = Join-Path $OutputPath -ChildPath "api\$dirName"
    if ((Test-Path -Path $outputBasePath)) { 
        Write-Log -Info "Deleting directory '$outputBasePath'"
        Remove-Item -Path $outputBasePath -Recurse -Force
    }
    [void](New-Item -Path $outputBasePath -ItemType Directory -Force)

    $outputIndexString = New-Object -TypeName System.Text.StringBuilder
    
    $moduleName = Split-Path -Path $Path -Leaf
    $readmePath = Join-Path -Path $Path -ChildPath 'readme.txt'
    [void]($OutputIndexString.Append("## $moduleName`r`n"))
    if ((Test-Path -Path $readmePath)) {
        $readmeContents = Get-Content -Path $readmePath -ReadCount 0 | Out-String
        [void]($outputIndexString.Append($readmeContents))
    }
    $functionsToDocument = Get-AllFunctionsFromDirectory -Path $Path
    foreach ($funcInfo in $functionsToDocument) {
        $outputString = Generate-MarkdownForFunction -FunctionInfo $funcInfo -OutputIndexString $outputIndexString -GitBaseUrl $GitBaseUrl
        
        $outputFilePath = Join-Path -Path $outputBasePath -ChildPath "$($funcInfo.FunctionName).md"
        $outputString.ToString() | Out-File -FilePath $outputFilePath  
    }

    $outputIndexPath = Join-Path -Path $outputBasePath -ChildPath "$dirName.md"
    $outputIndexString.ToString() | Out-File -FilePath $OutputIndexPath
}

function Escape-Markdown {
    <#
    .SYNOPSIS
    Escapes special characters for markdown.

    .PARAMETER String
    String to escape.

    .EXAMPLE
    Escape-Markdown -String '<test>'
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $String
    )

    return $String -replace '([^\\])<', '$1\<' `
                   -replace '([^\\])>', '$1\>'
}

function Get-AllFunctionsFromModule {
    <#
    .SYNOPSIS
    Gets all public functions from given module.

    .PARAMETER ModuleName
    Module name.

    .EXAMPLE
    $functionsToDocument = Get-AllFunctionsFromModule -ModuleName $ModuleName
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $ModuleName
    )

    Write-Log -Info "Getting functions from $ModuleName"
    $modulePath = Get-PSCIModulePath -ModuleName $ModuleName
    $allPs1Files = Get-ChildItem -Path $modulePath -Include "*.ps1" -Recurse | Select-Object -ExpandProperty FullName

    $result = New-Object -TypeName System.Collections.ArrayList
    foreach ($ps1File in $allPs1Files) {
        $funcName = (Split-Path -Path $ps1File -Leaf).Replace('.ps1', '')
        $cmd = Get-Command -Module $ModuleName -Name $funcName -ErrorAction SilentlyContinue
        if ($cmd) {
            $help = Get-Help -Name $funcName -ErrorAction SilentlyContinue
            [void]($result.Add([PSCustomObject]@{
                FunctionName = $funcName
                Path = $ps1File
                Command = $cmd
                Help = $help
            }))
        }
    }
    return $result.ToArray()

}

function Get-AllFunctionsFromDirectory {
    <#
    .SYNOPSIS
    Gets all functions from given directory.

    .PARAMETER Path
    Path to directory.

    .EXAMPLE
    $functionsToDocument = Get-AllFunctionsFromDirectory -Path 'c:\MyModule'
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    $allPs1Files = Get-ChildItem -Path $Path -Include "*.ps1" -Recurse | Select-Object -ExpandProperty FullName
    $result = New-Object -TypeName System.Collections.ArrayList
    foreach ($ps1File in $allPs1Files) {
        . $ps1File
        $funcName = (Split-Path -Path $ps1File -Leaf).Replace('.ps1', '')
        $cmd = Get-Command -Name $funcName -ErrorAction SilentlyContinue
        if (!$cmd) {
            throw "Cannot get command for function '$funcName'"
        }
        $help = $null
        # Get-Help does not work well for Configurations... we need to trick it it's a function
        if ($cmd.CommandType -eq 'Configuration') {

            $contents = Get-Content -Path $ps1File -ReadCount 0 | Out-String
            if ($contents -match '(?smi){.*(<#.*\.SYNOPSIS.*#>)') {
                $synopsis = $Matches[1]
                $cmdText = "function $($cmd.Name) {`r`n$synopsis`r`n}"
                Invoke-Expression $cmdText
                $help = Get-Help -Name $funcName -ErrorAction SilentlyContinue
            }
        }
        if (!$help) {
            $help = Get-Help -Name $funcName -ErrorAction SilentlyContinue
        }
        [void]($result.Add([PSCustomObject]@{
                FunctionName = $funcName
                Path = $ps1File
                Command = $cmd
                Help = $help
        }))
    }
    return $result.ToArray()
}

function Generate-MarkdownForFunction {
    <#
    .SYNOPSIS
    Generates markdown for specified function.

    .PARAMETER FunctionInfo
    FunctionInfo object as created by Get-AllFunctionsFrom* function.

    .PARAMETER OutputIndexString
    String builder for index markdown.

    .PARAMETER ModulePath
    Name of the module the function belongs to.

    .PARAMETER GitBaseUrl
    Base Git url to generate links to source files.

    .EXAMPLE
    $outputString = Generate-MarkdownForFunction -FunctionInfo $funcInfo -OutputIndexString $outputIndexString -ModulePath $modulePath -GitBaseUrl $GitBaseUrl
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [object]
        $FunctionInfo,

        [Parameter(Mandatory=$true)]
        [object]
        $OutputIndexString,

        [Parameter(Mandatory=$false)]
        [string]
        $ModuleName,

        [Parameter(Mandatory=$false)]
        [string]
        $GitBaseUrl
    )

    $funcName = $FunctionInfo.FunctionName
    $help = $FunctionInfo.Help
    $psciBasePathSlash = (Get-PSCIModulePath) -ireplace '\\', '/'
    if ($ModuleName) { 
        $modulePath = Get-PSCIModulePath -ModuleName $ModuleName
    } else {
        $ModuleName = Split-Path -Path (Split-Path -Path $FunctionInfo.Path -Parent) -Leaf
    }

    $arrParameterProperties = @(
        'DefaultValue',
        'PipelineInput',
        'Required'
    )

    Write-Log -Info "Generating markdown for $funcName"
   
    if ($modulePath) {
        $funcRelativeLocation = (Split-Path -Path $FunctionInfo.Path -Parent).Replace("$modulePath\", '')
        if ($funcRelativeLocation -ne $Global:currentRelativeLocation) {
            [void]($OutputIndexString.Append("`r`n### $funcRelativeLocation`r`n"))    
            $Global:currentRelativeLocation = $funcRelativeLocation
        }
    }

    $outputString = New-Object -TypeName System.Text.StringBuilder
    [void]($OutputIndexString.Append("* [[$funcName]]"))
    [void]($outputString.Append("## $funcName`r`n"))
    $gitLink = ($FunctionInfo.Path -ireplace '\\', '/').Replace($psciBasePathSlash, $GitBaseUrl)
    [void]($outputString.Append("[[$ModuleName]] -\> [$funcName.ps1]($gitLink)`r`n"))
        
    if ($help.Synopsis) {
        [void]($OutputIndexString.Append(" - $($help.Synopsis)`r`n"))
        [void]($outputString.Append("### Synopsis`r`n"))
        [void]($outputString.Append("$($help.Synopsis)`r`n"))
    } else {
        [void]($outputIndexString.Append("`r`n"))
    }

    if ($help.Syntax) {
        [void]($outputString.Append("### Syntax`r`n"))
        $syntax = ($help.Syntax | Out-String -Width 80).Trim()
        [void]($outputString.Append("``````PowerShell`r`n$syntax`r`n```````r`n"))
    }

    if ($help.Description) {
        [void]($outputString.Append("### Description`r`n"))
        [void]($outputString.Append("$($help.Description.Text)`r`n`r`n"))
    }

    if ($help.Parameters) {
        [void]($outputString.Append("### Parameters`r`n"))
        foreach ($item in $help.Parameters.Parameter) {
            [void]($outputString.Append("#### -$($item.Name)\<$($item.Type.Name)\>"))

            if ($item.defaultValue) {
                [void]($outputString.Append(" (default: $($item.defaultValue))"))
            }
            [void]($outputString.Append("`r`n"))
            if ($item.Description.Text) { 
                $escapedDescription = Escape-Markdown -String $item.Description.Text
                [void]($outputString.Append($escapedDescription))
                [void]($outputString.Append("`r`n"))
            }
            [void]($outputString.Append("`r`n<!---->`r`n"))

            $validateSetAttributes = $FunctionInfo.Command.Parameters.$($item.Name).Attributes | Where-Object { $_.TypeId.FullName -eq 'System.Management.Automation.ValidateSetAttribute' }
            if ($validateSetAttributes) {
                $validateSetStr = ($validateSetAttributes.ValidValues -replace '^$', '\<empty\>') -join ', '
                if ($validateSetStr.StartsWith(',')) {
                    $validateSetStr = '$null' + $validateSetStr
                }
                [void]($outputString.Append("- **Valid values**: $validateSetStr`r`n"))
            }

            foreach ($arrParamProperty in $arrParameterProperties){
                if ($item.$arrParamProperty){
                        [void]($outputString.Append("- **$arrParamProperty**: $($item.$arrParamProperty)`r`n"))
                }
            }
            [void]($outputString.Append("`r`n"))
        }
    }

    if ($help.Examples) {
        [void]($outputString.Append("### Examples`r`n"))
        foreach ($item in $help.Examples.Example) {
            $example = $item.title.Replace("--------------------------","").Replace("EXAMPLE","Example")
            [void]($outputString.Append("`r`n#### $example`r`n"))
            if ($item.Code) {
                [void]($outputString.Append("``````PowerShell`r`n"))
                # if code starts with ``` it means it special case - we need to put remarks inside ```. See https://connect.microsoft.com/PowerShell/feedbackdetail/view/952833.
                if (!$item.Code.StartsWith('```')) {
                    [void]($outputString.Append("$($item.Code)`r`n"))
                    [void]($outputString.Append("```````r`n"))
                }
            }
            if ($item.Remarks) {
                foreach ($remark in $item.Remarks.Text) { 
                    if ($remark -and $remark.Trim()) { 
                        [void]($outputString.Append("$($remark.Trim())`r`n"))
                    }
                }
            }
        }
    }

    return $outputString.ToString()
}