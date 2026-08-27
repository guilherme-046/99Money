unit u99Permissions;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Actions, System.Messaging, System.Permissions,
  FMX.DialogService, FMX.MediaLibrary.Actions, FMX.Media, FMX.ActnList,
  {$IFDEF ANDROID}
  Androidapi.Helpers,
  Androidapi.JNI.JavaTypes,
  Androidapi.JNI.Os,
  {$ENDIF}
  System.TypInfo;

type
  TCallbackProc = procedure(Sender: TObject) of Object;

  T99Permissions = class
  private
    CurrentRequest : string;
    pCamera, pReadStorage, pWriteStorage : string;
    pFineLocation, pCoarseLocation : string;

    procedure PermissionRequestResult(Sender: TObject;
      const APermissions: TClassicStringDynArray;
      const AGrantResults: TClassicPermissionStatusDynArray);

    procedure DisplayRationale(Sender: TObject;
      const APermissions: TClassicStringDynArray;
      const APostRationaleProc: TProc);

  public
    MyCallBack, MyCallBackError : TCallbackProc;
    MyCameraAction : TTakePhotoFromCameraAction;
    MyLibraryAction : TTakePhotoFromLibraryAction;

    constructor Create;
    procedure Camera(ActionPhoto: TTakePhotoFromCameraAction;
      ACallBackError: TCallbackProc = nil);
    procedure PhotoLibrary(ActionLibrary: TTakePhotoFromLibraryAction;
      ACallBackError: TCallbackProc = nil);
    procedure Location(ACallBack: TCallbackProc = nil;
      ACallBackError: TCallbackProc = nil);
  end;

implementation

constructor T99Permissions.Create;
begin
  {$IFDEF ANDROID}
  // Permissões padrão
  pCamera := JStringToString(TJManifest_permission.JavaClass.CAMERA);
  pWriteStorage := JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE);
  pCoarseLocation := JStringToString(TJManifest_permission.JavaClass.ACCESS_COARSE_LOCATION);
  pFineLocation := JStringToString(TJManifest_permission.JavaClass.ACCESS_FINE_LOCATION);

  // AJUSTE PARA ANDROID 13+ (API 33)
  if TOSVersion.Check(13) then
    pReadStorage := 'android.permission.READ_MEDIA_IMAGES'
  else
    pReadStorage := JStringToString(TJManifest_permission.JavaClass.READ_EXTERNAL_STORAGE);
  {$ENDIF}
end;

procedure T99Permissions.PermissionRequestResult(Sender: TObject;
  const APermissions: TClassicStringDynArray;
  const AGrantResults: TClassicPermissionStatusDynArray);
var
  LResult: Boolean;
begin
  LResult := False;

  // Verificamos se houve resposta e se o primeiro item (o principal) foi aceito
  if (Length(AGrantResults) > 0) and (AGrantResults[0] = TPermissionStatus.Granted) then
  begin
    if CurrentRequest = 'CAMERA' then
    begin
      LResult := True;
      if Assigned(MyCameraAction) then MyCameraAction.Execute;
    end
    else if CurrentRequest = 'LIBRARY' then
    begin
      LResult := True;
      if Assigned(MyLibraryAction) then MyLibraryAction.Execute;
    end
    else if CurrentRequest = 'LOCATION' then
    begin
      LResult := True;
      if Assigned(MyCallBack) then MyCallBack(Self);
    end;
  end;

  // Se falhou ou foi negado
  if not LResult then
  begin
    if Assigned(MyCallBackError) then
      MyCallBackError(Self);
  end;
end;

procedure T99Permissions.Camera(ActionPhoto: TTakePhotoFromCameraAction;
  ACallBackError: TCallbackProc = nil);
begin
  MyCameraAction := ActionPhoto;
  MyCallBackError := ACallBackError;
  CurrentRequest := 'CAMERA';

  {$IFDEF ANDROID}
  // No Android moderno, pedimos a Câmera e o Storage de leitura.
  // O WriteStorage é ignorado no 13+, mas incluímos para compatibilidade com antigos.
  PermissionsService.RequestPermissions([pCamera, pReadStorage, pWriteStorage],
    PermissionRequestResult, DisplayRationale);
  {$ELSE}
  ActionPhoto.Execute;
  {$ENDIF}
end;

procedure T99Permissions.PhotoLibrary(ActionLibrary: TTakePhotoFromLibraryAction;
  ACallBackError: TCallbackProc = nil);
begin
  MyLibraryAction := ActionLibrary;
  MyCallBackError := ACallBackError;
  CurrentRequest := 'LIBRARY';

  {$IFDEF ANDROID}
  PermissionsService.RequestPermissions([pReadStorage],
    PermissionRequestResult, DisplayRationale);
  {$ELSE}                  io
  ActionLibrary.Execute;
  {$ENDIF}
end;

procedure T99Permissions.Location(ACallBack: TCallbackProc = nil;
  ACallBackError: TCallbackProc = nil);
begin
  MyCallBack := ACallBack;
  MyCallBackError := ACallBackError;
  CurrentRequest := 'LOCATION';

  {$IFDEF ANDROID}
  PermissionsService.RequestPermissions([pFineLocation, pCoarseLocation],
    PermissionRequestResult, DisplayRationale);
  {$ELSE}
  if Assigned(MyCallBack) then MyCallBack(Self);
  {$ENDIF}
end;

procedure T99Permissions.DisplayRationale(Sender: TObject;
  const APermissions: TClassicStringDynArray; const APostRationaleProc: TProc);
begin
  // Opcional: Mostrar mensagem explicando por que precisa da permissão antes de pedir
  APostRationaleProc;
end;

end.
