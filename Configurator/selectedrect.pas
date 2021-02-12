unit SelectedRect;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Forms, StdCtrls, Spin;

type

  { TSelectedRect }

  TSelectedRect = class(TGroupBox)
  private
    FOnChange : TNotifyEvent;
    FOnClickRemove : TNotifyEvent;
    FRect : TRect;
    FMaxArea : TRect;
    FIndex : integer;
    FUpdating : Boolean;

    PositionXSpinEdit : TSpinEdit;
    PositionYSpinEdit : TSpinEdit;
    SizeWidthSpinEdit : TSpinEdit;
    SizeHeightSpinEdit : TSpinEdit;
    RemoveBtn : TButton;
    procedure InitSubComponents;
    procedure InitVariables;
    procedure SetIndex(AValue : integer);
    procedure SetMaxArea(AValue : TRect);
    procedure OnChangeEvent(Sender : TObject);
    procedure SetOnChange(AValue : TNotifyEvent);
    procedure SetOnClickRemove(AValue : TNotifyEvent);
    procedure RemoveEvent(Sender : TObject);
    procedure SetSelectedRectangle(AValue: TRect);
  public
    procedure Repaint; override;
    property Index : integer read FIndex write SetIndex;
    property SelectedRectangle : TRect read FRect write SetSelectedRectangle;
    property MaxArea : TRect read FMaxArea write SetMaxArea;
    property OnChange : TNotifyEvent read FOnChange write SetOnChange;
    property OnClickRemove : TNotifyEvent read FOnClickRemove write SetOnClickRemove;

    procedure UpdateTopPosition;
    constructor Create(AOwner : TComponent; const AnIndex : integer; const AMaxArea : TRect);
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
  end;

implementation

{ TSelectedRect }

procedure TSelectedRect.SetIndex(AValue : integer);
begin
  if FIndex = AValue then
    Exit;
  FIndex := AValue;
  UpdateTopPosition;
  Caption := 'Area ' + IntToStr(FIndex);
end;

procedure TSelectedRect.InitSubComponents;
begin
  PositionXSpinEdit := TSpinEdit.Create(Self);
  PositionYSpinEdit := TSpinEdit.Create(Self);
  SizeWidthSpinEdit := TSpinEdit.Create(Self);
  SizeHeightSpinEdit := TSpinEdit.Create(Self);
  RemoveBtn := TButton.Create(Self);

  PositionXSpinEdit.SetBounds(8, 8, 64, 28);
  PositionYSpinEdit.SetBounds(80, 8, 64, 28);
  SizeWidthSpinEdit.SetBounds(8, 42, 64, 28);
  SizeHeightSpinEdit.SetBounds(80, 42, 64, 28);
  RemoveBtn.SetBounds(8, 78, 75, 25);
  RemoveBtn.Caption := 'Remove';
  RemoveBtn.OnClick:=@RemoveEvent;

  PositionXSpinEdit.OnChange := @OnChangeEvent;
  PositionYSpinEdit.OnChange := @OnChangeEvent;
  SizeWidthSpinEdit.OnChange := @OnChangeEvent;
  SizeHeightSpinEdit.OnChange := @OnChangeEvent;

  Width := 152;
  Height := 128;

  InsertControl(PositionXSpinEdit);
  InsertControl(PositionYSpinEdit);
  InsertControl(SizeWidthSpinEdit);
  InsertControl(SizeHeightSpinEdit);
  InsertControl(RemoveBtn);
end;

procedure TSelectedRect.InitVariables;
begin
  FIndex := 0;
  FOnChange := nil;
  FOnClickRemove := nil;
  FMaxArea := Rect(0, 0, 1, 1);
  FRect := Rect(0, 0, 1, 1);
  Caption := 'Area ' + IntToStr(FIndex);
end;

procedure TSelectedRect.SetMaxArea(AValue : TRect);
begin
  if FMaxArea = AValue then
    Exit;
  FMaxArea := AValue;

  PositionXSpinEdit.MinValue := FMaxArea.Left;
  PositionXSpinEdit.MaxValue := FMaxArea.Right;
  PositionYSpinEdit.MinValue := FMaxArea.Top;
  PositionYSpinEdit.MaxValue := FMaxArea.Bottom;
  SizeWidthSpinEdit.MinValue := FMaxArea.Left;
  SizeWidthSpinEdit.MaxValue := FMaxArea.Right;
  SizeHeightSpinEdit.MinValue := FMaxArea.Top;
  SizeHeightSpinEdit.MaxValue := FMaxArea.Bottom;
end;

procedure TSelectedRect.OnChangeEvent(Sender : TObject);
begin
  if FUpdating then
    Exit;
  FRect.TopLeft := Point(PositionXSpinEdit.Value, PositionYSpinEdit.Value);
  FRect.BottomRight := Point(FRect.Left + SizeWidthSpinEdit.Value, FRect.Top + SizeHeightSpinEdit.Value);
  if FOnChange <> nil then
    FOnChange(Self);
end;

procedure TSelectedRect.SetOnChange(AValue : TNotifyEvent);
begin
  if FOnChange = AValue then
    Exit;
  FOnChange := AValue;
end;

procedure TSelectedRect.SetOnClickRemove(AValue : TNotifyEvent);
begin
  if FOnClickRemove = AValue then
    Exit;
  FOnClickRemove := AValue;
end;

procedure TSelectedRect.RemoveEvent(Sender: TObject);
begin
  if FOnClickRemove <> nil then
    FOnClickRemove(Self);
end;

procedure TSelectedRect.SetSelectedRectangle(AValue: TRect);
begin
  if FRect=AValue then Exit;
  FRect:=AValue;
  FUpdating := True;
  PositionXSpinEdit.Value:=FRect.Left;
  PositionYSpinEdit.Value:=FRect.Top;
  SizeWidthSpinEdit.Value:=FRect.Right - FRect.Left;
  SizeHeightSpinEdit.Value:=FRect.Bottom - FRect.Top;
  FUpdating := False;
end;

procedure TSelectedRect.Repaint;
begin
  inherited Repaint;
  PositionXSpinEdit.Repaint;
  PositionYSpinEdit.Repaint;
  SizeWidthSpinEdit.Repaint;
  SizeHeightSpinEdit.Repaint;
  RemoveBtn.Repaint;
end;

procedure TSelectedRect.UpdateTopPosition;
begin
  Top := FIndex * (Height + 8);
end;

constructor TSelectedRect.Create(AOwner : TComponent; const AnIndex : integer; const AMaxArea : TRect);
begin
  inherited Create(AOwner);  
  InitVariables;
  InitSubComponents;
  SetIndex(AnIndex);
  SetMaxArea(AMaxArea);
end;

constructor TSelectedRect.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FUpdating := False;
  InitVariables;
  InitSubComponents;
end;

destructor TSelectedRect.Destroy;
begin
  PositionXSpinEdit.Free;
  PositionYSpinEdit.Free;
  SizeWidthSpinEdit.Free;
  SizeHeightSpinEdit.Free;
  RemoveBtn.Free;
  inherited Destroy;
end;

end.
