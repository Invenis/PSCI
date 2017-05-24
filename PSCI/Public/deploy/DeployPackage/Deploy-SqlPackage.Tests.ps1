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

Describe -Tag "PSCI.unit" "Deploy-SqlPackage" {
    InModuleScope PSCI {

        $global:sqlsInvoked = @()
        Mock Invoke-Sql { 
            $global:sqlsInvoked += $InputFile 
        }
        #Mock Resolve-PathRelativeToProjectRoot { return '.' }

        function New-SqlTestPackage {
            New-Item -Path 'sqls' -ItemType Directory -Force
            New-Item -Path 'sqls\dir1' -ItemType Directory -Force
            New-Item -Path 'sqls\dir1\test1.sql' -ItemType File -Force
            New-Item -Path 'sqls\dir1\test10.sql' -ItemType File -Force
            New-Item -Path 'sqls\dir1\test2.sql' -ItemType File -Force
            New-Item -Path 'sqls\dir2' -ItemType Directory -Force
            New-Item -Path 'sqls\dir2\test1.sql' -ItemType File -Force
        }

        function Remove-SqlTestPackage {
            Remove-Item -LiteralPath 'sqls' -Force -Recurse -ErrorAction SilentlyContinue
        }

        Context "when invoked with default parameters" {
         
            try { 
                New-SqlTestPackage
                $global:sqlsInvoked = @()
                Deploy-SqlPackage -PackageName 'sqls' -ConnectionString 'test'

                It "should invoke sqls in appropriate order" {
                    $global:sqlsInvoked.Count | Should Be 4
                    $global:sqlsInvoked[0] | Should Be (Resolve-Path -LiteralPath 'sqls\dir1\test1.sql').ProviderPath
                    $global:sqlsInvoked[1] | Should Be (Resolve-Path -LiteralPath 'sqls\dir1\test10.sql').ProviderPath
                    $global:sqlsInvoked[2] | Should Be (Resolve-Path -LiteralPath 'sqls\dir1\test2.sql').ProviderPath
                    $global:sqlsInvoked[3] | Should Be (Resolve-Path -LiteralPath 'sqls\dir2\test1.sql').ProviderPath
                }
            } finally {
                Remove-SqlTestPackage
            }
        }

        Context "when invoked with SqlDirectories" {
            try { 
                New-SqlTestPackage
                $global:sqlsInvoked = @()
                Deploy-SqlPackage -PackageName 'sqls' -ConnectionString 'test' -SqlDirectories 'dir1'

                It "should invoke sqls in appropriate order" {
                    $global:sqlsInvoked.Count | Should Be 3
                    $global:sqlsInvoked[0] | Should Be (Resolve-Path -LiteralPath 'sqls\dir1\test1.sql').ProviderPath
                    $global:sqlsInvoked[1] | Should Be (Resolve-Path -LiteralPath 'sqls\dir1\test10.sql').ProviderPath
                    $global:sqlsInvoked[2] | Should Be (Resolve-Path -LiteralPath 'sqls\dir1\test2.sql').ProviderPath
                }
            } finally {
                Remove-SqlTestPackage
            }
        }

        Context "when invoked with CustomSortOrder" {
            try { 
                New-SqlTestPackage
                $global:sqlsInvoked = @()
                Deploy-SqlPackage -PackageName 'sqls' -ConnectionString 'test' -CustomSortOrder @('test10.sql', 'dir2\\test1.sql')

                It "should invoke sqls in appropriate order" {
                    $global:sqlsInvoked.Count | Should Be 4
                    $global:sqlsInvoked[0] | Should Be (Resolve-Path -LiteralPath 'sqls\dir1\test10.sql').ProviderPath
                    $global:sqlsInvoked[1] | Should Be (Resolve-Path -LiteralPath 'sqls\dir2\test1.sql').ProviderPath
                    $global:sqlsInvoked[2] | Should Be (Resolve-Path -LiteralPath 'sqls\dir1\test1.sql').ProviderPath
                    $global:sqlsInvoked[3] | Should Be (Resolve-Path -LiteralPath 'sqls\dir1\test2.sql').ProviderPath
                    
                }
            } finally {
                Remove-SqlTestPackage
            }
        }

        Context "when invoked with Exclude" {
            try { 
                New-SqlTestPackage
                $global:sqlsInvoked = @()
                Deploy-SqlPackage -PackageName 'sqls' -ConnectionString 'test' -Exclude @('test10.sql', 'dir1\\test1.sql')

                It "should not invoke excluded sqls" {
                    $global:sqlsInvoked.Count | Should Be 2
                    $global:sqlsInvoked[0] | Should Be (Resolve-Path -LiteralPath 'sqls\dir1\test2.sql').ProviderPath
                    $global:sqlsInvoked[1] | Should Be (Resolve-Path -LiteralPath 'sqls\dir2\test1.sql').ProviderPath
                    
                }
            } finally {
                Remove-SqlTestPackage
            }
        }
        
    }
}
