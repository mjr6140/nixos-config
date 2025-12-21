{ pkgs }:

let
  pname = "qidi-studio";
  version = "2.03.01.70";
  
  src = pkgs.fetchurl {
    url = "https://github.com/QIDITECH/QIDIStudio/releases/download/v${version}/QIDIStudio_${version}_Ubuntu24.AppImage";
    sha256 = "1s5ykjwrjcm7mahpm8yrbdq5pfb4mm3c8lslw6yk0hcpwv0lc3v4";
  };

  appimageContents = pkgs.appimageTools.extract {
    inherit pname version src;
  };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: with pkgs; [
    webkitgtk_4_1
  ];

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/QIDIStudio.desktop $out/share/applications/QIDIStudio.desktop
    install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/192x192/apps/QIDIStudio.png \
      $out/share/icons/hicolor/192x192/apps/QIDIStudio.png
    substituteInPlace $out/share/applications/QIDIStudio.desktop \
      --replace 'Exec=AppRun' 'Exec=qidi-studio'
  '';
}
