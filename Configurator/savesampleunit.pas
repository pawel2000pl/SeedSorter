unit SaveSampleUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls;

type

  TSaveSampleDialogButtons = TMsgDlgButtons;// set of (mbYes, mbNo, mbYesToAll, mbNoToAll, mbCancel);

  { TSaveSampleDialog }

  TSaveSampleDialog = class(TForm)
    Label1: TLabel;
    YesBtn: TButton;
    NoBtn: TButton;
    CancelBtn: TButton;
    YesToAllBtn: TButton;
    NoToAllBtn: TButton;
    Image1: TImage;
    procedure CancelBtnClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure NoBtnClick(Sender: TObject);
    procedure NoToAllBtnClick(Sender: TObject);
    procedure YesBtnClick(Sender: TObject);
    procedure YesToAllBtnClick(Sender: TObject);
  private
    FExecuteResult : TModalResult;
  public
    property ExecuteResult : TModalResult read FExecuteResult;
    procedure AssignVisibleButtons(Buttons : TSaveSampleDialogButtons);

    class function Execute(const Message : AnsiString; const Buttons : TSaveSampleDialogButtons; const Image : TCanvas; const SelectedRect : TRect) : TModalResult; overload;
    class function Execute(const Message : AnsiString; const Buttons : TSaveSampleDialogButtons; const Image : TCanvas) : TModalResult; overload;
  end;

implementation

{$R *.lfm}

{ TSaveSampleDialog }

procedure TSaveSampleDialog.FormCreate(Sender: TObject);
begin
  Constraints.MaxWidth:=Width;
  Constraints.MinWidth:=Width;
  Constraints.MaxHeight:=Height;
  Constraints.MinHeight:=Height;
  Caption:='';
  FExecuteResult := mrNone;
end;

procedure TSaveSampleDialog.CancelBtnClick(Sender: TObject);
begin
  FExecuteResult:=mrCancel;
end;

procedure TSaveSampleDialog.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  FExecuteResult:=mrCancel;
end;

procedure TSaveSampleDialog.NoBtnClick(Sender: TObject);
begin
  FExecuteResult:=mrNo;
end;

procedure TSaveSampleDialog.NoToAllBtnClick(Sender: TObject);
begin
  FExecuteResult:=mrNoToAll;
end;

procedure TSaveSampleDialog.YesBtnClick(Sender: TObject);
begin
  FExecuteResult:=mrYes;
end;

procedure TSaveSampleDialog.YesToAllBtnClick(Sender: TObject);
begin
  FExecuteResult:=mrYesToAll;
end;

procedure TSaveSampleDialog.AssignVisibleButtons(
  Buttons: TSaveSampleDialogButtons);
begin
  YesBtn.Visible:=mbYes in Buttons;
  NoBtn.Visible:=mbNo in Buttons;
  YesToAllBtn.Visible:=mbYesToAll in Buttons;
  NoToAllBtn.Visible:=mbNoToAll in Buttons;
  CancelBtn.Visible:=mbCancel in Buttons;
end;

class function TSaveSampleDialog.Execute(const Message: AnsiString;
  const Buttons: TSaveSampleDialogButtons; const Image: TCanvas;
  const SelectedRect: TRect): TModalResult;
var
  Form : TSaveSampleDialog;
begin
  Form := TSaveSampleDialog.Create(Application);
  Form.Label1.Caption:=Message;
  Form.AssignVisibleButtons(Buttons);
  Form.Image1.Canvas.CopyRect(Rect(0, 0, Form.Image1.Width-1, Form.Image1.Height-1), Image, SelectedRect);
  Form.Show;

  while Form.ExecuteResult = mrNone do
    Application.ProcessMessages;

  Result := Form.ExecuteResult;
  Form.Free;
end;

class function TSaveSampleDialog.Execute(const Message: AnsiString;
  const Buttons: TSaveSampleDialogButtons; const Image: TCanvas): TModalResult;
begin
     Result := Execute(Message, Buttons, Image, Rect(0, 0, Image.Width-1, Image.Height-1));
end;

end.

