{ alsa-lib
, autoconf
, automake
, libtool
, cmake
, copyDesktopItems
, curl
, glew
, zenity
, gtk3-x11
, imagemagick
, jansson
, jq
, lib
, libarchive
, libicns
, libjack2
, libpulseaudio
, libsamplerate
, makeDesktopItem
, makeWrapper
, pkg-config
, stdenv
, wrapGAppsHook3
, zstd
}:

let
  fundamental-source = builtins.fetchGit {
    url = "https://github.com/VCVRack/Fundamental.git";
    rev = "5ed79544161e0fa9a55faa7c0a5f299e828e12ab"; # tip of branch v2
    submodules = true;
  };
in
stdenv.mkDerivation rec {
  pname = "VCV-Rack";
  version = "2.5.1";

  desktopItems = [
    (makeDesktopItem {
      type = "Application";
      name = pname;
      desktopName = "VCV Rack";
      genericName = "Eurorack simulator";
      comment = "Create music by patching together virtual synthesizer modules";
      exec = "Rack";
      icon = "Rack";
      categories = [ "AudioVideo" "AudioVideoEditing" "Audio" ];
      keywords = [ "music" ];
    })
  ];

  src = builtins.fetchGit {
    url = "https://github.com/VCVRack/Rack.git";
    ref = "refs/tags/v${version}";
    rev = "3f133d8a0359b539bd262a4c3e1e6b4fb2ef83e6";
    submodules = true;
  };

  nativeBuildInputs = [
    cmake
    autoconf
    automake
    libtool
    copyDesktopItems
    imagemagick
    jq
    libicns
    makeWrapper
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    curl
    glew
    zenity
    gtk3-x11
    jansson
    libarchive
    libjack2
    libpulseaudio
    libsamplerate
    zstd
  ];

  prePatch = ''
    # Build and dist the Fundamental plugins
    cp -r ${fundamental-source} plugins/Fundamental/
    chmod -R +rw plugins/Fundamental # will be used as build dir
    substituteInPlace plugin.mk --replace ".DEFAULT_GOAL := all" ".DEFAULT_GOAL := dist"

    # Fix reference to zenity
    substituteInPlace dep/osdialog/osdialog_zenity.c \
      --replace 'zenityBin[] = "zenity"' 'zenityBin[] = "${zenity}/bin/zenity"'
  '';

  patches = [ ./rack-minimize-vendoring.patch ];

  configurePhase = '':'';

  makeFlags = lib.optionals (stdenv.buildPlatform != stdenv.hostPlatform) [
    "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
  ] ++ [
    "dep"
    "all"
    "plugins"
  ];

  installPhase = ''
    runHook preInstall

    install -D -m755 -t $out/bin Rack
    install -D -m755 -t $out/lib libRack.so

    mkdir -p $out/share/vcv-rack
    cp -r res cacert.pem Core.json template.vcv LICENSE-GPLv3.txt $out/share/vcv-rack
    cp -r plugins/Fundamental/dist/Fundamental-*.vcvplugin $out/share/vcv-rack/Fundamental.vcvplugin

    # Extract pngs from the Apple icon image and create
    # the missing ones from the 1024x1024 image.
    icns2png --extract icon.icns
    for size in 16 24 32 48 64 128 256 512 1024; do
      mkdir -pv $out/share/icons/hicolor/"$size"x"$size"/apps
      if [ ! -e icon_"$size"x"$size"x32.png ] ; then
        convert -resize "$size"x"$size" icon_1024x1024x32.png icon_"$size"x"$size"x32.png
      fi
      install -Dm644 icon_"$size"x"$size"x32.png $out/share/icons/hicolor/"$size"x"$size"/apps/Rack.png
    done;

    runHook postInstall
  '';

  dontWrapGApps = true;

  postFixup = ''
    # Wrap gApp and override the default global resource file directory
    wrapProgram $out/bin/Rack \
        "''${gappsWrapperArgs[@]}" \
        --add-flags "-s $out/share/vcv-rack"
  '';

  meta = with lib; {
    description = "Open-source virtual modular synthesizer";
    homepage = "https://vcvrack.com/";
    # The source is GPL3+ licensed, some of the art is CC-BY-NC 4.0 or under a
    # no-derivatives clause
    license = with licenses; [ gpl3Plus cc-by-nc-40 unfreeRedistributable ];
    maintainers = with maintainers; [ nathyong jpotier ddelabru ];
    mainProgram = "Rack";
    platforms = platforms.linux;
  };
}
