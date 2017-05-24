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

Import-Module -Name "$PSScriptRoot\..\..\..\PSCI.psd1" -Force

Describe -Tag "PSCI.unit" "Get-UpdateXdtCmdParams" {
    InModuleScope PSCI {

        $testFileName = "$PSScriptRoot\Get-UpdateXdtCmdParams.test"

        function New-TestFile {
            Set-Content -Path $testFileName -Value @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <appSettings>
    <add key="key1" value="value1" />
    <add key="key2" value="&amp;" />
    <add key="key3" value="value3" />
  </appSettings>
</configuration>
'@
        }

        $xdt = @'
<?xml version="1.0"?>
<configuration xmlns:xdt="http://schemas.microsoft.com/XML-Document-Transform">
    <appSettings>
        <add key="key1" value="newValue1" xdt:Transform="SetAttributes" xdt:Locator="Match(key)" />
        <add key="key3" xdt:Transform="Remove" xdt:Locator="Match(key)" />
    </appSettings>
</configuration>
'@

        Context "when supplied a file with multiple keys" {
            It "should properly update the file basing on xdt provided in string" {

                try { 
                    New-TestFile

                    $params = Get-UpdateXdtCmdParams -ConfigFiles $testFileName -XdtBody $xdt
                    $result = Invoke-Command @params
                    Write-Host $result

                    $content = [IO.File]::ReadAllText($testFileName)
                    $content | Should Be @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <appSettings>
    <add key="key1" value="newValue1" />
    <add key="key2" value="&amp;" />
  </appSettings>
</configuration>

'@
                } finally {
                    Remove-Item -LiteralPath $testFileName -Force -ErrorAction SilentlyContinue
                }

            }

            It "should properly update the file basing on xdt provided in file" {

                $xdtFilename = 'Get-UpdateXdtCmdParams.xdt'
                try { 
                    New-TestFile
                    New-Item -Path $xdtFilename -Force -ItemType File -Value $xdt

                    $params = Get-UpdateXdtCmdParams -ConfigFiles $testFileName -XdtFilename $xdtFilename
                    $result = Invoke-Command @params
                    Write-Host $result

                    $content = [IO.File]::ReadAllText($testFileName)
                    $content | Should Be @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <appSettings>
    <add key="key1" value="newValue1" />
    <add key="key2" value="&amp;" />
  </appSettings>
</configuration>

'@

                } finally {
                    Remove-Item -LiteralPath $testFileName -Force -ErrorAction SilentlyContinue
                    Remove-Item -LiteralPath $xdtFilename -Force -ErrorAction SilentlyContinue
                }
            }

        }
    }
}
