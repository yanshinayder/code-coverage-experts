unit CCE.Wizard.Forms;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls,
  ToolsAPI, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.ExtDlgs,
  System.IOUtils,
  Vcl.FileCtrl,
  CCE.Core.Interfaces,
  CCE.Core.Project,
  CCE.Core.CodeCoverage,
  CCE.Helpers.CheckListBox,
  CCE.Helpers.TreeView,
  System.Generics.Collections, Vcl.CheckLst, Vcl.Menus, Vcl.Buttons,
  System.ImageList, Vcl.ImgList;

const
  UNCHECKED_INDEX = 0;
  CHECKED_INDEX = 1;
  GRAYED_INDEX = 2;

type
  TCCEWizardForms = class(TForm)
    pgcWizard: TPageControl;
    tsFiles: TTabSheet;
    pnlBottom: TPanel;
    btnNext: TButton;
    btnPrevious: TButton;
    pnlTop: TPanel;
    lblTitle: TLabel;
    edtExeName: TLabeledEdit;
    btnSelectExeName: TButton;
    edtMapFileName: TLabeledEdit;
    btnSelectMapFile: TButton;
    edtCoverageExeName: TLabeledEdit;
    btnSelectCodeCoverage: TButton;
    edtOutputReport: TLabeledEdit;
    btnOutputReport: TButton;
    openTextDialog: TOpenTextFileDialog;
    grpOutputFormat: TGroupBox;
    chkXmlReport: TCheckBox;
    chkHtmlReport: TCheckBox;
    chkEmmaReport: TCheckBox;
    btnFinish: TButton;
    chkLog: TCheckBox;
    chkUseRelativePath: TCheckBox;
    tsTreeView: TTabSheet;
    tvPaths: TTreeView;
    iltreeView: TImageList;
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnPreviousClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnSelectExeNameClick(Sender: TObject);
    procedure btnSelectCodeCoverageClick(Sender: TObject);
    procedure btnSelectMapFileClick(Sender: TObject);
    procedure btnOutputReportClick(Sender: TObject);
    procedure btnFinishClick(Sender: TObject);
    procedure tvPathsDblClick(Sender: TObject);
  private
    FProject: ICCEProject;
    FTreeNodes: TDictionary<String, TTreeNode>;

    function GetNode(APath: String): TTreeNode;
    procedure AddPathInTreeView(APath: String);

    procedure RefreshAll;

    procedure CheckTreeView;
    procedure CheckChilds (ANode: TTreeNode; AIndex: Integer);
    procedure CheckParents(ANode: TTreeNode);

    procedure searchFile(FilterText, FilterExt: string; AComponent: TCustomEdit);
    procedure selectFolder(AComponent: TCustomEdit);

    procedure ListPaths;
    procedure ListUnits(Path: String);

    procedure InitialValues;
    procedure ApplyTheme;
    procedure HideTabs;
    procedure SelectPageNext;
    procedure SelectPagePrevious;
  public
    constructor create(AOwner: TComponent; Project: IOTAProject); reintroduce;
    destructor Destroy; override;
    { Public declarations }
  end;

var
  CCEWizardForms: TCCEWizardForms;

implementation

{$R *.dfm}

{ TCCEWizardForms }

procedure TCCEWizardForms.AddPathInTreeView(APath: String);
var
  i: Integer;
  nodeParent: TTreeNode;
  node: TTreeNode;
  text: String;
  pathParent: String;
  path: String;
  splittedPath: TArray<string>;
begin
  splittedPath := APath.Split(['\']);

  nodeParent := nil;
  pathParent := '';
  for i := 0 to Pred(Length(splittedPath)) do
  begin
    text := splittedPath[i];
    if text = '' then
      Continue;
    path := path + text + '\';
    node := GetNode(path);
    if Assigned(node) then
      Continue;

    if i = 0 then
    begin
      nodeParent := tvPaths.Items.AddChild(nil, text);
      nodeParent.ImageIndex := CHECKED_INDEX;
      nodeParent.SelectedIndex := CHECKED_INDEX;
      FTreeNodes.Add(path, nodeParent);
      nodeParent := nil;
      Continue;
    end;

    pathParent := Copy(path, 1, path.length - text.Length - 1);
    nodeParent := GetNode(pathParent);
    if Assigned(nodeParent) then
    begin
      nodeParent := tvPaths.Items.AddChild(nodeParent, text);
      nodeParent.ImageIndex := CHECKED_INDEX;
      nodeParent.SelectedIndex := CHECKED_INDEX;
      FTreeNodes.Add(path, nodeParent);
      nodeParent := nil;
      Continue;
    end;
  end;
end;

procedure TCCEWizardForms.ApplyTheme;
{$IF CompilerVersion > 31.0}
var
  theme: IOTAIDEThemingServices250;
  i: Integer;
{$ENDIF}
begin
  {$IF CompilerVersion > 31.0}
  theme := (BorlandIDEServices as IOTAIDEThemingServices250);
  theme.RegisterFormClass(TCCEWizardForms);

  for i := 0 to Pred(Self.ComponentCount) do
  begin
    if Components[i] is TLabel then
      theme.ApplyTheme(TLabel(Components[i]));
//
//    if Components[i] is TComboBox then
//      theme.ApplyTheme(TComboBox(Components[i]));
    if Components[i] is TPageControl then
    begin
      theme.ApplyTheme(TPageControl(Components[i]));
      TPageControl(Components[i]).Repaint;
    end;

    if Components[i] is TTabSheet then
    begin
      theme.ApplyTheme(TTabSheet(Components[i]));
      TTabSheet(Components[i]).Repaint;
    end;

    if Components[i] is TPanel then
      theme.ApplyTheme(TPanel(Components[i]));

    if Components[i] is TLabeledEdit then
      theme.ApplyTheme(TLabeledEdit(Components[i]));

    if Components[i] is TWinControl then
      theme.ApplyTheme(TWinControl(Components[i]));
  end;
//    theme.StyleServices.
  {$ENDIF}
end;

procedure TCCEWizardForms.btnPreviousClick(Sender: TObject);
begin
  SelectPagePrevious;
end;

procedure TCCEWizardForms.btnSelectCodeCoverageClick(Sender: TObject);
begin
  searchFile('Code Coverage File', 'exe', edtCoverageExeName);
end;

procedure TCCEWizardForms.btnSelectExeNameClick(Sender: TObject);
begin
  searchFile('Test Project', 'exe', edtExeName);
end;

procedure TCCEWizardForms.btnSelectMapFileClick(Sender: TObject);
begin
  searchFile('Map File', 'map', edtMapFileName);
end;

procedure TCCEWizardForms.CheckChilds(ANode: TTreeNode; AIndex: Integer);
var
  i: Integer;
  childNode: TTreeNode;
begin
  childNode := ANode.getFirstChild;

  while childNode <> nil do
  begin
    childNode.ImageIndex := AIndex;
    childNode.SelectedIndex := AIndex;
    CheckChilds(childNode, AIndex);

    childNode := ANode.GetNextChild(childNode);
  end;
end;

procedure TCCEWizardForms.CheckParents(ANode: TTreeNode);
var
  nodeParent: TTreeNode;
  hasCheck: Boolean;
  hasUnCheck: Boolean;
  hasGrayed: Boolean;
  i: Integer;
  childNode: TTreeNode;
  index: Integer;
begin
  nodeParent := ANode.Parent;
  if not Assigned(nodeParent) then
    Exit;

  hasCheck := False;
  hasUnCheck := False;
  hasGrayed := False;

  childNode := nodeParent.getFirstChild;
  while childNode <> nil do
  begin
    index := childNode.ImageIndex;
    hasCheck := (hasCheck) or (index = CHECKED_INDEX);
    hasUnCheck := (hasUnCheck) or (index = UNCHECKED_INDEX);
    hasGrayed := (hasGrayed) or (index = GRAYED_INDEX);

    childNode := nodeParent.GetNextChild(childNode);
  end;

  index := UNCHECKED_INDEX;
  if (hasCheck and hasUnCheck) or (hasGrayed) then
    index := GRAYED_INDEX
  else
  if hasCheck then
    index := CHECKED_INDEX;

  nodeParent.ImageIndex := index;
  nodeParent.SelectedIndex := index;
  CheckParents(nodeParent);
end;

procedure TCCEWizardForms.btnFinishClick(Sender: TObject);
begin
  TCCECoreCodeCoverage.New
    .CodeCoverageFileName(edtCoverageExeName.Text)
    .ExeFileName(edtExeName.Text)
    .MapFileName(edtMapFileName.Text)
    .OutputReport(edtOutputReport.Text)
    .Paths(FProject.ListAllPaths)
    .Units(FProject.ListAllUnits)
    .GenerateHtml(chkHtmlReport.Checked)
    .GenerateXml(chkXmlReport.Checked)
    .GenerateEmma(chkEmmaReport.Checked)
    .GenerateLog(chkLog.Checked)
    .UseRelativePath(chkUseRelativePath.Checked)
    .Save;
end;

procedure TCCEWizardForms.btnNextClick(Sender: TObject);
begin
  SelectPageNext;
end;

procedure TCCEWizardForms.btnOutputReportClick(Sender: TObject);
begin
  selectFolder(edtOutputReport);
end;

procedure TCCEWizardForms.checkTreeView;
var
  imageIndex: Integer;
  nodeSelected: TTreeNode;
begin
  nodeSelected := tvPaths.Selected;
  imageIndex := UNCHECKED_INDEX;
  if nodeSelected.ImageIndex = UNCHECKED_INDEX then
    imageIndex := CHECKED_INDEX;

  nodeSelected.ImageIndex := imageIndex;
  nodeSelected.SelectedIndex := imageIndex;

  CheckChilds(nodeSelected, imageIndex);
  CheckParents(nodeSelected);
end;

constructor TCCEWizardForms.create(AOwner: TComponent; Project: IOTAProject);
begin
  inherited create(AOwner);
  FTreeNodes := TDictionary<String, TTreeNode>.create;
  FProject := TCCECoreProject.New(Project);
end;

destructor TCCEWizardForms.Destroy;
begin
  FTreeNodes.Free;
  inherited;
end;

procedure TCCEWizardForms.FormCreate(Sender: TObject);
begin
  HideTabs;
  InitialValues;
end;

procedure TCCEWizardForms.FormShow(Sender: TObject);
begin
//  ApplyTheme;
end;

function TCCEWizardForms.GetNode(APath: String): TTreeNode;
begin
  result := nil;
  if FTreeNodes.ContainsKey(APath) then
    result := FTreeNodes.Items[APath];
end;

procedure TCCEWizardForms.HideTabs;
var
  i: Integer;
begin
  pgcWizard.ActivePageIndex := 0;

  for i := 0 to Pred(pgcWizard.PageCount) do
    pgcWizard.Pages[i].TabVisible := False;

  SelectPageNext;
end;

procedure TCCEWizardForms.InitialValues;
begin
//  edtExeName.Text := FProject.ExeName;
//  edtMapFileName.Text := FProject.MapFileName;

  ListPaths;
end;

procedure TCCEWizardForms.ListPaths;
var
  paths: TArray<String>;
  i: Integer;
begin
  paths := FProject.ListAllPaths;

  for i := 0 to Pred(Length(paths)) do
    if TDirectory.Exists(paths[i]) then
    begin
      ListUnits(Paths[i]);
    end;
end;

procedure TCCEWizardForms.ListUnits(Path: String);
var
  units: TArray<String>;
  i: Integer;
begin
  units := FProject.ListAllUnits(Path);
  for i := 0 to Pred(Length( units )) do
    AddPathInTreeView(units[i]);

end;

procedure TCCEWizardForms.RefreshAll;
begin
//  FProject.re
end;

procedure TCCEWizardForms.searchFile(FilterText, FilterExt: string; AComponent: TCustomEdit);
begin
  openTextDialog.Filter := Format('%s | *.%s', [FilterText, FilterExt]);
  if openTextDialog.Execute then
    AComponent.Text := openTextDialog.FileName;
end;

procedure TCCEWizardForms.selectFolder(AComponent: TCustomEdit);
var
  path: string;
begin
  path := FProject.ProjectPath;
  if SelectDirectory('Select Directory', '', path) then
    AComponent.Text := path;
end;

procedure TCCEWizardForms.SelectPageNext;
begin
  pgcWizard.SelectNextPage(True, False);
  btnNext.Enabled := pgcWizard.ActivePageIndex < (pgcWizard.PageCount - 1);
  btnPrevious.Enabled := True;
end;

procedure TCCEWizardForms.SelectPagePrevious;
begin
  pgcWizard.SelectNextPage(False, False);
  btnPrevious.Enabled := pgcWizard.ActivePageIndex > 0;
  btnNext.Enabled := True;
end;

procedure TCCEWizardForms.tvPathsDblClick(Sender: TObject);
begin
  CheckTreeView;
end;

end.
