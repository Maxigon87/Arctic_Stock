; ====== SETUP BÁSICO ======
[Setup]
AppId={{A5C2D5D4-6A1E-4E6E-9F3C-ARCTIC-STOCK-UUID}}
AppName=Arctic Stock
AppVersion=1.0.0
AppPublisher=EMGI
DefaultDirName={pf}\Arctic Stock
DefaultGroupName=Arctic Stock
OutputDir=dist
OutputBaseFilename=ArcticStock-Setup-1.0.0
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern
SetupLogging=yes
; (Opcional) Ícono del instalador:
; SetupIconFile=assets\images\artic_logo.ico

; ====== ARCHIVOS ======
[Files]
Source: "C:\Users\MaxDev\Documents\Github\Arctic_Stock\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

; ====== ATAJOS ======
[Icons]
Name: "{group}\Arctic Stock"; Filename: "{app}\arctic_stock_app.exe"
Name: "{userdesktop}\Arctic Stock"; Filename: "{app}\arctic_stock_app.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Accesos directos:"; Flags: unchecked

; ====== POSTINSTALACIÓN ======
[Run]
Filename: "{app}\arctic_stock_app.exe"; Description: "Iniciar Arctic Stock"; Flags: nowait postinstall skipifsilent

; ====== CÓDIGO: asegurar %AppData% y config.json ======
[Code]
function GetAppDataDir(): string;
begin
  Result := ExpandConstant('{userappdata}') + '\ArcticStock';
end;

procedure EnsureAppData();
var
  dir: string;
begin
  dir := GetAppDataDir();
  if not DirExists(dir) then
    CreateDir(dir);
end;

procedure EnsureDefaultConfig();
var
  cfgPath, dbPath, S: string;
begin
  cfgPath := GetAppDataDir() + '\config.json';

  if not FileExists(cfgPath) then
  begin
    // Construyo la ruta y escapo las barras para JSON: C:\...\  ->  C:\\...\\
    dbPath := GetAppDataDir() + '\arctic_stock.db';
    StringChangeEx(dbPath, '\', '\\', True);

    S :=
      '{' + #13#10 +
      '  "backend": "sqlite",' + #13#10 +
      '  "sqlite_db_path": "' + dbPath + '",' + #13#10 +
      '  "cloud": {' + #13#10 +
      '    "provider": "supabase",' + #13#10 +
      '    "url": "",' + #13#10 +
      '    "anonKey": ""' + #13#10 +
      '  }' + #13#10 +
      '}' + #13#10;

    SaveStringToFile(cfgPath, S, False);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    EnsureAppData();
    EnsureDefaultConfig();
  end;
end;
