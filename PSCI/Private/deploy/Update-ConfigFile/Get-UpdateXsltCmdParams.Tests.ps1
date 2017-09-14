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

Import-Module -Name "$PSScriptRoot\..\..\..\PSCI.psd1"

Describe -Tag "PSCI.unit" "Get-UpdateXsltCmdParams" {
    InModuleScope PSCI {

        $testFileName = "$PSScriptRoot\Get-UpdateXsltCmdParams.test"

        function New-TestFile {
            Set-Content -Path $testFileName -Value @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <appSettings>
    <add key="key1" value="value1" />
    <add key="key2" value="&amp;" />
  </appSettings>
</configuration>
'@
        }

        $xslt = @'
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="configuration/appSettings/add[@key='key1']">
    <add key="keyNew" value="newValue1" />
  </xsl:template>
</xsl:stylesheet>
'@

        Context "when supplied a file with multiple keys" {
            It "should properly update the file basing on xslt provided in string" {

                try { 
                    New-TestFile

                    $params = Get-UpdateXsltCmdParams -ConfigFiles $testFileName -XsltBody $xslt
                    $result = Invoke-Command @params
                    Write-Host $result

                    $content = [IO.File]::ReadAllText($testFileName)
                        $content | Should Be @'
<?xml version="1.0" encoding="utf-8"?><configuration>
  <appSettings>
    <add key="keyNew" value="newValue1" />
    <add key="key2" value="&amp;" />
  </appSettings>
</configuration>
'@

                } finally {
                    Remove-Item -LiteralPath $testFileName -Force -ErrorAction SilentlyContinue
                }

            }

            It "should properly update the file basing on xslt provided in file" {

                $xsltFilename = "$PSScriptRoot\Get-UpdateXsltCmdParams.xslt"
                try { 
                    New-TestFile
                    New-Item -Path $xsltFilename -Force -ItemType File -Value $xslt

                    $params = Get-UpdateXsltCmdParams -ConfigFiles $testFileName -XsltFilename $xsltFilename
                    $result = Invoke-Command @params
                    Write-Host $result

                    $content = [IO.File]::ReadAllText($testFileName)
                        $content | Should Be @'
<?xml version="1.0" encoding="utf-8"?><configuration>
  <appSettings>
    <add key="keyNew" value="newValue1" />
    <add key="key2" value="&amp;" />
  </appSettings>
</configuration>
'@

                } finally {
                    Remove-Item -LiteralPath $testFileName -Force -ErrorAction SilentlyContinue
                    Remove-Item -LiteralPath $xsltFilename -Force -ErrorAction SilentlyContinue
                }
            }

        }

       
    }
}
