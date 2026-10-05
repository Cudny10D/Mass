; ============================================================
; setup.iss —— Mass 应用主体安装包（不含 LibreTranslate）
; ============================================================

#define MyAppName "Mass"
#define MyAppVersion "1.2.2"
#define MyAppPublisher "Cudny"
#define MyAppExeName "ArknightsMusicPlayer.exe"
#define MySourceDir "C:\Users\Cudny\Documents\cppfiles\ArknightsMusicPlayer\dist"
#define MyOutputDir "C:\Users\Cudny\Documents\cppfiles\ArknightsMusicPlayer\dist_installer"
#define MyIconFile "C:\Users\Cudny\Documents\cppfiles\ArknightsMusicPlayer\icon.ico"
#define MyChineseIsl "C:\Users\Cudny\Documents\cppfiles\ArknightsMusicPlayer\ChineseSimplified.isl"

[Setup]
AppId={{8E5F9A1B-3C4D-4E5F-A6B7-8C9D0E1F2A3B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppVerName={#MyAppName} {#MyAppVersion}

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

OutputDir={#MyOutputDir}
OutputBaseFilename=Mass_Setup_{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

WizardStyle=modern

SetupIconFile={#MyIconFile}
UninstallDisplayIcon={app}\{#MyAppExeName}

PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "chinesesimplified"; MessagesFile: "{#MyChineseIsl}"

[Tasks]
Name: "desktopicon"; \
    Description: "创建桌面快捷方式"; \
    GroupDescription: "附加任务："; \
    Flags: checkedonce

[Files]
; 主程序全部文件（不含 libre-server 目录）
Source: "{#MySourceDir}\*"; DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; \
    Excludes: "libre-server\*,nllb-server\*"
[Icons]
Name: "{group}\{#MyAppName}"; \
    Filename: "{app}\{#MyAppExeName}"; \
    IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\卸载 {#MyAppName}"; \
    Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; \
    Filename: "{app}\{#MyAppExeName}"; \
    IconFilename: "{app}\{#MyAppExeName}"; \
    Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; \
    Description: "启动 {#MyAppName}"; \
    Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\Mass"

; ============================================================
; 升级时自动卸载旧版本
; ============================================================
[Code]

function GetUninstallString(): String;
var
  sUnInstPath: String;
  sUnInstallString: String;
begin
  sUnInstPath := ExpandConstant('Software\Microsoft\Windows\CurrentVersion\Uninstall\{#emit SetupSetting("AppId")}_is1');
  sUnInstallString := '';
  if not RegQueryStringValue(HKLM, sUnInstPath, 'UninstallString', sUnInstallString) then
    RegQueryStringValue(HKCU, sUnInstPath, 'UninstallString', sUnInstallString);
  Result := sUnInstallString;
end;

function IsUpgrade(): Boolean;
begin
  Result := (GetUninstallString() <> '');
end;

function UnInstallOldVersion(): Integer;
var
  sUnInstallString: String;
  iResultCode: Integer;
begin
  Result := 0;
  sUnInstallString := GetUninstallString();
  if sUnInstallString = '' then
  begin
    Result := 1;
    Exit;
  end;
  sUnInstallString := RemoveQuotes(sUnInstallString);
  if Exec(sUnInstallString,
          '/SILENT /NORESTART /SUPPRESSMSGBOXES',
          '',
          SW_HIDE,
          ewWaitUntilTerminated,
          iResultCode) then
  begin
    Result := 3;
  end
  else
  begin
    Result := 2;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  UninstallResult: Integer;
  OldDir: String;
begin
  if CurStep = ssInstall then
  begin
    if IsUpgrade() then
    begin
      UninstallResult := UnInstallOldVersion();
      if UninstallResult = 2 then
      begin
        MsgBox('检测到旧版本，但自动卸载失败。' + #13#10 +
               '如果安装过程中出现文件占用错误，请手动卸载旧版本后重试。',
               mbInformation, MB_OK);
      end
      else if UninstallResult = 3 then
      begin
        Sleep(500);
        OldDir := ExpandConstant('{autopf}\{#MyAppName}');
        if DirExists(OldDir) then
          DelTree(OldDir, True, True, True);
      end;
    end;
  end;
end;