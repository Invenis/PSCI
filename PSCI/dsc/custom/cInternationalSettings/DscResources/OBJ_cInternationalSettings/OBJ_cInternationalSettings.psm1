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

function Get-TargetResource {
    param
    (    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory=$false)] 
        [string] 
        $Culture,

        [parameter(Mandatory=$false)] 
        [string] 
        $HomeLocationGeoId,

        [parameter(Mandatory=$false)] 
        [string] 
        $SystemLocale
    )

    # Get-Culture does not work for different user when invoked with Invoke-Command -Credential... so need to run process explicitly
    $tempFileName = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'OBJ_cInternationalSettings.txt'
    Run-AsDifferentUser -Credential $Credential -ScriptBlock "'{0},{1},{2}' -f ((Get-Culture).Name, (Get-WinHomeLocation).GeoID, (Get-WinSystemLocale).Name) | Set-Content -Path '$tempFileName'"

    $cultureInfo = Get-Content -Path $tempFileName -ReadCount 0
    $cultureInfo = $cultureInfo -split ","

    Write-Verbose -Message ('Current culture: {0}, HomeLocationGeoId: {1}, SystemLocale: {2}' -f $cultureInfo[0], $cultureInfo[1], $cultureInfo[2])
    $result = @{ 
        Name = $Name
        Username = $Credential.UserName;
        Culture = $cultureInfo[0]
        HomeLocationGeoId = $cultureInfo[1]
        SystemLocale = $cultureInfo[2]
    }

    return $result
}

function Test-TargetResource {
    param(    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory=$false)] 
        [string] 
        $Culture,

        [parameter(Mandatory=$false)] 
        [string] 
        $HomeLocationGeoId,

        [parameter(Mandatory=$false)] 
        [string] 
        $SystemLocale
    )

    $currentSettings = Get-TargetResource -Name $Name -Credential $Credential -Culture $Culture -HomeLocationGeoId $HomeLocationGeoId -SystemLocale $SystemLocale
    if ($Culture -and $currentSettings.Culture -ne $Culture) {
        return $false
    }
    if ($HomeLocationGeoId -and $currentSettings.HomeLocationGeoId -ne $HomeLocationGeoId) {
        return $false
    }
    if ($SystemLocale -and $currentSettings.SystemLocale -ne $SystemLocale) {
        return $false
    }
    return $true
}


function Set-TargetResource {
    param(    
    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
    
        [parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory=$false)] 
        [string] 
        $Culture,

        [parameter(Mandatory=$false)] 
        [string] 
        $HomeLocationGeoId,

        [parameter(Mandatory=$false)] 
        [string] 
        $SystemLocale
    )
    $currentSettings = Get-TargetResource -Name $Name -Credential $Credential -Culture $Culture -HomeLocationGeoId $HomeLocationGeoId -SystemLocale $SystemLocale
    if ($Culture -and $currentSettings.Culture -ne $Culture) {
        Write-Verbose "'$($currentSettings.Culture)' != '$Culture' Setting culture to $Culture"
        Run-AsDifferentUser -Credential $Credential -ScriptBlock "Set-Culture -CultureInfo $Culture"
    }
    if ($HomeLocationGeoId -and $currentSettings.HomeLocationGeoId -ne $HomeLocationGeoId) {
        Write-Verbose "'$($currentSettings.HomeLocationGeoId)' != '$HomeLocationGeoId' Setting Home Location Geo Id to $HomeLocationGeoId"
        Run-AsDifferentUser -Credential $Credential -ScriptBlock "Set-WinHomeLocation -GeoId $HomeLocationGeoId"
    }
    if ($SystemLocale -and $currentSettings.SystemLocale -ne $SystemLocale) {
        Write-Verbose "Setting System Locale to $SystemLocale"
        Run-AsDifferentUser -Credential $Credential -ScriptBlock "Set-WinSystemLocale -SystemLocale $SystemLocale"
        $global:DSCMachineStatus = 1
    }
}


function Run-AsDifferentUser {
    param(
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [parameter(Mandatory=$false)] 
        [string]
        $ScriptBlock
    )
    $networkCred = $Credential.GetNetworkCredential()   
    $exitCode = 0
    $fileName = "$PSHOME\powershell.exe"
    $arguments = ('-NoProfile -NoLogo -NonInteractive -Command "{0}"' -f $ScriptBlock)
    CallPInvoke
    [Source.NativeMethods_cInternationalSettings]::CreateProcessAsUser("""" + $fileName + """ " + $arguments, `
                        $networkCred.Domain, $networkCred.UserName, $networkCred.Password, [ref] $exitCode)
    if ($exitCode) {
        throw "Failed to run scriptblock '$ScriptBlock'. Exit code: $exitCode"
    }
}

# Taken from xPSDesiredStateConfiguration / MSFT_xProcessResource
function CallPInvoke
{
$script:ProgramSource = @"
using System;
using System.Collections.Generic;
using System.Text;
using System.Security;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Security.Principal;
using System.ComponentModel;
using System.IO;

namespace Source
{
    [SuppressUnmanagedCodeSecurity]
    public static class NativeMethods_cInternationalSettings
    {
        //The following structs and enums are used by the various Win32 API's that are used in the code below
        
        [StructLayout(LayoutKind.Sequential)]
        public struct STARTUPINFO
        {
            public Int32 cb;
            public string lpReserved;
            public string lpDesktop;
            public string lpTitle;
            public Int32 dwX;
            public Int32 dwY;
            public Int32 dwXSize;
            public Int32 dwXCountChars;
            public Int32 dwYCountChars;
            public Int32 dwFillAttribute;
            public Int32 dwFlags;
            public Int16 wShowWindow;
            public Int16 cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public Int32 dwProcessID;
            public Int32 dwThreadID;
        }

        [Flags]
        public enum LogonType
        {
            LOGON32_LOGON_INTERACTIVE = 2,
            LOGON32_LOGON_NETWORK = 3,
            LOGON32_LOGON_BATCH = 4,
            LOGON32_LOGON_SERVICE = 5,
            LOGON32_LOGON_UNLOCK = 7,
            LOGON32_LOGON_NETWORK_CLEARTEXT = 8,
            LOGON32_LOGON_NEW_CREDENTIALS = 9
        }

        [Flags]
        public enum LogonProvider
        {
            LOGON32_PROVIDER_DEFAULT = 0,
            LOGON32_PROVIDER_WINNT35,
            LOGON32_PROVIDER_WINNT40,
            LOGON32_PROVIDER_WINNT50
        }
        [StructLayout(LayoutKind.Sequential)]
        public struct SECURITY_ATTRIBUTES
        {
            public Int32 Length;
            public IntPtr lpSecurityDescriptor;
            public bool bInheritHandle;
        }

        public enum SECURITY_IMPERSONATION_LEVEL
        {
            SecurityAnonymous,
            SecurityIdentification,
            SecurityImpersonation,
            SecurityDelegation
        }

        public enum TOKEN_TYPE
        {
            TokenPrimary = 1,
            TokenImpersonation
        }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        internal struct TokPriv1Luid
        {
            public int Count;
            public long Luid;
            public int Attr;
        }

        public const int GENERIC_ALL_ACCESS = 0x10000000;
        public const int CREATE_NO_WINDOW = 0x08000000;
        internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
        internal const int TOKEN_QUERY = 0x00000008;
        internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
        internal const string SE_INCRASE_QUOTA = "SeIncreaseQuotaPrivilege";

        [DllImport("kernel32.dll",
              EntryPoint = "CloseHandle", SetLastError = true,
              CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
        public static extern bool CloseHandle(IntPtr handle);

        [DllImport("advapi32.dll",
              EntryPoint = "CreateProcessAsUser", SetLastError = true,
              CharSet = CharSet.Ansi, CallingConvention = CallingConvention.StdCall)]
        public static extern bool CreateProcessAsUser(
            IntPtr hToken, 
            string lpApplicationName, 
            string lpCommandLine,
            ref SECURITY_ATTRIBUTES lpProcessAttributes, 
            ref SECURITY_ATTRIBUTES lpThreadAttributes,
            bool bInheritHandle, 
            Int32 dwCreationFlags, 
            IntPtr lpEnvrionment,
            string lpCurrentDirectory, 
            ref STARTUPINFO lpStartupInfo,
            ref PROCESS_INFORMATION lpProcessInformation
            );

        [DllImport("advapi32.dll", EntryPoint = "DuplicateTokenEx")]
        public static extern bool DuplicateTokenEx(
            IntPtr hExistingToken, 
            Int32 dwDesiredAccess,
            ref SECURITY_ATTRIBUTES lpThreadAttributes,
            Int32 ImpersonationLevel, 
            Int32 dwTokenType,
            ref IntPtr phNewToken
            );

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern Boolean LogonUser(
            String lpszUserName,
            String lpszDomain,
            String lpszPassword,
            LogonType dwLogonType,
            LogonProvider dwLogonProvider,
            out IntPtr phToken
            );

        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool AdjustTokenPrivileges(
            IntPtr htok, 
            bool disall,
            ref TokPriv1Luid newst, 
            int len, 
            IntPtr prev, 
            IntPtr relen
            );

        [DllImport("kernel32.dll", ExactSpelling = true)]
        internal static extern IntPtr GetCurrentProcess();

        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool OpenProcessToken(
            IntPtr h, 
            int acc, 
            ref IntPtr phtok
            );

        [DllImport("kernel32.dll", ExactSpelling = true)]
        internal static extern int WaitForSingleObject(
            IntPtr h, 
            int milliseconds
            );

        [DllImport("kernel32.dll", ExactSpelling = true)]
        internal static extern bool GetExitCodeProcess(
            IntPtr h, 
            out int exitcode
            );

        [DllImport("advapi32.dll", SetLastError = true)]
        internal static extern bool LookupPrivilegeValue(
            string host, 
            string name,
            ref long pluid
            );

        public static void CreateProcessAsUser(string strCommand, string strDomain, string strName, string strPassword, ref int ExitCode )
        {
            var hToken = IntPtr.Zero;
            var hDupedToken = IntPtr.Zero;
            TokPriv1Luid tp;
            var pi = new PROCESS_INFORMATION();
            var sa = new SECURITY_ATTRIBUTES();
            sa.Length = Marshal.SizeOf(sa);
            Boolean bResult = false;
            try
            {
                bResult = LogonUser(
                    strName,
                    strDomain,
                    strPassword,
                    LogonType.LOGON32_LOGON_BATCH,
                    LogonProvider.LOGON32_PROVIDER_DEFAULT,
                    out hToken
                    );
                if (!bResult) 
                { 
                    throw new Win32Exception("Logon error #" + Marshal.GetLastWin32Error().ToString()); 
                }
                IntPtr hproc = GetCurrentProcess();
                IntPtr htok = IntPtr.Zero;
                bResult = OpenProcessToken(
                        hproc, 
                        TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, 
                        ref htok
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Open process token error #" + Marshal.GetLastWin32Error().ToString());
                }
                tp.Count = 1;
                tp.Luid = 0;
                tp.Attr = SE_PRIVILEGE_ENABLED;
                bResult = LookupPrivilegeValue(
                    null, 
                    SE_INCRASE_QUOTA, 
                    ref tp.Luid
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Lookup privilege error #" + Marshal.GetLastWin32Error().ToString());
                }
                bResult = AdjustTokenPrivileges(
                    htok, 
                    false, 
                    ref tp, 
                    0, 
                    IntPtr.Zero, 
                    IntPtr.Zero
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Token elevation error #" + Marshal.GetLastWin32Error().ToString());
                }
                
                bResult = DuplicateTokenEx(
                    hToken,
                    GENERIC_ALL_ACCESS,
                    ref sa,
                    (int)SECURITY_IMPERSONATION_LEVEL.SecurityIdentification,
                    (int)TOKEN_TYPE.TokenPrimary,
                    ref hDupedToken
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Duplicate Token error #" + Marshal.GetLastWin32Error().ToString());
                }
                var si = new STARTUPINFO();
                si.cb = Marshal.SizeOf(si);
                si.lpDesktop = "";
                bResult = CreateProcessAsUser(
                    hDupedToken,
                    null,
                    strCommand,
                    ref sa, 
                    ref sa,
                    false, 
                    0, 
                    IntPtr.Zero,
                    null, 
                    ref si, 
                    ref pi
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Create process as user error #" + Marshal.GetLastWin32Error().ToString());
                }

                int status = WaitForSingleObject(pi.hProcess, -1);
                if(status == -1)
                {
                    throw new Win32Exception("Wait during create process failed user error #" + Marshal.GetLastWin32Error().ToString());
                }

                bResult = GetExitCodeProcess(pi.hProcess, out ExitCode);
                if(!bResult)
                {
                    throw new Win32Exception("Retrieving status error #" + Marshal.GetLastWin32Error().ToString());
                }
            }
            finally
            {
                if (pi.hThread != IntPtr.Zero)
                {
                    CloseHandle(pi.hThread);
                }
                if (pi.hProcess != IntPtr.Zero)
                {
                    CloseHandle(pi.hProcess);
                }
                 if (hDupedToken != IntPtr.Zero)
                {
                    CloseHandle(hDupedToken);
                }
            }
        }
    }
}

"@
            Add-Type -TypeDefinition $ProgramSource -ReferencedAssemblies "System.ServiceProcess"
}


Export-ModuleMember -Function *-TargetResource