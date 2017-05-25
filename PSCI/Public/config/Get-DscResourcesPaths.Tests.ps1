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

Import-Module -Name "$PSScriptRoot\..\..\PSCI.psd1" -Force

Describe -Tag "PSCI.unit" "Get-DscResourcesPaths" {

    InModuleScope PSCI {

        Context "when supplied empty ModuleNames" {

            $result = Get-DscResourcesPaths

            It "should return null" {
                $result | Should Be $null
            }
        }

        Context "when supplied with some ModuleNames" {

            $moduleNames = @('xWebAdministration', 'cIIS', 'rchaganti') | Sort
            $moduleNamesWildcard = @('xWebAdministration.*', 'cIIS', 'rchaganti') | Sort
            $result = Get-DscResourcesPaths -ModuleNames $moduleNames

            It "should return proper paths" {
                $expectedSrcPaths = Get-ChildItem -Path "$PSScriptRoot\..\..\dsc" -Directory -Recurse -Include $moduleNamesWildcard | Sort -Property Name | Select-Object -ExpandProperty FullName
                $expectedDstPaths = $moduleNames | Foreach-Object { Join-Path -Path 'C:\Program Files\WindowsPowerShell\Modules' -ChildPath $_ }

                $result.Count | Should Be $moduleNames.Count
                $result.SrcPath | Should Be $expectedSrcPaths
                $result.DstPath | Should Be $expectedDstPaths
            }

        }

        Context "when supplied with non-existing ModuleName" {
            $moduleNames = 'NonExisting'

            $fail = $false
            try { 
                $result = Get-DscResourcesPaths -ModuleNames $moduleNames
            } catch {
                $fail = $true  
            } 

            It "should throw exception" {
                $fail | Should Be $true
            }

        }
       
    }
}
