unit CCE.Core.Project;

interface

uses
  Dccstrs,
  ToolsAPI,
  CCE.Core.Interfaces,
  CCE.Core.Utils,
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils,
  System.Types,
  System.Classes;

type TCCECoreProject = class(TInterfacedObject, ICCEProject)

  private
    FProject: IOTAProject;
    FActiveConfig: IOTABuildConfiguration;
    FSelectedPaths: TList<String>;
    FSelectedUnits: TList<String>;

    function ProjectPath: string;
    function GetSearchPaths: TList<String>;

  public
    function Clear: ICCEProject;
    function OutputPath: string;
    function ExeName: String;
    function MapFileName: string;

    function ListAllPaths: TArray<String>;
    function ListAllUnits(Path: String): TArray<String>; overload;
    function ListAllUnits: TArray<String>; overload;

    function AddPath(Value: string): ICCEProject;
    function AddUnit(Value: string): ICCEProject;
    function AddAllUnits(Path: string): ICCEProject;

    function RemovePath(Value: String): ICCEProject;
    function RemoveUnit(Value: String): ICCEProject;
    function RemoveAllUnits(Path: String): ICCEProject;

    constructor create(Project: IOTAProject);
    class function New(Project: IOTAProject): ICCEProject;
    destructor Destroy; override;
end;

implementation

{ TCCECoreProject }

function TCCECoreProject.AddAllUnits(Path: string): ICCEProject;
var
  units: TArray<String>;
  i: Integer;
begin
  result := Self;
  units := ListAllUnits(Path);
  for i := 0 to Pred(Length(units)) do
    AddUnit(units[i]);

end;

function TCCECoreProject.AddPath(Value: string): ICCEProject;
begin
  result := Self;
  if not FSelectedPaths.Contains(Value) then
    FSelectedPaths.Add(Value);
end;

function TCCECoreProject.AddUnit(Value: string): ICCEProject;
begin
  result := Self;
  if not FSelectedUnits.Contains(Value) then
    FSelectedUnits.Add(Value);
end;

function TCCECoreProject.Clear: ICCEProject;
var
  i: Integer;
begin
  result := Self;
  for i := Pred(FSelectedPaths.Count) downto 0 do
    RemovePath(FSelectedPaths[i]);

  for i := Pred(FSelectedUnits.Count) downto 0 do
    RemoveUnit(FSelectedUnits[i]);
end;

constructor TCCECoreProject.create(Project: IOTAProject);
begin
  FProject := Project;
  FActiveConfig := (Project.ProjectOptions as IOTAProjectOptionsConfigurations)
                      .ActiveConfiguration;

  FSelectedPaths := TList<String>.create;
  FSelectedUnits := TList<String>.create;
end;

destructor TCCECoreProject.Destroy;
begin
  FSelectedPaths.Free;
  FSelectedUnits.Free;
  inherited;
end;

function TCCECoreProject.ExeName: String;
begin
  Result := OutputPath +
                ChangeFileExt(ExtractFileName(FProject.FileName), '.exe');
end;

function TCCECoreProject.GetSearchPaths: TList<String>;
var
  searchPath: TStrings;
  path: string;
  i: Integer;
begin
  searchPath := TStringList.Create;
  try
    result := TList<String>.create;
    try
      FActiveConfig.GetValues(sUnitSearchPath, searchPath, True);
      for i := 0 to Pred(searchPath.Count) do
      begin
        path := RelativeToAbsolutePath(searchPath[i], ProjectPath);
        result.Add(path);
      end;

    except
      result.Free;
    end;
  finally
    searchPath.Free;
  end;
end;

function TCCECoreProject.ListAllPaths: TArray<String>;
var
  i: Integer;
  paths: TList<String>;
  searchPath: TList<String>;
  path: string;
begin
  paths := TList<String>.create;
  try
    for i := 0 to Pred(FProject.GetModuleCount) do
    begin
      if ExtractFileExt(FProject.GetModule(i).FileName) = '.pas' then
      begin
        path := ExtractFilePath(FProject.GetModule(i).FileName);
        if (not paths.Contains(path)) then
          paths.Add(path);
      end;
    end;

    searchPath := Self.GetSearchPaths;
    try
      for i := 0 to Pred(searchPath.Count) do
      begin
        path := searchPath.Items[i];
        if (not paths.Contains(path)) then
          paths.Add(path);
      end;
    finally
      searchPath.Free;
    end;

    result := paths.ToArray;
  finally
    paths.Free;
  end;
end;

function TCCECoreProject.ListAllUnits: TArray<String>;
begin
  result := FSelectedUnits.ToArray;
end;

function TCCECoreProject.ListAllUnits(Path: String): TArray<String>;
var
  i: Integer;
  files: TStringDynArray;
begin
  files := TDirectory.GetFiles(Path);

  for i := 0 to Pred(Length(files)) do
  begin
    if ExtractFileExt(files[i]) = '.pas' then
    begin
      SetLength(result, Length(result) + 1);
      result[Length(result) - 1] := files[i];
    end;
  end;
end;

function TCCECoreProject.MapFileName: string;
begin
  result := ChangeFileExt(ExeName, '.map');
end;

class function TCCECoreProject.New(Project: IOTAProject): ICCEProject;
begin
  result := Self.create(Project);
end;

function TCCECoreProject.OutputPath: string;
begin
  result := FActiveConfig.GetValue(sExeOutput);
  result := RelativeToAbsolutePath(Result, ProjectPath)
                 .Replace('$(Platform)', FActiveConfig.Platform)
                 .Replace('$(Config)', FActiveConfig.Name) + '\';

  result := Result.Replace('\\', '\');
end;

function TCCECoreProject.ProjectPath: string;
begin
  result := ExtractFilePath(FProject.FileName);
end;

function TCCECoreProject.RemoveAllUnits(Path: String): ICCEProject;
var
  i: Integer;
  unitPath: string;
begin
  result := Self;
  for i := Pred(FSelectedUnits.Count) downto 0 do
  begin
    unitPath := ExtractFilePath(FSelectedUnits[i]);
    if Path.ToLower = unitPath.ToLower then
      RemoveUnit(FSelectedUnits[i]);
  end;
end;

function TCCECoreProject.RemovePath(Value: String): ICCEProject;
begin
  result := Self;
  FSelectedPaths.Remove(Value);
end;

function TCCECoreProject.RemoveUnit(Value: String): ICCEProject;
begin
  result := Self;
  FSelectedUnits.Remove(Value);
end;

end.
