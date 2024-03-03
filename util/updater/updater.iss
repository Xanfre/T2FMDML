; T2FMDML Automatic Updater
; Setup Script

#ifndef ModName
#define ModName "T2FMDML"
#endif
#define RepoName "T2FMDML"

#define AppName ModName + " Updater"
#define AppVersion "1.0"
#define AppPublisher "Xanfre"
#define AppURL "https://github.com/" + AppPublisher + "/" + RepoName

[Setup]
AppId={{BA5C87AE-B0BB-48D0-869D-CB813D44ECE2}
AppName={#AppName}
AppVersion={#AppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
CreateAppDir=no
;DisableFinishedPage=yes
;LicenseFile=LICENSE
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
OutputBaseFilename=updater
OutputDir=Output\{#ModName}
Compression=lzma
SolidCompression=yes
Uninstallable=no
WizardStyle=modern

[Files]
Source: 7za.exe; Flags: dontcopy

[Languages]
Name: "english"; MessagesFile: "updater_en.isl"

[Code]

var
  CheckDownloadPage: TDownloadWizardPage;
  FoundUpdatePage: TOutputMsgWizardPage;
  CurrentVersionUnknownPage: TOutputMsgWizardPage;
  CheckFailedPage: TOutputMsgWizardPage;
  NoUpdatePage: TOutputMsgWizardPage;
  UpdateDownloadPage: TDownloadWizardPage;
  UpdateDownloadSuccessPage: TOutputMsgWizardPage;
  UpdateDownloadFailedPage: TOutputMsgWizardPage;
  ExtractionPage: TOutputMarqueeProgressWizardPage;
  Prompt: TNewCheckBox;
  FoundUpdate: Boolean;
  CurrentVersionKnown: Boolean;
  UpdateCheckFailed: Boolean;
  UpdateDownloadFailed: Boolean;
  NewVersion: String;

type
  TShellExecuteInfo = record
    cbSize: DWORD;
    fMask: Cardinal;
    Wnd: HWND;
    lpVerb: String;
    lpFile: String;
    lpParameters: String;
    lpDirectory: String;
    nShow: Integer;
    hInstApp: THandle;
    lpIDList: DWORD;
    lpClass: String;
    hkeyClass: THandle;
    dwHotKey: DWORD;
    hMonitor: THandle;
    hProcess: THandle;
  end;
  TMsg = record
    hwnd: HWND;
    message: UINT;
    wParam: Longint;
    lParam: Longint;
    time: DWORD;
    pt: TPoint;
  end;

const
  WAIT_TIMEOUT = $00000102;
  SEE_MASK_NOCLOSEPROCESS = $00000040;
  INFINITE = $FFFFFFFF;
  PM_REMOVE = 1;

function ShellExecuteEx(var lpExecInfo: TShellExecuteInfo): BOOL;
  external 'ShellExecuteExW@shell32.dll stdcall';
function WaitForSingleObject(hHandle: THandle; dwMilliseconds: DWORD): DWORD;
  external 'WaitForSingleObject@kernel32.dll stdcall';
function CloseHandle(hObject: THandle): BOOL;
  external 'CloseHandle@kernel32.dll stdcall';
function PeekMessage(var lpMsg: TMsg; hWnd: HWND; wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): BOOL;
  external 'PeekMessageW@user32.dll stdcall';
function TranslateMessage(const lpMsg: TMsg): BOOL;
  external 'TranslateMessage@user32.dll stdcall';
function DispatchMessage(const lpMsg: TMsg): Longint;
  external 'DispatchMessageW@user32.dll stdcall';

{ Pump the message queue to prevent blocking the UI thread.
  The interface would be sluggish while doing long operations otherwise. }
procedure AppProcessMessage();
var
  Msg: TMsg;
begin
  while PeekMessage(Msg, WizardForm.Handle, 0, 0, PM_REMOVE) do begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;
end;

{ Extract a file to the location of setup while not blocking the UI thread. }
procedure Extract(archive: String);
var
  ExecInfo: TShellExecuteInfo;
begin
  ExecInfo.cbSize := SizeOf(ExecInfo);
  ExecInfo.fMask := SEE_MASK_NOCLOSEPROCESS;
  ExecInfo.Wnd := 0;
  ExecInfo.lpFile := ExpandConstant('{tmp}\7za.exe');
  ExecInfo.lpParameters := ExpandConstant('x "' + archive + '" -aoa -o"{src}"');
  ExecInfo.nShow := SW_HIDE;
  if ShellExecuteEx(ExecInfo) then begin
    while WaitForSingleObject(ExecInfo.hProcess, 5) = WAIT_TIMEOUT do begin
      AppProcessMessage;
      { This is only used on the extraction page. Calling Animate will pump the
        message queue to ensure form responsiveness. }
      ExtractionPage.Animate;
      { Uncomment the following line to simply refresh the form instead. }
      { WizardForm.Refresh; }
    end;
    CloseHandle(ExecInfo.hProcess);
  end;
end;

{ Detect if setup has write access to the setup directory. }
function HaveDirWriteAccess(): Boolean;
var
  FileName: String;
begin
  FileName := ExpandConstant('{src}\writetest.tmp');
  Result := SaveStringToFile(FileName, #10, False);
  if Result then
    DeleteFile(FileName);
end;

{ Compare the current version to that found at the remote repository. }
function CheckUpdate(): Boolean;
var
  file: AnsiString;
  current: String;
  latest: String;
begin
  Result := False;
  if LoadStringFromFile(ExpandConstant('{tmp}\latest.json'), file) then begin
    latest := file;
    if LoadStringFromFile(ExpandConstant('{src}\version'), file) then begin
      current := file;
      Trim(current);
      StringChangeEx(current, #13, '', True);
      StringChangeEx(current, #10, '', True);
      CurrentVersionKnown := Length(current) > 0;
    end;
    { To reduce complexity, we do not parse the JSON data in the strict sense.
      However, because we are only interested in one particular key-value pair,
      this simple string manipulation is sufficient.
      'tag_name' is the name of the release's tag on GitHub and is necessarily
      a string. }
    Delete(latest, 1, Pos('"tag_name"', latest)+9);
    Delete(latest, 1, Pos('"', latest));
    Delete(latest, Pos('"', latest), Length(latest));
    NewVersion := latest;
    Result := not CurrentVersionKnown or not SameStr(current, latest);
  end;
end;

{ Remove the old version of the program. }
procedure RemoveOldVersion;
begin
  { This implementation depends on the files originally delpoyed.
    In T2FMDML's case, this just consists of the gamesys DMLs in the root
    directory, the sq_scripts directory containing the helper scripts and the
    dbmods directory containing the mission and special-purpose DMLs. }
  DeleteFile(ExpandConstant('{src}\*.dml'));
  DelTree(ExpandConstant('{src}\dbmods'), True, True, True);
  DelTree(ExpandConstant('{src}/sq_scripts'), True, True, True);
end;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if Progress = ProgressMax then
    Log(Format('Successfully downloaded file to {tmp}: %s', [FileName]));
  Result := True;
end;

{ Extract the included 7-Zip binary to the temp directory. }
function InitializeSetup: Boolean;
begin
  ExtractTemporaryFile('7za.exe');
  Result := True;
end;

{ Set up custom pages and initialize global variables. }
procedure InitializeWizard;
begin
  CheckDownloadPage := CreateDownloadPage(ExpandConstant('{cm:UpdateCheck}'), ExpandConstant('{cm:UpdateCheckDesc}'), @OnDownloadProgress);
  FoundUpdatePage := CreateOutputMsgPage(wpReady, ExpandConstant('{cm:UpdateCheck}'), ExpandConstant('{cm:UpdateCheckCompleteDesc}'), ExpandConstant('{cm:UpdateCheckFoundMsg,{#ModName}}'));
  CurrentVersionUnknownPage := CreateOutputMsgPage(FoundUpdatePage.ID, ExpandConstant('{cm:UpdateCheck}'), ExpandConstant('{cm:UpdateCheckCompleteDesc}'), ExpandConstant('{cm:UpdateCheckUnknownMsg,{#ModName}}'));
  CheckFailedPage := CreateOutputMsgPage(CurrentVersionUnknownPage.ID, ExpandConstant('{cm:UpdateCheck}'), ExpandConstant('{cm:UpdateCheckCompleteDesc}'), ExpandConstant('{cm:UpdateCheckFailedMsg}'))
  NoUpdatePage := CreateOutputMsgPage(CheckFailedPage.ID, ExpandConstant('{cm:UpdateCheck}'), ExpandConstant('{cm:UpdateCheckCompleteDesc}'), ExpandConstant('{cm:UpdateCheckNoneMsg,{#ModName}}'));
  UpdateDownloadPage := CreateDownloadPage(ExpandConstant('{cm:UpdateDownload}'), ExpandConstant('{cm:UpdateDownloadDesc}'), @OnDownloadProgress);
  UpdateDownloadSuccessPage := CreateOutputMsgPage(NoUpdatePage.ID, ExpandConstant('{cm:UpdateDownload}'), ExpandConstant('{cm:UpdateDownloadSuccessDesc}'), ExpandConstant('{cm:UpdateDownloadSuccessMsg,{#ModName}}'));
  UpdateDownloadFailedPage := CreateOutputMsgPage(UpdateDownloadSuccessPage.ID, ExpandConstant('{cm:UpdateDownload}'), ExpandConstant('{cm:UpdateDownloadFailedDesc}'), ExpandConstant('{cm:UpdateDownloadFailedMsg,{#ModName}}'));
  ExtractionPage := CreateOutputMarqueeProgressPage(ExpandConstant('{cm:UpdateExtracting}'), ExpandConstant('{cm:UpdateExtractingDesc,{#ModName}}'));
  Prompt := TNewCheckbox.Create(WizardForm);
  Prompt.Parent := WizardForm;
  Prompt.Caption := ExpandConstant('{cm:UpdatePrompt}');
  Prompt.Left := WizardForm.ClientWidth - WizardForm.CancelButton.Left - WizardForm.CancelButton.Width + ScaleX(5);
  Prompt.Top := WizardForm.NextButton.Top + ScaleY(1);
  Prompt.Width := WizardForm.ClientWidth div 3;
  Prompt.Anchors := [akLeft, akBottom];
  Prompt.Checked := False;
  FoundUpdate := False;
  CurrentVersionKnown := False;
  UpdateCheckFailed := False;
  UpdateDownloadFailed := False;
end;

{ Handle showing the custom pages. }
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = wpReady then begin
    CheckDownloadPage.Clear;
    { The following is the GitHub endpoint for fetching information pertaining
      to the latest release formatted in JSON:
        https://api.github.com/repos/:owner/:repo/releases/latest
      See the following for more information:
        https://docs.github.com/en/rest/overview/endpoints-available-for-github-apps }
    CheckDownloadPage.Add('https://api.github.com/repos/{#AppPublisher}/{#ModName}/releases/latest', 'latest.json', '');
    CheckDownloadPage.Show;
    try
      try
        CheckDownloadPage.Download;
      except
        UpdateCheckFailed := True;
      end;
    finally
      if not UpdateCheckFailed then FoundUpdate := CheckUpdate;
      if not HaveDirWriteAccess then begin
        SuppressibleMsgBox(ExpandConstant('{cm:UpdaterNoWriteAccess,{#ModName}}'), mbError, MB_OK, IDOK);
        Result := False;
        Exit;
      end;
      CheckDownloadPage.Hide;
    end;
   end;
   if (CurPageID = FoundUpdatePage.ID) or (CurPageID = CurrentVersionUnknownPage.ID) or ((CurPageID = wpReady) and not Prompt.Checked and (FoundUpdate or not CurrentVersionKnown)) then begin
    UpdateDownloadPage.Clear;
    { GitHub releases can be linked according to the following pattern:
        https://github.com/:owner/:repo/releases/download/:tag
      All T2FMDML release assets are formatted as 'Name_Tag.zip'. }
    UpdateDownloadPage.Add('{#AppURL}/releases/download/' + NewVersion + '/{#ModName}_' + NewVersion + '.zip', '{#ModName}.zip', '');
    UpdateDownloadPage.Show;
    try
      try
        UpdateDownloadPage.Download;
      except
        UpdateDownloadFailed := True;
      end;
    finally
      UpdateDownloadPage.Hide;
      if not UpdateDownloadFailed then begin
        ExtractionPage.Show
        try;
          RemoveOldVersion;
          Extract(ExpandConstant('{tmp}\{#ModName}.zip'));
        finally
          ExtractionPage.Hide;
        end;
      end;
    end;
  end;
end;

{ Handle showing and hiding the prompt check box. }
procedure CurPageChanged(CurPageID: Integer);
begin
  if (CurPageID = wpReady) and not Prompt.Visible then Prompt.Show
  else if not (CurPageID = wpReady) and Prompt.Visible then Prompt.Hide;
end;

{ Skip certain pages depending on update check and download success. }
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  if PageID = FoundUpdatePage.ID then Result := not (FoundUpdate and CurrentVersionKnown and Prompt.Checked)
  else if PageID = CurrentVersionUnknownPage.ID then Result := not (FoundUpdate and not CurrentVersionKnown and Prompt.Checked)
  else if PageID = CheckFailedPage.ID then Result := not UpdateCheckFailed
  else if PageID = NoUpdatePage.ID then Result := not (not FoundUpdate and CurrentVersionKnown)
  else if PageID = UpdateDownloadPage.ID then Result := not FoundUpdate
  else if PageID = UpdateDownloadSuccessPage.ID then Result := not (FoundUpdate and not UpdateDownloadFailed)
  else if PageID = UpdateDownloadFailedPage.ID then Result := not (FoundUpdate and UpdateDownloadFailed);  
end;

{ Update the ready page to show only the location of the updater. }
function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
begin
  Result := ExpandConstant('{cm:ReadyInstLocation,{#ModName}}') + NewLine + Space + ExpandConstant('{src}') + NewLine + NewLine + ExpandConstant('{cm:ReadyRemoteRepo,{#ModName}}') + NewLine + Space + '{#AppURL}' + NewLine;
end;
