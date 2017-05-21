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

Describe -Tag "PSCI.unit" "Get-UpdateKeyValueCmdParams" {
    InModuleScope PSCI {
    
        $testFileName = "$PSScriptRoot\Get-UpdateKeyValueCmdParams.test"

        function New-TestFile {
            Set-Content -Path $testFileName -Value @'
key1=value1
 key\2 = value2

[Section]
key3=value3
key4= value4
key5=
key6=value6
app.webservice.password=zzz
'@
        }

        Context "when supplied a file with multiple key=value lines" {

            It "should properly update the lines" {

                try { 
                    
                    New-TestFile

                    $configValues = @('key1=newValue1', 'key\2=newValue2', 'key3=value3', 'key5=c:\a\b', 'key6=', 'keyNew=newValue', 'app.webservice.password=123')

                    $params = Get-UpdateKeyValueCmdParams -ConfigFiles $testFileName -ConfigValues $configValues
                    $result = Invoke-Command @params
                    Write-Host $result

                    $content = [IO.File]::ReadAllText($testFileName)
                        $content | Should Be @'
key1=newValue1
 key\2 =newValue2

[Section]
key3=value3
key4= value4
key5=c:\\a\\b
key6=
app.webservice.password=123
keyNew=newValue
'@

                    $result | Should Not Be $null
                    $result.Count | Should Be 8
                    $result[0] | Should Match "Key 'key1' - value set to 'newValue1'"
                    $result[1] | Should Match "Key 'key\\2' - value set to 'newValue2'"
                    $result[2] | Should Match "Key 'key3' - value is already 'value3'"
                    $result[3] | Should Match "Key 'key5' - value set to 'c:\\\\a\\\\b'"
                    $result[4] | Should Match "Key 'key6' - value set to ''"
                    $result[5] | Should Match "Key 'keyNew' not found - adding with value 'newValue'"
                    $result[6] | Should Match "Key 'app.webservice.password' - value set to '123'"

                } finally {
                    Remove-Item -LiteralPath $testFileName -Force -ErrorAction SilentlyContinue
                }

            }
        }

        Context "when FailIfCannotMatch=true and cannot match" {

            It "should fail" {
                try {
                    New-TestFile
                    $params = Get-UpdateKeyValueCmdParams -ConfigFiles $testFileName -ConfigValues 'keyNotFound=test' -FailIfCannotMatch
                    try { 
                        Invoke-Command @params 
                    } catch {
                        Write-Host $_
                        return
                    }
                    0 | Should Be 1
                } finally {
                    Remove-Item -LiteralPath $testFileName -Force -ErrorAction SilentlyContinue
                }
            }
        }
       
    }
}
