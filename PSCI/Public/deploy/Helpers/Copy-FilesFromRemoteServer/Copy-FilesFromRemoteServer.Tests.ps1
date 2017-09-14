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

Describe -Tag "PSCI.unit" "Copy-FilesFromRemoteServer" {

    InModuleScope PSCI {

        $Global:loggedMessage = ''

        if ($Env:PSCIWinRmUser) {
            $cred = ConvertTo-PSCredential -User $Env:PSCIWinRmUser -Password $Env:PSCIWinRmPassword
            $connectionParams = New-ConnectionParameters -Nodes 'localhost' -Credential $cred
        }
        else {
            $connectionParams = New-ConnectionParameters -Nodes 'localhost'
        }

        $srcDir = 'c:\PSCITestDirSrc'
        $dstDir = 'c:\PSCITestDirDst'
        
        Remove-Item -LiteralPath $dstDir -Force -Recurse -ErrorAction SilentlyContinue

        function New-TestDirStructure {
            New-Item -Path "$srcDir\testFolder1\testFolder11" -ItemType Directory -Force 
            New-Item -Path "$srcDir\testFolder1\testFile2" -ItemType File -Force -Value 'test2'
            New-Item -Path "$srcDir\testFolder1\testFolder11\testFile3" -ItemType File -Force -Value 'test33'
            New-Item -Path "$srcDir\testFolder2" -ItemType Directory -Force
            New-Item -Path "$srcDir\testFolder2\testFile4" -ItemType File -Force -Value 'test444'
        }

        function Remove-TestDirStructure {
             Remove-Item -LiteralPath "$srcDir\testFolder1" -Force -Recurse -ErrorAction SilentlyContinue
             Remove-Item -LiteralPath "$srcDir\testFolder2" -Force -Recurse -ErrorAction SilentlyContinue
             Remove-Item -LiteralPath $dstDir -Force -Recurse -ErrorAction SilentlyContinue
        }

        function Validate-TestDirStructure($src, $dst) {
            Test-Path -LiteralPath $dst -PathType Container | Should Be $true
            Test-Path -LiteralPath "$dst\test1\testFile2" -PathType Leaf | Should Be $true
            (Get-Item -Path "$dst\test1\testFile2").Length | Should Be (Get-Item -Path "$src\testFolder1\testFile2").Length
            Test-Path -LiteralPath "$dst\test1\testFolder11\testFile3" -PathType Leaf | Should Be $true
            (Get-Item -Path "$dst\test1\testFolder11\testFile3").Length | Should Be (Get-Item -Path "$src\testFolder1\testfolder11\testFile3").Length
            Test-Path -LiteralPath "$dst\test2\testFile4" -PathType Leaf | Should Be $true
            (Get-Item -Path "$dst\test2\testFile4").Length | Should Be (Get-Item -Path "$src\testFolder2\testFile4").Length
        }        

        Context "when copying one non-zip file" {
            try {
                New-Item -Path "$srcDir\testFile1" -ItemType File -Force -Value 'test'

                Copy-FilesFromRemoteServer -RemotePath "$srcDir\testFile1" -Destination $dstDir -ConnectionParams $connectionParams

                It "should copy the file" {
                    Test-Path -LiteralPath $dstDir -PathType Container | Should Be $true
                    Test-Path -LiteralPath "$dstDir\testFile1" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFile1").Length | Should Be (Get-Item -Path "$srcDir\testFile1").Length
                }

            } finally {
                Remove-Item -LiteralPath 'testFile1' -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $dstDir -Force -Recurse -ErrorAction SilentlyContinue
            }
        } 

        Context "when copying several directories and files to one Destination" {
            try {
                New-Item -Path "$srcDir\testFile1" -ItemType File -Force -Value 'test'
                New-Item -Path "$srcDir\testFolder1\testFolder11" -ItemType Directory -Force 
                New-Item -Path "$srcDir\testFolder1\testFile2" -ItemType File -Force -Value 'test2'
                New-Item -Path "$srcDir\testFolder1\testFolder11\testFile3" -ItemType File -Force -Value 'test33'

                Copy-FilesFromRemoteServer -RemotePath "$srcDir\testFile1", "$srcDir\testFolder1" -Destination $dstDir -ConnectionParams $connectionParams

                It "should copy the files with structure intact" {
                    Test-Path -LiteralPath $dstDir -PathType Container | Should Be $true
                    Test-Path -LiteralPath "$dstDir\testFile1" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFile1").Length | Should Be (Get-Item -Path "$srcDir\testFile1").Length
                    Test-Path -LiteralPath "$dstDir\testFile2" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFile2").Length | Should Be (Get-Item -Path "$srcDir\testFolder1\testFile2").Length
                    Test-Path -LiteralPath "$dstDir\testFolder11\testFile3" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFolder11\testFile3").Length | Should Be (Get-Item -Path "$srcDir\testFolder1\testfolder11\testFile3").Length
                }

            } finally {
                Remove-Item -LiteralPath "$srcDir\testFile1" -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath "$srcDir\testFolder1" -Force -Recurse -ErrorAction SilentlyContinue
            }
        } 

        Context "when copying one non-zip file to existing Destination and ClearDestination = false" {
            try {
                New-Item -Path "$srcDir\testFile1" -ItemType File -Force -Value 'test'
                New-Item -Path "$dstDir\testFileExisting" -ItemType File -Force -Value 'test'

                Copy-FilesFromRemoteServer -RemotePath "$srcDir\testFile1" -Destination $dstDir -ConnectionParams $connectionParams

                It "should copy the file" {
                    Test-Path -LiteralPath $dstDir -PathType Container | Should Be $true
                    Test-Path -LiteralPath "$dstDir\testFile1" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFile1").Length | Should Be (Get-Item -Path "$srcDir\testFile1").Length
                }

                It "should leave existing file" {
                    Test-Path -LiteralPath "$dstDir\testFileExisting" -PathType Leaf | Should Be $true
                }

            } finally {
                Remove-Item -LiteralPath "$srcDir\testFile1" -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $dstDir -Force -Recurse -ErrorAction SilentlyContinue
            }
        } 

        Context "when copying one non-zip file to existing Destination and ClearDestination = true" {
            try {
                New-Item -Path "$srcDir\testFile1" -ItemType File -Force -Value 'test'
                New-Item -Path "$dstDir\testFileExisting" -ItemType File -Force -Value 'test'

                Copy-FilesFromRemoteServer -RemotePath "$srcDir\testFile1" -Destination $dstDir -ConnectionParams $connectionParams -ClearDestination

                It "should copy the file" {
                    Test-Path -LiteralPath $dstDir -PathType Container | Should Be $true
                    Test-Path -LiteralPath "$dstDir\testFile1" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFile1").Length | Should Be (Get-Item -Path "$srcDir\testFile1").Length
                }

                It "should delete existing file" {
                    Test-Path -LiteralPath "$dstDir\testFileExisting" -PathType Leaf | Should Be $false
                }

            } finally {
                Remove-Item -LiteralPath "$srcDir\testFile1" -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $dstDir -Force -Recurse -ErrorAction SilentlyContinue
            }
        }  

    }
}
