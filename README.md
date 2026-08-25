# NT8 Auto-Login

Fills in the password on the NinjaTrader account sign-in dialog automatically,
so you only type it once (during setup) instead of on every restart.

Runs on Windows only (this is where NT8 itself runs). Copy this `AutoLogin`
folder to your Windows machine before using it.

## How it works

- Your password is stored **once**, encrypted, in **Windows Credential
  Manager** (the same OS vault Windows/Edge/Office use) — never in a plaintext
  file, never hardcoded in a script.
- `Launch-NT8-AutoLogin.ps1` starts NinjaTrader, waits for the sign-in dialog
  (detected by its password field + "Log In" button, not by window title, so
  it survives NT8 updates), types the password into it, and clicks **Log In**.
  Your username field already autofills on its own, so this script leaves it
  alone.

## Setup (one time)

1. Copy the `AutoLogin` folder to your Windows PC.
2. Open PowerShell and run:
   ```powershell
   cd path\to\AutoLogin
   .\Setup-NT8Credential.ps1
   ```
   Enter your NinjaTrader username and password when prompted. This is the
   only time you'll type the password.
3. If PowerShell blocks the scripts ("running scripts is disabled"), run
   PowerShell as your normal user (not admin needed) and either:
   - `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`, or
   - always launch scripts with `powershell -ExecutionPolicy Bypass -File ...`
     (used in the shortcut below).

## Everyday use

Instead of double-clicking NinjaTrader's own shortcut, use this one instead.

Create a desktop shortcut with:

- **Target:**
  ```
  powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\path\to\AutoLogin\Launch-NT8-AutoLogin.ps1"
  ```
- **Start in:** the `AutoLogin` folder

Double-click that instead of NinjaTrader's icon. It launches NT8 and fills
the password in for you.

If NT8 isn't installed at the default path
(`C:\Program Files\NinjaTrader 8\bin\NinjaTrader.exe`), add
`-NinjaTraderExePath "D:\Your\Actual\Path\NinjaTrader.exe"` to the target.

## Updating or removing the saved password

- **Change it:** re-run `Setup-NT8Credential.ps1` — it overwrites the saved
  entry.
- **Remove it:**
  ```powershell
  . .\CredentialStore.ps1
  Remove-GenericCredential -Target 'NT8AutoLogin'
  ```
  or delete it manually via Control Panel → Credential Manager → Windows
  Credentials → `NT8AutoLogin`.

## Notes / limitations

- The credential is protected by Windows DPAPI tied to your Windows user
  account — anyone logged in as *you* on this PC (or an admin) can still
  retrieve it, same as any other saved Windows credential (browser passwords,
  Wi-Fi keys, etc). It is not protected against someone who already has
  access to your Windows login.
- The script only fills the **password**; it does not touch "Sign in with
  Google/Apple" and won't interfere if you use one of those instead.
- If NT8 changes its sign-in dialog significantly in a future update and
  detection stops working, the script will just time out after 60s and print
  a warning — it won't type your password into the wrong place, since it
  only acts once it finds a password field *and* a "Log In" button together.
