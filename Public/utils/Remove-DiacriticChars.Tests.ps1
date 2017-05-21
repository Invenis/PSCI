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

. "$PSScriptRoot\Remove-DiacriticChars.ps1" -Force

Describe "Remove-DiacriticChars" {

    Context "when invoked for alphanumeric characters" {
        $str = (0..127 | Foreach-Object { [char] $_ }) -join ''
        $result = Remove-DiacriticChars -String $str

        It "should not change any character" {
            $result | Should Be $str
        }
    }

    Context "when invoked for polish characters" {
        $str = 'ąćęłńóśżźĄĆĘŁŃÓŚŻŹ'
        $result = Remove-DiacriticChars -String $str

        It "should change characters to non-polish ones" {
            $result | Should Be 'acelnoszzACELNOSZZ'
        }
    }

}