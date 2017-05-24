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

Describe -Tag "PSCI.unit" "Copy-FilesToRemoteServer" {

    InModuleScope PSCI {

        $Global:loggedMessage = @('')
        if ($Env:PSCIWinRmUser) {
            $cred = ConvertTo-PSCredential -User $Env:PSCIWinRmUser -Password $Env:PSCIWinRmPassword
            $connectionParams = New-ConnectionParameters -Nodes 'localhost' -Credential $cred
        }
        else {
            $connectionParams = New-ConnectionParameters -Nodes 'localhost'
        }

        $dstDir = 'c:\PSCITestDir'
        $dstDirGreen = 'c:\PSCITestDir2'
        Remove-Item -LiteralPath $dstDir -Force -Recurse -ErrorAction SilentlyContinue

        function New-TestDirStructure {
            New-Item -Path 'testFolder1\testFolder11' -ItemType Directory -Force 
            New-Item -Path 'testFolder1\testFile2' -ItemType File -Force -Value 'test2'
            New-Item -Path 'testFolder1\testFolder11\testFile3' -ItemType File -Force -Value 'test33'
            New-Item -Path 'testFolder2' -ItemType Directory -Force
            New-Item -Path 'testFolder2\testFile4' -ItemType File -Force -Value 'test444'
        }

        function Remove-TestDirStructure {
             Remove-Item -LiteralPath 'testFolder1' -Force -Recurse -ErrorAction SilentlyContinue
             Remove-Item -LiteralPath 'testFolder2' -Force -Recurse -ErrorAction SilentlyContinue
             Remove-Item -LiteralPath $dstDir -Force -Recurse -ErrorAction SilentlyContinue
             Remove-Item -LiteralPath $dstDirGreen -Force -Recurse -ErrorAction SilentlyContinue
        }

        function Validate-TestDirStructure($dst) {
            Test-Path -LiteralPath $dst -PathType Container | Should Be $true
            Test-Path -LiteralPath "$dst\test1\testFile2" -PathType Leaf | Should Be $true
            (Get-Item -Path "$dst\test1\testFile2").Length | Should Be (Get-Item -Path 'testFolder1\testFile2').Length
            Test-Path -LiteralPath "$dst\test1\testFolder11\testFile3" -PathType Leaf | Should Be $true
            (Get-Item -Path "$dst\test1\testFolder11\testFile3").Length | Should Be (Get-Item -Path 'testFolder1\testfolder11\testFile3').Length
            Test-Path -LiteralPath "$dst\test2\testFile4" -PathType Leaf | Should Be $true
            (Get-Item -Path "$dst\test2\testFile4").Length | Should Be (Get-Item -Path 'testFolder2\testFile4').Length
        }

        function Validate-TestDirStructureFlat($dst) {
            Test-Path -LiteralPath $dst -PathType Container | Should Be $true
            Test-Path -LiteralPath "$dst\testFile2" -PathType Leaf | Should Be $true
            (Get-Item -Path "$dst\testFile2").Length | Should Be (Get-Item -Path 'testFolder1\testFile2').Length
            Test-Path -LiteralPath "$dst\testFolder11\testFile3" -PathType Leaf | Should Be $true
            (Get-Item -Path "$dst\testFolder11\testFile3").Length | Should Be (Get-Item -Path 'testFolder1\testfolder11\testFile3').Length
            Test-Path -LiteralPath "$dst\testFile4" -PathType Leaf | Should Be $true
            (Get-Item -Path "$dst\testFile4").Length | Should Be (Get-Item -Path 'testFolder2\testFile4').Length
        }
        
        Context "when copying only one .zip file" {
            try {
                New-Item -Path 'testFile1' -ItemType File -Force -Value 'test'
                New-Zip -Path 'testFile1' -OutputFile "$dst\test.zip"
                Mock New-Zip { }

                Copy-FilesToRemoteServer -Path "$dst\test.zip" -Destination $dstDir -ConnectionParams $connectionParams
            
                It "should copy the file" {
                    Test-Path -LiteralPath $dstDir -PathType Container | Should Be $true
                    Test-Path -LiteralPath "$dstDir\testFile1" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFile1").Length | Should Be (Get-Item -Path 'testFile1').Length
                }

                It "should not create new zip" {
                    Assert-MockCalled New-Zip -Times 0
                }

            } finally {
                Remove-Item -LiteralPath 'testfile1' -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath 'test.zip' -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $dstDir -Force -Recurse -ErrorAction SilentlyContinue
            }
        }

        Context "when copying one non-zip file" {
            try {
                New-Item -Path 'testFile1' -ItemType File -Force -Value 'test'

                Copy-FilesToRemoteServer -Path 'testFile1' -Destination $dstDir -ConnectionParams $connectionParams

                It "should copy the file" {
                    Test-Path -LiteralPath $dstDir -PathType Container | Should Be $true
                    Test-Path -LiteralPath "$dstDir\testFile1" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFile1").Length | Should Be (Get-Item -Path 'testFile1').Length
                }

            } finally {
                Remove-Item -LiteralPath 'testFile1' -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $dstDir -Force -Recurse -ErrorAction SilentlyContinue
            }
        } 

        
        Context "when copying one directory" {
            try {
                New-Item -Path 'testFolder1\testFolder11' -ItemType Directory -Force 
                New-Item -Path 'testFolder1\testFile2' -ItemType File -Force -Value 'test2'
                New-Item -Path 'testFolder1\testFolder11\testFile3' -ItemType File -Force -Value 'test33'

                Copy-FilesToRemoteServer -Path 'testFolder1' -Destination $dstDir -ConnectionParams $connectionParams

                It "should copy the files with structure intact" {
                    Test-Path -LiteralPath $dstDir -PathType Container | Should Be $true
                    Test-Path -LiteralPath "$dstDir\testFile2" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFile2").Length | Should Be (Get-Item -Path 'testFolder1\testFile2').Length
                    Test-Path -LiteralPath "$dstDir\testFolder11\testFile3" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFolder11\testFile3").Length | Should Be (Get-Item -Path 'testFolder1\testfolder11\testFile3').Length
                }

            } finally {
                Remove-Item -LiteralPath 'testFolder1' -Force -Recurse -ErrorAction SilentlyContinue
            }
        } 

        Context "when copying several directories and files to one Destination" {
            try {
                New-Item -Path 'testFile1' -ItemType File -Force -Value 'test'
                New-Item -Path 'testFolder1\testFolder11' -ItemType Directory -Force 
                New-Item -Path 'testFolder1\testFile2' -ItemType File -Force -Value 'test2'
                New-Item -Path 'testFolder1\testFolder11\testFile3' -ItemType File -Force -Value 'test33'

                Copy-FilesToRemoteServer -Path 'testFile1', 'testFolder1' -Destination $dstDir -ConnectionParams $connectionParams

                It "should copy the files with structure intact" {
                    Test-Path -LiteralPath $dstDir -PathType Container | Should Be $true
                    Test-Path -LiteralPath "$dstDir\testFile1" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFile1").Length | Should Be (Get-Item -Path 'testFile1').Length
                    Test-Path -LiteralPath "$dstDir\testFile2" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFile2").Length | Should Be (Get-Item -Path 'testFolder1\testFile2').Length
                    Test-Path -LiteralPath "$dstDir\testFolder11\testFile3" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFolder11\testFile3").Length | Should Be (Get-Item -Path 'testFolder1\testfolder11\testFile3').Length
                }

            } finally {
                Remove-Item -LiteralPath 'testFile1' -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath 'testFolder1' -Force -Recurse -ErrorAction SilentlyContinue
            }
        } 
         
        Context "when copying several directories to several Destinations" {
            try {
                New-TestDirStructure

                Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination "$dstDir\test1", "$dstDir\test2" -ConnectionParams $connectionParams

                It "should copy the files with structure intact" {
                    Validate-TestDirStructure $dstDir
                }               

            } finally {
                Remove-TestDirStructure
            }
        } 

        Context "when copying several directories to several Destinations without ClearDestination flag when destination exist" {
            try {
                New-TestDirStructure
                
                New-Item -Path "$dstDir\test1\newFolder" -ItemType Directory -Force
                New-Item -Path "$dstDir\test1\newFolder\testFileAdditional" -ItemType File -Value 'additional'
                New-Item -Path "$dstDir\test1\testFileAdditional" -ItemType File -Value 'additional'
                New-Item -Path "$dstDir\testFileAdditional" -ItemType File -Value 'additional'

                $len = (Get-Item -Path "$dstDir\testFileAdditional").Length

                Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination "$dstDir\test1", "$dstDir\test2" -ConnectionParams $connectionParams -ClearDestination:$false

                It "should copy the files with structure intact" {
                    Validate-TestDirStructure $dstDir
                }  

                It "should not touch additional files" {
                    Test-Path -LiteralPath "$dstDir\test1\testFileAdditional" -PathType Leaf | Should Be $true
                    Test-Path -LiteralPath "$dstDir\test1\newFolder\testFileAdditional" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\test1\newFolder\testFileAdditional").Length | Should Be $len
                    Test-Path -LiteralPath "$dstDir\test1\testFileAdditional" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\test1\testFileAdditional").Length | Should Be $len
                    Test-Path -LiteralPath "$dstDir\testFileAdditional" -PathType Leaf | Should Be $true
                    (Get-Item -Path "$dstDir\testFileAdditional").Length | Should Be $len
                }
            } finally {
                Remove-TestDirStructure
            }
        }

        Context "when copying several directories to several Destinations with ClearDestination flag when destination exist" {
            try {
                New-TestDirStructure
                New-Item -Path "$dstDir\test1\newFolder" -ItemType Directory -Force
                New-Item -Path "$dstDir\test1\newFolder\testFileAdditional" -ItemType File -Value 'additional'
                New-Item -Path "$dstDir\test1\testFileAdditional" -ItemType File -Value 'additional'
                New-Item -Path "$dstDir\testFileAdditional" -ItemType File -Value 'additional'

                $len = (Get-Item -Path "$dstDir\testFileAdditional").Length

                Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination "$dstDir\test1", "$dstDir\test2" -ConnectionParams $connectionParams -ClearDestination

                It "should copy the files with structure intact" {
                    Validate-TestDirStructure $dstDir
                }

                It "should delete additional files in Destination" {       
                    Test-Path -LiteralPath "$dstDir\test1\testFileAdditional" | Should Be $false
                    Test-Path -LiteralPath "$dstDir\test1\newFolder" | Should Be $false
                }

                It "should not touch additional files outside Destination" {       
                    Test-Path -LiteralPath "$dstDir\testFileAdditional" | Should Be $true
                }

            } finally {
                Remove-TestDirStructure
            }
        }

        Context "when copying several directories to one Destination with ClearDestination flag when destination exists" {
            try {
                New-TestDirStructure

                New-Item -Path "$dstDir\test1\newFolder" -ItemType Directory -Force
                New-Item -Path "$dstDir\test1\testFileAdditional" -ItemType File -Value 'additional'
                New-Item -Path "$dstDir\testFileAdditional" -ItemType File -Value 'additional'

                $len = (Get-Item -Path "$dstDir\testFileAdditional").Length

                Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination $dstDir -ConnectionParams $connectionParams -ClearDestination

                It "should copy the files with structure intact" {
                    Validate-TestDirStructureFlat $dstDir
                }

                It "should delete additional files in Destination" {       
                    Test-Path -LiteralPath "$dstDir\test1\newFolder\testFileAdditional" | Should Be $false
                    Test-Path -LiteralPath "$dstDir\test1\testFileAdditional" | Should Be $false
                    Test-Path -LiteralPath "$dstDir\testFileAdditional"| Should Be $false
                }
            } finally {
                Remove-TestDirStructure
            }
        }


        Context "when copying several directories to several Destinations with CheckHashMode = AlwaysCalculateHash" {
            try {
                New-TestDirStructure

                Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination "$dstDir\test1", "$dstDir\test2" -ConnectionParams $connectionParams -CheckHashMode AlwaysCalculateHash

                It "should copy the files with structure intact" {
                    Validate-TestDirStructure $dstDir
                }

                It "copying it again with CheckHashMode = AlwaysCalculateHash should do nothing" {
                    Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination "$dstDir\test1", "$dstDir\test2" -ConnectionParams $connectionParams -CheckHashMode AlwaysCalculateHash
                }

                It "copying it again when one file changed at destination should update the files" {
                    Set-Content -Path "$dstDir\test1\testFile2" -Value 'a' -Force
                    Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination "$dstDir\test1", "$dstDir\test2" -ConnectionParams $connectionParams -CheckHashMode AlwaysCalculateHash
                    Validate-TestDirStructure $dstDir
                }

                It "copying it again when one file changed at source should update the files" {
                    Set-Content -Path "testfolder1\testFile2" -Value 'aa' -Force
                    Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination "$dstDir\test1", "$dstDir\test2" -ConnectionParams $connectionParams -CheckHashMode AlwaysCalculateHash
                    Validate-TestDirStructure $dstDir
                }

            } finally {
                Remove-TestDirStructure
            }
       } 

       Context "when copying several directories to several Destinations with CheckHashMode = UseHashFile" {
            try {
                New-TestDirStructure
                Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination "$dstDir\test1", "$dstDir\test2" -ConnectionParams $connectionParams -CheckHashMode UseHashFile
                

                It "should copy the files with structure intact" {
                    Validate-TestDirStructure $dstDir
                }

                It "should create syncHash file in first directory" {
                    Test-Path -LiteralPath "$dstDir\test1\syncHash_999606178B015C8FB734CF07D268AA300861CB34" | Should Be $true
                    (Get-ChildItem -Path "$dstDir\test1" -Filter "syncHash*").Count | Should Be 1

                }

                It "copying it again with CheckHashMode = UseHashFile should do nothing" {$Global:loggedMessage = @()
                    Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination "$dstDir\test1", "$dstDir\test2" -ConnectionParams $connectionParams -CheckHashMode UseHashFile
                }

                It "copying it again when one file changed at source should update the files and syncHash" {
                    Set-Content -Path "testfolder1\testFile2" -Value 'aa' -Force
                    Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination "$dstDir\test1", "$dstDir\test2" -ConnectionParams $connectionParams -CheckHashMode UseHashFile
                    Validate-TestDirStructure $dstDir
                    Test-Path -LiteralPath "$dstDir\test1\syncHash_28B142D577A040D52F5D1BA8C42CA5517F75382E" | Should Be $true
                    (Get-ChildItem -Path "$dstDir\test1" -Filter "syncHash*").Count | Should Be 1
                }

            } finally {
                Remove-TestDirStructure
            }
       } 

       Context "when supply 1 Path and 2 Destinations" {
          try {
            New-TestDirStructure

            $fail = $false
            Copy-FilesToRemoteServer -Path 'testFolder1' -Destination $dstDir,$dstDir -ConnectionParams $connectionParams

          } catch {
            $fail = $true 
          } finally {
            Remove-TestDirStructure
          }

          It "should throw exception" {
            $fail | Should Be $true
          }
       }

       Context "when supply 2 Paths and 3 Destinations" {
          try {
            New-TestDirStructure

            $fail = $false
            Copy-FilesToRemoteServer -Path 'testFolder1','testfolder2' -Destination $dstDir,$dstDir,$dstDir -ConnectionParams $connectionParams

          } catch {
            $fail = $true 
          } finally {
            Remove-TestDirStructure
          }

          It "should throw exception" {
            $fail | Should Be $true
          }
       } 

       Context "when supply BlueGreenEnvVariableName and one Destination" {
          try {
            New-TestDirStructure

            $fail = $false
            Copy-FilesToRemoteServer -Path 'testFolder1' -Destination $dstDir -ConnectionParams $connectionParams -BlueGreenEnvVariableName 'PSCITest'

          } catch {
            $fail = $true 
          } finally {
            Remove-TestDirStructure
          }

          It "should throw exception" {
            $fail | Should Be $true
          }
       }

       Context "when supply BlueGreenEnvVariableName and two the same Destinations" {
          try {
            New-TestDirStructure

            $fail = $false
            Copy-FilesToRemoteServer -Path 'testFolder1' -Destination $dstDir,$dstDir -ConnectionParams $connectionParams -BlueGreenEnvVariableName 'PSCITest'

          } catch {
            $fail = $true 
          } finally {
            Remove-TestDirStructure
          }

          It "should throw exception" {
            $fail | Should Be $true
          }
       } 
       
       Context "when supply BlueGreenEnvVariableName and env variable doesn't exist" {
            try {
                New-TestDirStructure
                [Environment]::SetEnvironmentVariable('PSCITest', '', 'Machine')
                Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination $dstDir, $dstDirGreen -ConnectionParams $connectionParams -BlueGreenEnvVariableName 'PSCITest'

                It "should copy the files with structure intact to first directory" {
                    Validate-TestDirStructureFlat $dstDir
                }             

                It "second directory should not exist" {
                    Test-Path -LiteralPath $dstDirGreen | Should Be $false
                }  
                
                It "should set environment variable to first direcory" {
                    [Environment]::GetEnvironmentVariable('PSCITest', 'Machine') | Should Be $dstDir
                }  

                It "should create .currentLive file in first directory" {
                    Test-Path -LiteralPath "$dstDir\.currentLive" -PathType Leaf | Should be $true
                }

            } finally {
                Remove-TestDirStructure
                [Environment]::SetEnvironmentVariable('PSCITest', '', 'Machine')
            }
        } 

        Context "when supply BlueGreenEnvVariableName and env variable exists" {
            try {
                New-TestDirStructure
                [Environment]::SetEnvironmentVariable('PSCITest', $dstDir, 'Machine')
                Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination $dstDir, $dstDirGreen -ConnectionParams $connectionParams -BlueGreenEnvVariableName 'PSCITest'

                It "should copy the files with structure intact to second directory" {
                    Validate-TestDirStructureFlat $dstDirGreen
                }             

                It "first directory should not exist" {
                    Test-Path -LiteralPath $dstDir | Should Be $false
                }             
                
                It "should set environment variable to second direcory" {
                    [Environment]::GetEnvironmentVariable('PSCITest', 'Machine') | Should Be $dstDirGreen
                }  

                It "should create .currentLive file in second directory" {
                    Test-Path -LiteralPath "$dstDirGreen\.currentLive" -PathType Leaf | Should be $true
                }

            } finally {
                Remove-TestDirStructure
                [Environment]::SetEnvironmentVariable('PSCITest', '', 'Machine')
            }
        }

        Context "when supply BlueGreenEnvVariableName and env variable exists and first directory exists" {
            try {
                New-TestDirStructure
                [Environment]::SetEnvironmentVariable('PSCITest', '', 'Machine')
                Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination $dstDir, $dstDirGreen -ConnectionParams $connectionParams -BlueGreenEnvVariableName 'PSCITest'
                Copy-FilesToRemoteServer -Path 'testFolder1', 'testFolder2' -Destination $dstDir, $dstDirGreen -ConnectionParams $connectionParams -BlueGreenEnvVariableName 'PSCITest'

                It "should copy the files with structure intact to second directory" {
                    Validate-TestDirStructureFlat $dstDirGreen
                }             

                It "first directory should exist but not have .currentLive file" {
                    Test-Path -LiteralPath "$dstDir\.currentLive" | Should Be $false
                }             
                
                It "should set environment variable to second direcory" {
                    [Environment]::GetEnvironmentVariable('PSCITest', 'Machine') | Should Be $dstDirGreen
                }  

                It "should create .currentLive file in second directory" {
                    Test-Path -LiteralPath "$dstDirGreen\.currentLive" -PathType Leaf | Should be $true
                }

            } finally {
                Remove-TestDirStructure
                [Environment]::SetEnvironmentVariable('PSCITest', '', 'Machine')
            }
        }
    }
}
