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

Describe -Tag "PSCI.unit" "Copy-Directory" {

    InModuleScope PSCI {

        function New-TestDirStructure {
            Remove-Item -LiteralPath 'testDir' -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath 'testDirOut' -Force -Recurse -ErrorAction SilentlyContinue

            New-Item -Path 'testDir\testDir1\testDir11' -ItemType Directory -Force
            New-Item -Path 'testDir\testDir1\testDir2' -ItemType Directory -Force
            New-Item -Path 'testDir\testDir2' -ItemType Directory -Force

            New-Item -Path 'testDir\testDir1\testDir11\testFile11' -ItemType File -Value 'testFile11' -Force
            New-Item -Path 'testDir\testDir1\testDir2\testFile12' -ItemType File -Value 'testFile12' -Force
            New-Item -Path 'testDir\testDir2\testFile2' -ItemType File -Value 'testFile2' -Force
        }

        function Remove-TestDirStructure {
            Remove-Item -LiteralPath 'testDir' -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath 'testDirOut' -Force -Recurse -ErrorAction SilentlyContinue
        }

        Context "when copying directory structure" {
            try {
                New-TestDirStructure
                
                Copy-Directory -Path 'testDir' -Destination 'testDirOut'
                
                It "should properly copy the structure" {
                    Test-Path -LiteralPath 'testDirOut\testDir1\testDir11\testFile11' -PathType Leaf | Should Be $true
                    Test-Path -LiteralPath 'testDirOut\testDir2\testFile2' -PathType Leaf | Should Be $true
                }
            } finally {
                Remove-TestDirStructure
            }
        }

        Context "when copying directory structure with exclude / recurse" {
            try {
                New-TestDirStructure
                
                Copy-Directory -Path 'testDir' -Destination 'testDirOut' -Exclude 'testDir2' -ExcludeRecurse
                
                It "should properly copy the structure" {
                    Test-Path -LiteralPath 'testDirOut\testDir1\testDir11\testFile11' -PathType Leaf | Should Be $true
                }

                It "should not copy the excluded directory" {
                    Test-Path -LiteralPath 'testDirOut\testDir1\testDir2' | Should Be $false
                    Test-Path -LiteralPath 'testDirOut\testDir2' | Should Be $false
                }
            } finally {
                Remove-TestDirStructure
            }
        }

        Context "when copying directory structure with exclude / not recurse" {
            try {
                New-TestDirStructure
                
                Copy-Directory -Path 'testDir' -Destination 'testDirOut' -Exclude 'testDir2' 
                
                It "should properly copy the structure" {
                    Test-Path -LiteralPath 'testDirOut\testDir1\testDir11\testFile11' -PathType Leaf | Should Be $true
                    Test-Path -LiteralPath 'testDirOut\testDir1\testDir2\testFile12' -PathType Leaf | Should Be $true
                }

                It "should not copy the excluded directory" {
                    Test-Path -LiteralPath 'testDirOut\testDir2' | Should Be $false
                }
            } finally {
                Remove-TestDirStructure
            }
        }

        Context "when copying directory structure with include / recurse" {
            try {
                New-TestDirStructure
                
                Copy-Directory -Path 'testDir' -Destination 'testDirOut' -Include 'testDir2' -IncludeRecurse
                
                It "should properly copy the structure" {
                    Test-Path -LiteralPath 'testDirOut\testDir2\testFile2' -PathType Leaf | Should Be $true
                }

                It "should not copy the not-included directory on root level" {
                    Test-Path -LiteralPath 'testDirOut\testDir1\testDir11' | Should Be $false
                }

                It "should copy the included directory even if not on root level" {
                    Test-Path -LiteralPath 'testDirOut\testDir1\testDir2\testFile12' -PathType Leaf | Should Be $true
                }
            } finally {
                Remove-TestDirStructure
            }
        }
    }
}
