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

Describe -Tag "PSCI.unit" "Compress-With7Zip" {

    InModuleScope PSCI {
        
        function New-TestDirStructure {
            Remove-Item -LiteralPath 'testDir' -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath 'testDirOut' -Force -Recurse -ErrorAction SilentlyContinue

            New-Item -Path 'testDir\testDir1\testDir11' -ItemType Directory -Force
            New-Item -Path 'testDir\testDir1\testDir2' -ItemType Directory -Force
            New-Item -Path 'testDir\testDir2' -ItemType Directory -Force
            New-Item -Path 'testDir\testDir3' -ItemType Directory -Force

            New-Item -Path 'testDir\testDir1\testDir11\testFile11' -ItemType File -Value 'testFile11' -Force
            New-Item -Path 'testDir\testDir1\testDir2\testFile12' -ItemType File -Value 'testFile12' -Force
            New-Item -Path 'testDir\testDir2\testFile2' -ItemType File -Value 'testFile2' -Force
            1..11 | % { New-Item -Path "testDir\testDir3\testFile$_" -ItemType File -Value 'testFile$_' -Force }
        }

        function Remove-TestDirStructure {
            Remove-Item -LiteralPath 'testDir' -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath 'testDirOut' -Force -Recurse -ErrorAction SilentlyContinue
        }

        Mock Start-ExternalProcess {
            Write-Host "Arguments passed to 7z: $ArgumentList"
        }

        Mock Get-PathTo7Zip {
            return "7z.exe"
        }

        Context "when compressing" {
            try {
                New-TestDirStructure
            
                It "should properly compress single file" {
                    Compress-With7Zip -PathsToCompress 'testFile' -OutputFile 'output.zip'

                    Assert-MockCalled Start-ExternalProcess -Exactly 1 -ParameterFilter {
                        $ArgumentList -eq 'a "output.zip" "testFile"'
                    }
                }

                It "should properly compress directory by paths and includes" {
                    Compress-With7Zip -PathsToCompress 'testDir' -Include @('testDir1', 'testDir2') -OutputFile 'output.zip'
                    Assert-MockCalled Start-ExternalProcess -Exactly 1 -ParameterFilter {
                        $ArgumentList -eq 'a "output.zip" "testDir" -i!testDir1 -i!testDir2'
                    }
                }

                It "should properly compress directory by paths only" {
                    Compress-With7Zip -PathsToCompress 'testDir' -OutputFile 'output.zip'
                    Assert-MockCalled Start-ExternalProcess -Exactly 1 -ParameterFilter {
                        $ArgumentList -eq 'a "output.zip" "testDir"'
                    }
                }

                It "should properly compress directory by includes only" {
                    Compress-With7Zip -Include @('testDir1', 'testDir2') -WorkingDirectory 'testDir' -OutputFile 'output.zip'
                    Assert-MockCalled Start-ExternalProcess -Exactly 1 -ParameterFilter {
                        $ArgumentList -eq 'a "output.zip"  -i!testDir1 -i!testDir2' `
                        -and $WorkingDirectory -eq (Join-Path -Path (Get-Location | Select-Object -ExpandProperty Path) -ChildPath 'testDir')
                    }
                }

                It "should properly compress single directory by paths" {
                    Compress-With7Zip -PathsToCompress '*' -WorkingDirectory 'testDir' -OutputFile 'output.zip'

                    Assert-MockCalled Start-ExternalProcess -Exactly 1 -ParameterFilter {
                        $ArgumentList -eq 'a "output.zip" "*"' `
                        -and $WorkingDirectory -eq (Join-Path -Path (Get-Location | Select-Object -ExpandProperty Path) -ChildPath 'testDir')
                    }
                }

                It "should properly compress multiple directories by paths" {
                    $manyDirectories = Get-ChildItem 'testDir\testDir3' -File

                    Mock New-Item { return @{FullName='filelist.txt'} }

                    Compress-With7Zip -PathsToCompress $manyDirectories -OutputFile 'output.zip'

                    Assert-MockCalled New-Item -Exactly 1 -ParameterFilter {
                        $Value -eq ($manyDirectories -join "`r`n")
                    }

                    Assert-MockCalled Start-ExternalProcess -Exactly 1 -ParameterFilter {
                        $ArgumentList -eq 'a "output.zip" -i@"filelist.txt"'
                    }
                }
            } finally {
                Remove-TestDirStructure
            }
        }
    }
}
