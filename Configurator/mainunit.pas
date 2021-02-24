unit MainUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Spin,
  ExtCtrls, Arrow, Math, Unix, SelectedRect, FPImage, YUV2Camera, IniFiles,
  SaveSampleUnit;

var
  ConfigPath: ansistring = '~/.seedsorter/';
  ConfigFile: ansistring = '~/.seedsorter/config.ini';
  ConfigTruePath: ansistring = '~/.seedsorter/true/';
  ConfigFalsePath: ansistring = '~/.seedsorter/false/';

type

  { TMainForm }

  TMainForm = class(TForm)
    AddAreaBtn: TButton;
    Arrow1: TArrow;
    Arrow2: TArrow;
    Arrow3: TArrow;
    Arrow4: TArrow;
    Label1: TLabel;
    PaintBox1: TPaintBox;
    SaveAsBtn: TButton;
    ScrollBox1: TScrollBox;
    ScrollBox2: TScrollBox;
    TakePhotoBtn: TButton;
    RefreshDeviceListBtn: TButton;
    CameraSettingsGB: TGroupBox;
    DeviceSelector: TComboBox;
    Timer1: TTimer;
    XResolutionSpinEdit: TSpinEdit;
    YResolutionSpinEdit: TSpinEdit;
    procedure AddAreaBtnClick(Sender: TObject);
    procedure ArrowClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
    procedure RefreshDeviceListBtnClick(Sender: TObject);
    procedure SaveAsBtnClick(Sender: TObject);
    procedure TakePhotoBtnClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    SamplePhoto: TBitmap;
    Selections: array of TSelectedRect;
    ToBeFreed: TStringList;
    procedure ForceRepaint(Sender: TObject);
    procedure RemoveItem(Item: TObject);
  public
    procedure SaveSelectionToFile(Selection: TSelectedRect;
      const FileName: ansistring);
    procedure SaveSelectionAs(const Index: integer); overload;
    procedure SaveSelectionAs(const Index: integer; const Verdict: boolean); overload;
    procedure SaveSelectionsAs(const Verdict: boolean;
      const FirstIndex: integer = 0); overload;
    procedure SaveSelectionsAs; overload;
    procedure SaveConfigToFile(const FileName: ansistring);
    procedure LoadConfigFromFile(const FileName: ansistring);
    procedure UpdateSelectionIndex;
    function TakePhoto(const Device: ansistring;
      const AWidth, AHeight: integer): boolean;
    procedure MoveSelections(const MoveVector : TPoint);
    procedure RefreshDeviceList;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

function FPColorToLongWord(const c: TFPColor): longword; inline;
begin
  Result := (c.red shr 8) or (c.green and $FF00) or ((c.blue and $FF00) shl 8);
end;

function IfThen(const val: boolean; const iftrue, iffalse: ansistring): ansistring;
  overload;
begin
  if val then
    Result := iftrue
  else
    Result := iffalse;
end;

function MoveRect(const Rectangle: TRect; const MoveVector: TPoint): TRect;
begin
  Result.Left := Rectangle.Left + MoveVector.X;
  Result.Top := Rectangle.Top + MoveVector.Y;
  Result.Right := Rectangle.Right + MoveVector.X;
  Result.Bottom := Rectangle.Bottom + MoveVector.Y;
end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Randomize;
  RefreshDeviceList;
  SamplePhoto := TBitmap.Create;
  ToBeFreed := TStringList.Create;
  LoadConfigFromFile(ConfigFile);
end;

procedure TMainForm.AddAreaBtnClick(Sender: TObject);
var
  c: integer;
begin
  c := Length(Selections);
  SetLength(Selections, c + 1);
  Selections[c] := TSelectedRect.Create(Self, c, SamplePhoto.Canvas.ClipRect);
  Selections[c].OnChange := @ForceRepaint;
  Selections[c].OnClickRemove := @RemoveItem;
  ScrollBox2.InsertControl(Selections[c]);
  if c = 0 then
    Selections[c].SelectedRectangle :=
      Rect(SamplePhoto.Width div 2 - 16, SamplePhoto.Height div 2 - 16,
      SamplePhoto.Width div 2 + 16, SamplePhoto.Height div 2 + 16)
  else
    Selections[c].SelectedRectangle :=
      MoveRect(Selections[c - 1].SelectedRectangle, Point(10, 10));
  PaintBox1.Repaint;
end;

procedure TMainForm.ArrowClick(Sender: TObject);
begin
  if (Sender is TArrow) then
    case (Sender as TArrow).ArrowType of
      atDown: MoveSelections(Point(0, 1));
      atUp: MoveSelections(Point(0, -1));
      atRight: MoveSelections(Point(1, 0));
      atLeft: MoveSelections(Point(-1, 0));
    end;
  PaintBox1.Repaint;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
var
  i: integer;
begin
  SaveConfigToFile(ConfigFile);
  SamplePhoto.Free;
  for i := 0 to Length(Selections) - 1 do
    Selections[i].Free;
  Timer1Timer(Self);
  ToBeFreed.Free;
end;

procedure TMainForm.FormPaint(Sender: TObject);
var
  i: integer;
begin
  for i := 0 to Length(Selections) - 1 do
    Selections[i].Repaint;
end;

procedure TMainForm.PaintBox1Paint(Sender: TObject);
var
  i: integer;
begin
  PaintBox1.Canvas.Draw(0, 0, SamplePhoto);
  PaintBox1.Canvas.Pen.Color := clRed;
  PaintBox1.Canvas.Pen.Style := psDash;
  PaintBox1.Canvas.Brush.Style := bsClear;
  PaintBox1.Canvas.Font.Color := clRed;
  for i := 0 to Length(Selections) - 1 do
  begin
    PaintBox1.Canvas.TextOut(Selections[i].SelectedRectangle.Left,
      Selections[i].SelectedRectangle.Top,
      Selections[i].Caption);
    PaintBox1.Canvas.Rectangle(Selections[i].SelectedRectangle);
  end;
end;

procedure TMainForm.RefreshDeviceListBtnClick(Sender: TObject);
begin
  RefreshDeviceList;
end;

procedure TMainForm.SaveAsBtnClick(Sender: TObject);
begin
  SaveSelectionsAs;
end;

procedure TMainForm.TakePhotoBtnClick(Sender: TObject);
var
  Device: ansistring;
  i, x, y: integer;
begin
  i := DeviceSelector.ItemIndex;
  if i < 0 then
    Exit;

  if not FileExists(DeviceSelector.Items[i]) then
    Exit;

  Device := DeviceSelector.Items[i];

  x := XResolutionSpinEdit.Value;
  y := YResolutionSpinEdit.Value;
  if not TakePhoto(Device, x, y) then
    ShowMessage('Cannot take a photo');
end;

procedure TMainForm.Timer1Timer(Sender: TObject);
var
  i: integer;
  o: TObject;
begin
  for i := 0 to ToBeFreed.Count - 1 do
  begin
    o := ToBeFreed.Objects[i];
    o.Free;
  end;
  ToBeFreed.Clear;
end;

procedure TMainForm.ForceRepaint(Sender: TObject);
begin
  Repaint;
end;

procedure TMainForm.RemoveItem(Item: TObject);
var
  i, c: integer;
begin
  c := Length(Selections);
  i := 0;
  while (i < c) do
    if Selections[i] = Item then
    begin
      Dec(c);
      Selections[i].Index := c;
      Selections[i].Visible := False;
      ToBeFreed.AddObject(IntToStr(i), Selections[i]);
      Selections[i] := Selections[c];
    end
    else
      Inc(i);
  SetLength(Selections, c);
  UpdateSelectionIndex;
end;

procedure TMainForm.SaveSelectionToFile(Selection: TSelectedRect;
  const FileName: ansistring);
var
  bmp: TBitmap;
  w, h: integer;
begin
  w := Selection.SelectedRectangle.Right - Selection.SelectedRectangle.Left;
  h := Selection.SelectedRectangle.Bottom - Selection.SelectedRectangle.Top;
  bmp := TBitmap.Create;
  bmp.SetSize(w, h);
  bmp.Canvas.CopyRect(Rect(0, 0, w, h), SamplePhoto.Canvas,
    Selection.SelectedRectangle);
  bmp.SaveToFile(FileName);
  bmp.Free;
end;

procedure TMainForm.SaveSelectionAs(const Index: integer);
begin
  try
    Enabled:=False;
    if (Index >= 0) and (Index < Length(Selections)) then
      case TSaveSampleDialog.Execute(Format('Do you want to save probe %d as for rejected?', [Index]), [mbYes, mbNo, mbCancel], SamplePhoto.Canvas, Selections[Index].SelectedRectangle) of
        mrYes: SaveSelectionAs(Index, True);
        mrNo: SaveSelectionAs(Index, False);
      end;           
  finally
    Enabled:=True;
  end;
end;

procedure TMainForm.SaveSelectionAs(const Index: integer; const Verdict: boolean);
begin
  if (Index >= 0) and (Index < Length(Selections)) then
    SaveSelectionToFile(Selections[Index], IfThen(Verdict, ConfigTruePath,
      ConfigFalsePath) + IntToStr(GetTickCount64) + IntToStr(Random($FFFFFFFF)) + '.bmp');
end;

procedure TMainForm.SaveSelectionsAs(const Verdict: boolean; const FirstIndex: integer);
var
  i: integer;
begin
  for i := FirstIndex to High(Selections) do
    SaveSelectionAs(i, Verdict);
end;

procedure TMainForm.SaveSelectionsAs;
var
  i: integer;
begin
  try
    Enabled:=False;
    for i := 0 to High(Selections) do
      case TSaveSampleDialog.Execute(Format('Do you want to save probe %d as for rejected?', [i]),[mbYes, mbNo, mbYesToAll, mbNoToAll, mbCancel], SamplePhoto.Canvas, Selections[i].SelectedRectangle) of
        mrYes: SaveSelectionAs(i, True);
        mrNo: SaveSelectionAs(i, False);
        mrYesToAll:
        begin
          SaveSelectionsAs(True, i);
          break;
        end;
        mrNoToAll:
        begin
          SaveSelectionsAs(False, i);
          break;
        end;
        mrCancel: Break;
      end;
  finally
    Enabled := True;
  end;
end;

procedure TMainForm.SaveConfigToFile(const FileName: ansistring);
var
  ConfigFile: TIniFile;
  i, c, w, h: integer;
  r: TRect;
  SectionName: ansistring;
begin
  ConfigFile := TIniFile.Create(FileName);
  c := Length(Selections);
  ConfigFile.WriteInteger('Global', 'DetectAreaCount', c);
  SamplePhoto.SaveToFile(ExtractFilePath(FileName) + 'Sample.bmp');
  w := SamplePhoto.Width;
  h := SamplePhoto.Height;
  ConfigFile.WriteInteger('Global', 'Width', w);
  ConfigFile.WriteInteger('Global', 'Height', h);
  for i := 0 to c - 1 do
  begin
    r := Selections[i].SelectedRectangle;
    SectionName := 'DetectArea' + IntToStr(i);
    ConfigFile.WriteFloat(SectionName, 'Left', r.Left / w);
    ConfigFile.WriteFloat(SectionName, 'Top', r.Top / h);
    ConfigFile.WriteFloat(SectionName, 'Right', r.Right / w);
    ConfigFile.WriteFloat(SectionName, 'Bottom', r.Bottom / h);
  end;
  ConfigFile.Free;
end;

procedure TMainForm.LoadConfigFromFile(const FileName: ansistring);
var
  ConfigFile: TIniFile;
  i, c, w, h: integer;
  SectionName: ansistring;
begin
  ConfigFile := TIniFile.Create(FileName);
  c := ConfigFile.ReadInteger('Global', 'DetectAreaCount', 0);
  if FileExists(ExtractFilePath(FileName) + 'Sample.bmp') then
  begin
    SamplePhoto.LoadFromFile(ExtractFilePath(FileName) + 'Sample.bmp');
    PaintBox1.SetBounds(0, 0, SamplePhoto.Width, SamplePhoto.Height);
    PaintBox1.Repaint;
  end;
  w := SamplePhoto.Width;
  h := SamplePhoto.Height;
  w := ConfigFile.ReadInteger('Global', 'Width', w);
  h := ConfigFile.ReadInteger('Global', 'Height', h);
  for i := 0 to c - 1 do
  begin
    AddAreaBtnClick(Self);
    SectionName := 'DetectArea' + IntToStr(i);
    Selections[i].SelectedRectangle :=
      Rect(Round(ConfigFile.ReadFloat(SectionName, 'Left', 0) * w),
      Round(
      ConfigFile.ReadFloat(SectionName, 'Top', 0) * h),
      Round(
      ConfigFile.ReadFloat(SectionName, 'Right', 0) * w),
      Round(
      ConfigFile.ReadFloat(SectionName, 'Bottom', 0) * h));
  end;
  ConfigFile.Free;
end;

procedure TMainForm.UpdateSelectionIndex;
var
  i: integer;
begin
  for i := 0 to Length(Selections) - 1 do
    Selections[i].Index := i;
end;

function TMainForm.TakePhoto(const Device: ansistring;
  const AWidth, AHeight: integer): boolean;
var
  Camera: TYUV2Camera;
  i, x, y: integer;
  t1, t2: QWord;
begin
  try
    try
      Camera := TYUV2Camera.Create(AWidth, AHeight, Device);

      Camera.Open;

      for i := 1 to 50 do
        Camera.GetNextFrame;
      t1 := GetTickCount64;
      for i := 1 to 50 do
        Camera.GetNextFrame;
      t2 := GetTickCount64;

      writeln(stdErr, 50 * 1000 / (t2 - t1): 2: 2, 'fps');

      SamplePhoto.SetSize(AWidth, AHeight);
      for x := 0 to AWidth - 1 do
        for y := 0 to AHeight - 1 do
          SamplePhoto.Canvas.Pixels[x, y] := FPColorToLongWord(Camera.GetColor(x, y));

      Camera.Close;

    finally
      Camera.Free;
    end;
  except
    Exit(False);
  end;

  PaintBox1.SetBounds(0, 0, SamplePhoto.Width, SamplePhoto.Height);
  PaintBox1.Repaint;
  Result := True;
end;

procedure TMainForm.MoveSelections(const MoveVector: TPoint);
var
  i : Integer;
begin
  for i := 0 to Length(Selections)-1 do
      Selections[i].SelectedRectangle := MoveRect(Selections[i].SelectedRectangle, MoveVector);
end;

procedure TMainForm.RefreshDeviceList;
var
  i: integer;
  List: TStringList;
begin
  List := TStringList.Create;
  for i := 0 to 9 do
    if FileExists('/dev/video' + IntToStr(i)) then
      List.Add('/dev/video' + IntToStr(i));
  i := DeviceSelector.ItemIndex;
  DeviceSelector.Items.Assign(List);
  if List.Count > 0 then
    DeviceSelector.ItemIndex := EnsureRange(i, 0, List.Count - 1);
  List.Free;
end;

initialization
  ConfigPath := StringReplace(ConfigPath, '~/', GetUserDir, []);
  ConfigFile := StringReplace(ConfigFile, '~/', GetUserDir, []);
  ConfigTruePath := StringReplace(ConfigTruePath, '~/', GetUserDir, []);
  ConfigFalsePath := StringReplace(ConfigFalsePath, '~/', GetUserDir, []);
  CreateDir(ConfigPath);
  CreateDir(ConfigTruePath);
  CreateDir(ConfigFalsePath);

end.
