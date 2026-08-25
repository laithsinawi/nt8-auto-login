<#
.SYNOPSIS
    Launches NinjaTrader 8 and automatically fills in the password on the
    NinjaTrader account sign-in dialog (the "NINJATRADER / Username /
    Password / Log In" popup), using the credential saved earlier by
    Setup-NT8Credential.ps1.

.DESCRIPTION
    - Retrieves the saved password from Windows Credential Manager (never
      stored in plaintext on disk or in this script).
    - Starts NinjaTrader.exe if it isn't already running.
    - Polls for the sign-in window (identified by a password-masked Edit
      control + a "Log In" button, not by window title, so it keeps working
      across NT8 versions/skins).
    - Focuses the password field, types the password, and submits the form.

.PARAMETER NinjaTraderExePath
    Full path to NinjaTrader.exe. Defaults to the standard 64-bit install
    location; override if yours is installed elsewhere.

.PARAMETER TimeoutSeconds
    How long to wait for the sign-in dialog to appear before giving up.

.EXAMPLE
    .\Launch-NT8-AutoLogin.ps1
#>

param(
    [string]$NinjaTraderExePath = "$env:ProgramFiles\NinjaTrader 8\bin\NinjaTrader.exe",
    [int]$TimeoutSeconds = 60
)

. (Join-Path $PSScriptRoot 'CredentialStore.ps1')

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms

if (-not ("Win32.ForegroundWindow" -as [type])) {
    Add-Type -Namespace Win32 -Name ForegroundWindow -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
}

$Target = 'NT8AutoLogin'
$credential = Get-GenericCredential -Target $Target
if (-not $credential) {
    Write-Error "No saved credential found under '$Target'. Run Setup-NT8Credential.ps1 first."
    exit 1
}

function ConvertFrom-SecureStringPlain([securestring]$Secure) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Send-EscapedKeys([string]$Text) {
    $special = '+^%~(){}[]'
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $Text.ToCharArray()) {
        if ($special.IndexOf($c) -ge 0) {
            switch ($c) {
                '{' { [void]$sb.Append('{{}') }
                '}' { [void]$sb.Append('{}}') }
                default { [void]$sb.Append('{').Append($c).Append('}') }
            }
        } else {
            [void]$sb.Append($c)
        }
    }
    [System.Windows.Forms.SendKeys]::SendWait($sb.ToString())
}

function Find-SignInDialog {
    $root = [Windows.Automation.AutomationElement]::RootElement
    $windowCondition = [Windows.Automation.PropertyCondition]::new(
        [Windows.Automation.AutomationElement]::ControlTypeProperty,
        [Windows.Automation.ControlType]::Window)
    $windows = $root.FindAll([Windows.Automation.TreeScope]::Children, $windowCondition)

    foreach ($win in $windows) {
        try {
            $passwordCondition = [Windows.Automation.PropertyCondition]::new(
                [Windows.Automation.AutomationElement]::IsPasswordProperty, $true)
            $passwordField = $win.FindFirst([Windows.Automation.TreeScope]::Descendants, $passwordCondition)

            $buttonCondition = [Windows.Automation.AndCondition]::new(
                [Windows.Automation.PropertyCondition]::new(
                    [Windows.Automation.AutomationElement]::ControlTypeProperty,
                    [Windows.Automation.ControlType]::Button),
                [Windows.Automation.PropertyCondition]::new(
                    [Windows.Automation.AutomationElement]::NameProperty, 'Log In'))
            $loginButton = $win.FindFirst([Windows.Automation.TreeScope]::Descendants, $buttonCondition)

            if ($passwordField -and $loginButton) {
                return [PSCustomObject]@{
                    Window        = $win
                    PasswordField = $passwordField
                    LoginButton   = $loginButton
                }
            }
        } catch { }
    }
    return $null
}

# Start NT8 if it isn't already running.
$processName = [IO.Path]::GetFileNameWithoutExtension($NinjaTraderExePath)
$proc = Get-Process -Name $processName -ErrorAction SilentlyContinue
if (-not $proc) {
    if (-not (Test-Path $NinjaTraderExePath)) {
        Write-Error "NinjaTrader.exe not found at '$NinjaTraderExePath'. Pass -NinjaTraderExePath with the correct location."
        exit 1
    }
    Start-Process -FilePath $NinjaTraderExePath | Out-Null
}

Write-Host "Waiting for the NinjaTrader sign-in dialog (timeout ${TimeoutSeconds}s)..."
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$dialog = $null
while ((Get-Date) -lt $deadline) {
    $dialog = Find-SignInDialog
    if ($dialog) { break }
    Start-Sleep -Milliseconds 750
}

if (-not $dialog) {
    Write-Warning "Sign-in dialog not found within ${TimeoutSeconds}s. Nothing was typed."
    exit 1
}

try {
    $hwnd = [IntPtr]$dialog.Window.Current.NativeWindowHandle
    if ($hwnd -ne [IntPtr]::Zero) {
        [Win32.ForegroundWindow]::ShowWindow($hwnd, 9) | Out-Null   # SW_RESTORE
        [Win32.ForegroundWindow]::SetForegroundWindow($hwnd) | Out-Null
    }

    $dialog.PasswordField.SetFocus()
    Start-Sleep -Milliseconds 200

    $plainPassword = ConvertFrom-SecureStringPlain $credential.Password
    try {
        Send-EscapedKeys $plainPassword
    }
    finally {
        $plainPassword = $null
    }

    Start-Sleep -Milliseconds 200

    $invokePattern = $dialog.LoginButton.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern)
    $invokePattern.Invoke()

    Write-Host "Submitted NinjaTrader sign-in." -ForegroundColor Green
}
finally {
    $credential.Password.Dispose()
}
