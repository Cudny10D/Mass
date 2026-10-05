; ============================================================
; setup-nllb.iss —— Mass NLLB-200 离线翻译补丁包
;
; 依赖：Mass 主程序已安装
; 卸载：只删除 nllb-server 目录，不影响主程序
; ============================================================

#define MyAppName "Mass"
#define MyAppVersion "1.2.2"
#define MyPatchName "Mass NLLB-200 离线翻译补丁"
#define MyPatchVersion "1.2.2"
#define MyPublisher "Cudny"
#define MyMainExeName "ArknightsMusicPlayer.exe"
#define MyNLLBSourceDir "C:\Users\Cudny\Documents\cppfiles\ArknightsMusicPlayer\dist-libre\nllb-server"
#define MyOutputDir "C:\Users\Cudny\Documents\cppfiles\ArknightsMusicPlayer\dist_installer"
#define MyIconFile "C:\Users\Cudny\Documents\cppfiles\ArknightsMusicPlayer\icon.ico"
#define MyChineseIsl "C:\Users\Cudny\Documents\cppfiles\ArknightsMusicPlayer\ChineseSimplified.isl"

[Setup]
; 独立 AppId，与主程序区分
AppId={{8E5F9A1B-3C4D-4E5F-A6B7-8C9D0E1F2A3C}
AppName={#MyPatchName}
AppVersion={#MyPatchVersion}
AppPublisher={#MyPublisher}
AppVerName={#MyPatchName} {#MyPatchVersion}

DefaultDirName={autopf}\{#MyAppName}
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=no
DisableFinishedPage=no

OutputDir={#MyOutputDir}
OutputBaseFilename=Mass_NLLB_Patch_{#MyPatchVersion}
Compression=lzma2/fast
SolidCompression=no
LZMAUseSeparateProcess=yes

WizardStyle=modern

SetupIconFile={#MyIconFile}

PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "chinesesimplified"; MessagesFile: "{#MyChineseIsl}"

[Files]
Source: "{#MyNLLBSourceDir}\*"; DestDir: "{app}\nllb-server"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Messages]
SetupAppRunningError=安装程序检测到 %1 正在运行。%n%n请先关闭 Mass 音乐播放器，然后点击"确定"继续，或点击"取消"退出。

[Code]

const
  MAIN_APP_ID = '{8E5F9A1B-3C4D-4E5F-A6B7-8C9D0E1F2A3B}_is1';

// ------------------------------------------------------------
// 检测主程序是否已安装
// ------------------------------------------------------------
function IsMainAppInstalled(): Boolean;
var
  sUnInstPath: String;
  sUnInstallString: String;
begin
  sUnInstPath := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + MAIN_APP_ID;
  sUnInstallString := '';

  if RegQueryStringValue(HKLM, sUnInstPath, 'UninstallString', sUnInstallString) then
  begin
    Result := True;
    Exit;
  end;

  if RegQueryStringValue(HKCU, sUnInstPath, 'UninstallString', sUnInstallString) then
  begin
    Result := True;
    Exit;
  end;

  Result := False;
end;

// ------------------------------------------------------------
// 获取主程序安装目录
// ------------------------------------------------------------
function GetMainAppDir(): String;
var
  sUnInstPath: String;
  sValue: String;
  p: Integer;
begin
  sUnInstPath := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + MAIN_APP_ID;

  // 优先 InstallLocation
  sValue := '';
  if RegQueryStringValue(HKLM, sUnInstPath, 'InstallLocation', sValue) and (sValue <> '') then
  begin
    Result := sValue;
    Exit;
  end;
  if RegQueryStringValue(HKCU, sUnInstPath, 'InstallLocation', sValue) and (sValue <> '') then
  begin
    Result := sValue;
    Exit;
  end;

  // 从 UninstallString 反推
  sValue := '';
  if not RegQueryStringValue(HKLM, sUnInstPath, 'UninstallString', sValue) then
    RegQueryStringValue(HKCU, sUnInstPath, 'UninstallString', sValue);

  sValue := RemoveQuotes(sValue);
  p := Pos('\unins', LowerCase(sValue));
  if p > 0 then
    sValue := Copy(sValue, 1, p - 1);

  Result := sValue;
end;

// ------------------------------------------------------------
// 启动前检查
// ------------------------------------------------------------
function InitializeSetup(): Boolean;
begin
  Result := True;

  if not IsMainAppInstalled() then
  begin
    MsgBox('未检测到 Mass 音乐播放器。' + #13#10 + #13#10 +
           '请先安装 Mass 应用主体，然后重新运行此补丁包。',
           mbCriticalError, MB_OK);
    Result := False;
    Exit;
  end;
end;

// ------------------------------------------------------------
// 强制使用主程序的安装目录
// ------------------------------------------------------------
procedure InitializeWizard();
var
  MainDir: String;
begin
  MainDir := GetMainAppDir();
  if MainDir <> '' then
    WizardForm.DirEdit.Text := MainDir;
end;

// ------------------------------------------------------------
// 卸载时只删除 nllb-server 目录（保留主程序）
// ------------------------------------------------------------
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  NLLBDir: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    NLLBDir := ExpandConstant('{app}\nllb-server');
    if DirExists(NLLBDir) then
      DelTree(NLLBDir, True, True, True);
  end;
end;