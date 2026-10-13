#ifndef PortableDir
  #error Pass /DPortableDir with the path to the clean portable client.
#endif
#ifndef OutputDir
  #error Pass /DOutputDir with the installer output directory.
#endif

[Setup]
AppId={{B67DA60B-8B52-4DB6-A12F-AD2EAC82C667}
AppName=DaoYuan-NEW
AppVersion=1.0.0
AppVerName=DaoYuan-NEW 1.0.0
AppPublisher=DaoYuan
DefaultDirName={localappdata}\Programs\DaoYuan-NEW
DefaultGroupName=DaoYuan-NEW
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=DaoYuan-NEW-Setup-1.0.0
SetupIconFile=..\apps\desktop\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\道渊微端.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Dirs]
Name: "{app}\runtime"; Flags: uninsneveruninstall

[Files]
Source: "{#PortableDir}\道渊微端.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PortableDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PortableDir}\native_assets.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PortableDir}\version.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PortableDir}\使用说明.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PortableDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PortableDir}\scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PortableDir}\resources\*"; DestDir: "{app}\resources"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PortableDir}\resources\sillytavern\.git\*"; DestDir: "{app}\resources\sillytavern\.git"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PortableDir}\resources\sillytavern\public\scripts\extensions\third-party\JS-Slash-Runner\.git\*"; DestDir: "{app}\resources\sillytavern\public\scripts\extensions\third-party\JS-Slash-Runner\.git"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#PortableDir}\resources\sillytavern\public\scripts\extensions\third-party\ST-Prompt-Template\.git\*"; DestDir: "{app}\resources\sillytavern\public\scripts\extensions\third-party\ST-Prompt-Template\.git"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\DaoYuan-NEW"; Filename: "{app}\道渊微端.exe"
Name: "{autodesktop}\DaoYuan-NEW"; Filename: "{app}\道渊微端.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; Flags: unchecked

[Run]
Filename: "{app}\道渊微端.exe"; Description: "启动 DaoYuan-NEW"; Flags: nowait postinstall skipifsilent
