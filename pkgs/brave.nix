{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  buildPackages,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  gtk4,
  libX11,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXrandr,
  libXrender,
  libXScrnSaver,
  libXtst,
  libdrm,
  libgbm,
  libuuid,
  libxcb,
  libxkbcommon,
  libxshmfence,
  nspr,
  nss,
  pango,
  pipewire,
  udev,
  wayland,
  xdg-utils,
  coreutils,
  zlib,
  snappy,
  libkrb5,
  qt6,
  pulseSupport ? stdenv.hostPlatform.isLinux,
  libpulseaudio,
  libGL,
  vulkanSupport ? true,
  addDriverRunpath,
  pname,
  version,
  hash,
  url,
  commandLineArgs ? "",
}:

let
  deps = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    gtk4
    libdrm
    libX11
    libGL
    libxkbcommon
    libXScrnSaver
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libxshmfence
    libXtst
    libuuid
    libgbm
    nspr
    nss
    pango
    pipewire
    udev
    wayland
    libxcb
    zlib
    snappy
    libkrb5
    qt6.qtbase
  ]
  ++ lib.optional pulseSupport libpulseaudio;

  rpath = lib.makeLibraryPath deps + ":" + lib.makeSearchPathOutput "lib" "lib64" deps;
  binpath = lib.makeBinPath [
    xdg-utils
    coreutils
  ];

in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl { inherit url hash; };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;

  nativeBuildInputs = [
    dpkg
    (buildPackages.wrapGAppsHook3.override { makeWrapper = buildPackages.makeShellWrapper; })
  ];

  buildInputs = [
    glib
    gtk3
    gtk4
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    dpkg --fsys-tarfile $src | tar --extract --no-same-owner --no-same-permissions -C $out

    # Move share to output
    mv $out/usr/share $out/share || true
    rm -rf $out/usr

    # Find the installation directory
    TARGET_OPT=$(find $out/opt/brave.com -mindepth 1 -maxdepth 1 -type d | head -n 1)
    EXE_NAME=$(basename $TARGET_OPT)

    mkdir -p $out/bin

    # Replace absolute shell path
    substituteInPlace $TARGET_OPT/$EXE_NAME \
      --replace-fail /bin/bash ${stdenv.shell} \
      --replace-fail 'CHROME_WRAPPER' 'WRAPPER'

    # Link main executable
    ln -sf $TARGET_OPT/$EXE_NAME $out/bin/$EXE_NAME
    # Alias to pname if different
    if [ "$EXE_NAME" != "${pname}" ]; then
      ln -sf $out/bin/$EXE_NAME $out/bin/${pname}
    fi

    for binary in $TARGET_OPT/{$EXE_NAME,brave,chrome_crashpad_handler}; do
      if [ -f "$binary" ]; then
        if patchelf --print-interpreter "$binary" >/dev/null 2>&1 || patchelf --print-rpath "$binary" >/dev/null 2>&1; then
          patchelf \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
            --set-rpath "${rpath}" "$binary" || true
        fi
      fi
    done

    # Fix desktop files
    find $out/share/applications -name "*.desktop" -exec sed -i "s|/usr/bin/[a-zA-Z0-9-]*|$out/bin/${pname}|g" {} +

    ln -sf ${xdg-utils}/bin/xdg-settings $TARGET_OPT/xdg-settings
    ln -sf ${xdg-utils}/bin/xdg-mime $TARGET_OPT/xdg-mime

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : ${rpath}
      --prefix PATH : ${binpath}
      --set CHROME_WRAPPER "${pname}"
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
      ${lib.optionalString vulkanSupport "--prefix XDG_DATA_DIRS : \"${addDriverRunpath.driverLink}/share\""}
      --add-flags ${lib.escapeShellArg commandLineArgs}
    )
  '';

  meta = with lib; {
    homepage = "https://brave.com/";
    description = "Privacy-oriented browser - ${pname}";
    license = licenses.mpl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = pname;
  };
}
