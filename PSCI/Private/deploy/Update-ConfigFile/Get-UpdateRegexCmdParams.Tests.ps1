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

Describe -Tag "PSCI.unit" "Get-UpdateRegexCmdParams" {
    InModuleScope PSCI {
    
        $testFileName = "$PSScriptRoot\Get-UpdateRegexCmdParams.test"

        function New-TestFile {
            Set-Content -Path $testFileName -Value @'
key1=value1
 key\2 = value2

[Section]
key3=value3
key4= value4
key5=
'@
        }

        Context "when supplied a file with multiple lines" {

            It "single-line regex should properly update the lines" {

                try { 
                    
                    New-TestFile

                    $regexSearch = 'key(\d)=[^\r\n]*'
                    $replaceString = 'key$1=newValue$1'

                    $params = Get-UpdateRegexCmdParams -ConfigFiles $testFileName -RegexSearch $regexSearch -ReplaceString $replaceString
                    $result = Invoke-Command @params
                    Write-Host $result

                    $content = [IO.File]::ReadAllText($testFileName)
                        $content | Should Be @'
key1=newValue1
 key\2 = value2

[Section]
key3=newValue3
key4=newValue4
key5=newValue5

'@

                } finally {
                    Remove-Item -LiteralPath $testFileName -Force -ErrorAction SilentlyContinue
                }

            }
        }
        
        Context "when FailIfCannotMatch=true and cannot match" {

            It "should fail" {
                try {
                    New-TestFile
                    $regexSearch = 'keyNotFound'
                    $replaceString = ''

                    $params = Get-UpdateRegexCmdParams -ConfigFiles $testFileName -RegexSearch $regexSearch -ReplaceString $replaceString -FailIfCannotMatch
                    
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

        Context "when FailIfCannotMatch=false and cannot match" {

            It "should succeed" {
                try {
                    New-TestFile
                    $regexSearch = 'keyNotFound'
                    $replaceString = ''

                    $params = Get-UpdateRegexCmdParams -ConfigFiles $testFileName -RegexSearch $regexSearch -ReplaceString $replaceString
                    
                    Invoke-Command @params 
                   
                } finally {
                    Remove-Item -LiteralPath $testFileName -Force -ErrorAction SilentlyContinue
                }
            }
        }

       
    }
}
