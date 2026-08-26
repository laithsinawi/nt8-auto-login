# NT8 Auto-Login

Fills in the password on the NinjaTrader account sign-in dialog automatically,
so you only type it once (during setup) instead of on every restart.

Runs on Windows only (this is where NT8 itself runs).

## Install

1. Grab [`dist/NT8AutoLogin-Setup.exe`](dist/NT8AutoLogin-Setup.exe) from
   this repo and copy it to the Windows PC. (A fresh build is also produced
   by the **Build Installer** GitHub Action on every push, under its
   Artifacts, if you want the latest instead of the checked-in copy.)
2. Run it. It's a normal per-machine-user installer — no admin rights
   needed. It will:
   - Install the scripts to `%LocalAppData%\NT8AutoLogin`.
   - Create Start Menu shortcuts (**NT8 Auto-Login**, **Set Up NT8
     Credential**, **Uninstall**) and, if you leave the box checked, a
     Desktop shortcut too.
   - Offer to open **Set Up NT8 Credential** right after install so you can
     enter your NinjaTrader username/password once — see [How it
     works](#how-it-works) for how that's stored.
3. Windows SmartScreen may warn about an unrecognized publisher since the
   installer isn't code-signed — click **More info → Run anyway**.

Building the installer requires [Inno Setup](https://jrsoftware.org/isinfo.php),
which is Windows-only; it's compiled automatically by
`.github/workflows/build-installer.yml` on a `windows-latest` GitHub Actions
runner, so you don't need Inno Setup installed locally to get a `.exe`.

### Everyday use

Use the **NT8 Auto-Login** shortcut (Start Menu or Desktop) instead of
NinjaTrader's own icon. It launches NT8 and fills the password in for you.

If NT8 isn't installed at the default path
(`C:\Program Files\NinjaTrader 8\bin\NinjaTrader.exe`), edit the shortcut's
target to add `-NinjaTraderExePath "D:\Your\Actual\Path\NinjaTrader.exe"`.

### Manual install (no installer)

Prefer running the scripts in place instead of installing? Copy this
`AutoLogin` folder to the Windows PC, then:

```powershell
cd path\to\AutoLogin
.\Setup-NT8Credential.ps1
```

If PowerShell blocks the scripts ("running scripts is disabled"), run
PowerShell as your normal user (not admin needed) and either:
- `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`, or
- always launch scripts with `powershell -ExecutionPolicy Bypass -File ...`.

Then create a shortcut with:
- **Target:**
  ```
  powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\path\to\AutoLogin\Launch-NT8-AutoLogin.ps1"
  ```
- **Start in:** the `AutoLogin` folder

## How it works

- Your password is stored **once**, encrypted, in **Windows Credential
  Manager** (the same OS vault Windows/Edge/Office use) — never in a plaintext
  file, never hardcoded in a script.
- `Launch-NT8-AutoLogin.ps1` starts NinjaTrader, waits for the sign-in dialog
  (detected by its password field + "Log In" button, not by window title, so
  it survives NT8 updates), types the password into it, and clicks **Log In**.
  Your username field already autofills on its own, so this script leaves it
  alone.

## Updating or removing the saved password

- **Change it:** re-run the **Set Up NT8 Credential** shortcut (or
  `Setup-NT8Credential.ps1` directly) — it overwrites the saved entry.
- **Remove it:** delete it via Control Panel → Credential Manager → Windows
  Credentials → `NT8AutoLogin`, or from PowerShell:
  ```powershell
  . "$env:LocalAppData\NT8AutoLogin\CredentialStore.ps1"
  Remove-GenericCredential -Target 'NT8AutoLogin'
  ```
  Uninstalling the app (Start Menu → **Uninstall NT8 Auto-Login**, or Apps &
  Features) removes the installed files and shortcuts but leaves the saved
  credential in Credential Manager — remove it separately as above if you
  want it gone too.

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
