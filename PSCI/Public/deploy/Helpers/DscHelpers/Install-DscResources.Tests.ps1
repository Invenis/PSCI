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

Import-Module -Name "$PSScriptRoot\..\..\..\..\PSCI.psd1" -Force

Describe -Tag "PSCI.unit" "Install-DscResources" {

    InModuleScope PSCI {

        $Global:loggedMessage = ''
        $moduleNames = @('cIIS', 'rchaganti', 'xWebAdministration')

        $Global:writeLogMock = {
            $Global:loggedMessage += $Message
            Write-Host $Message
            if ($Critical) {
                throw $Message
            }
        } 

        Mock Write-Log $Global:writeLogMock

        InModuleScope PSCI {
           Mock Write-Log $Global:writeLogMock
        }

        Context "when ModuleNames is empty" {

            $Global:loggedMessage = ''
            Install-DscResources

            It "should not do anything" {
                $Global:loggedMessage | Should Be ''
            }
        }

        Context "when supply non-existing ModuleName" {
            $fail = $false
            
            try { 
                Install-DscResources -ModuleNames 'NonExisting'
            } catch {
                $fail = $true
            }

            It "should throw exception" {
                $fail | Should Be $true
            }
        }

        Context "when installing to localhost" {
            $expectedDst = (Get-DscResourcesPaths $moduleNames).DstPath
            Remove-Item -LiteralPath $expectedDst -Force -Recurse -ErrorAction SilentlyContinue

            Install-DscResources -ModuleNames $moduleNames

            It "should copy modules" {
                Test-Path -LiteralPath $expectedDst | Should Be @($true, $true, $true)
            }

            It "should not copy Examples directory" {
                Test-Path -LiteralPath ("{0}\Examples" -f $expectedDst[2]) | Should Be $false
            }
        }

        Context "when installing to non-localhost" {

            Mock Test-ComputerNameIsLocalhost { return $false }

            $expectedDst = (Get-DscResourcesPaths $moduleNames).DstPath
            Remove-Item -LiteralPath $expectedDst -Force -Recurse -ErrorAction SilentlyContinue

            if ($Env:PSCIWinRmUser) {
               $cred = ConvertTo-PSCredential -User $Env:PSCIWinRmUser -Password $Env:PSCIWinRmPassword
               $connectionParams = New-ConnectionParameters -Nodes 'localhost' -Credential $cred
            }
            else {
                $connectionParams = New-ConnectionParameters -Nodes 'localhost'
            }
            Install-DscResources -ModuleNames $moduleNames -ConnectionParams $connectionParams

            It "should copy modules" {
                Test-Path -LiteralPath $expectedDst | Should Be @($true, $true, $true)
            }

            It "should not copy Examples directory" {
                Test-Path -LiteralPath ("{0}\Examples" -f $expectedDst[2]) | Should Be $false
            }
        }

       
    }
}
