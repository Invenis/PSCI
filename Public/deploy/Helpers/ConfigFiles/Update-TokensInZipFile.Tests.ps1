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

Describe -Tag "PSCI.unit" "Update-TokensInZipFile" {
    InModuleScope PSCI {

        Mock Test-Path { return $true } -ParameterFilter { $LiteralPath -eq 'test.zip' }
        Mock Copy-Item { }
        Mock Open-ZipArchive { 
            $zipArchive =  @{ 'Entries' = 
                                    @( @{'Name' = 'test.notconfig'; 'FullName' = 'dir1/test.notconfig'}, 
                                        @{'Name' = 'x.config'; 'FullName' = 'dir1/x.config'}, 
                                        @{'Name' = 'x.config'; 'FullName' = 'dir2/x.config'}, 
                                        @{'Name' = 'x.DEV.config'; 'FullName' = 'dir2/x.DEV.config'}, 
                                        @{'Name' = 'x.TEST.config'; 'FullName' = 'dir2/x.TEST.config'},
                                        @{'Name' = 'y.DEV.config'; 'FullName' = 'dir1/y.DEV.config'}
                                    ) }
            $zipArchive | Add-Member -MemberType ScriptMethod -Name 'Dispose' -Value { }
            $zipArchive.Entries | Add-Member -MemberType ScriptMethod -Name 'Open' -Value { New-Object -TypeName System.IO.MemoryStream }
            $zipArchive.Entries | Add-Member -MemberType ScriptMethod -Name 'Delete' -Value { $global:deletedFiles += $_.Name }
            
            return $zipArchive
        }                                    
        Mock Update-TokensInStream { }
        Mock Convert-XmlUsingXdtInArchive { }
        Mock New-TempDirectory { return "c:\Temp" }
    
        Context "when invoked for non-existing .zip file" {
            Mock Test-Path { return $false } -ParameterFilter { $LiteralPath -eq 'test.zip' }

            It "should throw exception" {
                try { 
                    Update-TokensInZipFile -ZipFile 'test.zip' -OutputFile 'test_out.zip' -Tokens @{}
                    $true | Should Be $false
                } catch {
                    $_ | Should Be "Cannot access file 'test.zip'"
                }
            }
        }

        Context "when invoked with no Environment for .zip with 5 .config files inside" {
            
            $global:deletedFiles = @()
            Update-TokensInZipFile -ZipFile 'test.zip' -OutputFile 'test_out.zip' -Tokens @{ }

            It "Update-TokensInStream should be invoked 5 times" {
                Assert-MockCalled Update-TokensInStream -Exactly 5
            }

            It "It should not run Convert-XmlUsingXdtInArchive" {
                Assert-MockCalled Convert-XmlUsingXdtInArchive -Exactly 0
            }

             It "It should delete 2 files from archive" {
                # x.DEV.config, x.TEST.config
                $global:deletedFiles.Count | Should Be 2
            }
        }

        Context "when invoked with no Environment and -PreserveTransformFiles for .zip with 5 .config files inside" {
            
            $global:deletedFiles = @()
            Update-TokensInZipFile -ZipFile 'test.zip' -OutputFile 'test_out.zip' -Tokens @{ } -PreserveTransformFiles

            It "Update-TokensInStream should be invoked 5 times" {
                Assert-MockCalled Update-TokensInStream -Exactly 5
            }

            It "It should not run Convert-XmlUsingXdtInArchive" {
                Assert-MockCalled Convert-XmlUsingXdtInArchive -Exactly 0
            }

            It "It should not delete any files from archive" {
                $global:deletedFiles.Count | Should Be 0
            }
        }

        Context "when invoked for .zip with 5 .config files inside and Environment = Dev" {
            
            $global:deletedFiles = @()
            Update-TokensInZipFile -ZipFile 'test.zip' -OutputFile 'test_out.zip' -Tokens @{ } -Environment Dev

            It "Update-TokensInStream should be invoked 5 times" {
                Assert-MockCalled Update-TokensInStream -Exactly 5
            }

            It "It should run Convert-XmlUsingXdtInArchive once" {
                Assert-MockCalled Convert-XmlUsingXdtInArchive -Exactly 1 
            }

            It "It should run Convert-XmlUsingXdtInArchive with proper parameters" {
                Assert-MockCalled Convert-XmlUsingXdtInArchive -Exactly 1 -ParameterFilter { 
                    $EntryToTransform.FullName -eq 'dir2/x.config' -and $EntryXdt.FullName -eq 'dir2/x.DEV.config' 
                }
            }

            It "It should delete 2 files from archive" {
                # x.DEV.config, x.TEST.config
                $global:deletedFiles.Count | Should Be 2
            }
        }

  }
}
