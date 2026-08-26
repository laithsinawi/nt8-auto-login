; Inno Setup script for NT8 Auto-Login.
; Builds a per-user installer (no admin rights needed) that copies the
; PowerShell scripts to %LocalAppData%\NT8AutoLogin, creates Start Menu /
; Desktop shortcuts that launch NinjaTrader with auto-login, and offers to
; run the credential setup right after install.
;
; Compile with: ISCC.exe installer\NT8AutoLogin.iss
; (see .github/workflows/build-installer.yml for the CI build)

#define MyAppName "NT8 Auto-Login"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Laith Sinawi"

[Setup]
AppId={{1550E24C-1CE5-43A3-B123-456098EB7032}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\NT8AutoLogin
DefaultGroupName=NT8 Auto-Login
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=Output
OutputBaseFilename=NT8AutoLogin-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "..\Launch-NT8-AutoLogin.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Setup-NT8Credential.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\CredentialStore.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\NT8 Auto-Login"; Filename: "powershell.exe"; Parameters: "-WindowStyle Hidden -ExecutionPolicy Bypass -File ""{app}\Launch-NT8-AutoLogin.ps1"""; WorkingDir: "{app}"
Name: "{group}\Set Up NT8 Credential"; Filename: "powershell.exe"; Parameters: "-NoExit -ExecutionPolicy Bypass -File ""{app}\Setup-NT8Credential.ps1"""; WorkingDir: "{app}"
Name: "{group}\Uninstall NT8 Auto-Login"; Filename: "{uninstallexe}"
Name: "{autodesktop}\NT8 Auto-Login"; Filename: "powershell.exe"; Parameters: "-WindowStyle Hidden -ExecutionPolicy Bypass -File ""{app}\Launch-NT8-AutoLogin.ps1"""; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "powershell.exe"; Parameters: "-NoExit -ExecutionPolicy Bypass -File ""{app}\Setup-NT8Credential.ps1"""; Description: "Set up your NinjaTrader credential now"; Flags: postinstall runascurrentuser skipifsilent
