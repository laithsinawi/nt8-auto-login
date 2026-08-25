# Thin wrapper around the Windows Credential Manager (DPAPI-backed) API.
# Passwords never touch disk in plaintext and never appear as a process
# command-line argument (unlike cmdkey.exe) - they only ever live as a
# SecureString in memory during Save/Get.

if (-not ("WinCred.CredentialManager" -as [type])) {
    Add-Type -Namespace WinCred -Name CredentialManager -MemberDefinition @'
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct CREDENTIAL
{
    public uint Flags;
    public uint Type;
    public string TargetName;
    public string Comment;
    public long LastWritten;
    public uint CredentialBlobSize;
    public IntPtr CredentialBlob;
    public uint Persist;
    public uint AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
}

[DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool CredWrite(ref CREDENTIAL credential, uint flags);

[DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool CredRead(string target, uint type, uint flags, out IntPtr credentialPtr);

[DllImport("advapi32.dll", SetLastError = true)]
public static extern bool CredFree(IntPtr credentialPtr);

[DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool CredDelete(string target, uint type, uint flags);
'@
}

$CRED_TYPE_GENERIC = 1
$CRED_PERSIST_LOCAL_MACHINE = 2

function Save-GenericCredential {
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$UserName,
        [Parameter(Mandatory)][securestring]$Password
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    try {
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $blob = [Text.Encoding]::Unicode.GetBytes($plain)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }

    $blobPtr = [Runtime.InteropServices.Marshal]::AllocHGlobal($blob.Length)
    try {
        [Runtime.InteropServices.Marshal]::Copy($blob, 0, $blobPtr, $blob.Length)
        [Array]::Clear($blob, 0, $blob.Length)

        $cred = New-Object WinCred.CredentialManager+CREDENTIAL
        $cred.Type = $CRED_TYPE_GENERIC
        $cred.TargetName = $Target
        $cred.UserName = $UserName
        $cred.CredentialBlobSize = [uint32][Text.Encoding]::Unicode.GetByteCount($plain)
        $cred.CredentialBlob = $blobPtr
        $cred.Persist = $CRED_PERSIST_LOCAL_MACHINE

        if (-not [WinCred.CredentialManager]::CredWrite([ref]$cred, 0)) {
            throw "CredWrite failed with error $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }
    }
    finally {
        # Best-effort zero of the unmanaged blob before freeing it.
        $zero = New-Object byte[] ($blob.Length)
        [Runtime.InteropServices.Marshal]::Copy($zero, 0, $blobPtr, $zero.Length)
        [Runtime.InteropServices.Marshal]::FreeHGlobal($blobPtr)
    }
}

function Get-GenericCredential {
    param([Parameter(Mandatory)][string]$Target)

    $ptr = [IntPtr]::Zero
    if (-not [WinCred.CredentialManager]::CredRead($Target, $CRED_TYPE_GENERIC, 0, [ref]$ptr)) {
        return $null
    }

    try {
        $cred = [Runtime.InteropServices.Marshal]::PtrToStructure($ptr, [type][WinCred.CredentialManager+CREDENTIAL])
        $bytes = New-Object byte[] $cred.CredentialBlobSize
        [Runtime.InteropServices.Marshal]::Copy($cred.CredentialBlob, $bytes, 0, $cred.CredentialBlobSize)
        $plain = [Text.Encoding]::Unicode.GetString($bytes)
        [Array]::Clear($bytes, 0, $bytes.Length)

        $secure = New-Object securestring
        foreach ($ch in $plain.ToCharArray()) { $secure.AppendChar($ch) }
        $secure.MakeReadOnly()

        [PSCustomObject]@{
            UserName = $cred.UserName
            Password = $secure
        }
    }
    finally {
        [WinCred.CredentialManager]::CredFree($ptr) | Out-Null
    }
}

function Remove-GenericCredential {
    param([Parameter(Mandatory)][string]$Target)
    [WinCred.CredentialManager]::CredDelete($Target, $CRED_TYPE_GENERIC, 0) | Out-Null
}
