[Setup]
AppName=Flash Note
AppVersion={#MyAppVersion}
AppPublisher=SiRanDev
AppPublisherURL=https://github.com/SiRan-Dev/FlashNote
DefaultDirName={autopf}\FlashNote
DefaultGroupName=Flash Note
OutputDir=..\installer_output
OutputBaseFilename=flashnote-windows-installer-v{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Flash Note"; Filename: "{app}\flashnote.exe"
Name: "{group}\Uninstall Flash Note"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Flash Note"; Filename: "{app}\flashnote.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Run]
Filename: "{app}\flashnote.exe"; Description: "Launch Flash Note"; Flags: nowait postinstall skipifsilent
