{
  lib,
  fetchFromGitHub,
  pkg-config,
  flutter,
  nix-update-script,
  makeWrapper,
}:

flutter.buildFlutterApplication rec {
  pname = "invoiceninja-desktop";
  version = "5.0.156";

  src = fetchFromGitHub {
    owner = "invoiceninja";
    repo = "admin-portal";
    rev = "v${version}";
    hash = "sha256-xZJSStEV+ZXErMmnmu9mA1sKdSvixbez/hLdQ4N3OJc=";
  };

  sourceRoot = "${src.name}";

  #cmakeFlags = [ "-DMIMALLOC_LIB=${mimalloc}/lib/mimalloc.o" ];

  # curl https://github.com/invoiceninja/admin-portal/raw/v5.0.156/pubspec.lock | yq > ./pubspec.lock.json
  pubspecLock = lib.importJSON ./pubspec.lock.json;
  gitHashes = {
    attributed_text = "sha256-4Kim4kGS0fNcPZqFjJ7fPS1BBDEpHQduGIyhCoXi3k0=";
    boardview = "sha256-+RYN9nHIGtaQxfLoO6HeBeWfHBag+aS+LEksUQuBoqQ=";
    qr_flutter = "sha256-QkPbX15YPjrfvTjFoCjFXCFBpsrabDC2AcZ8u+eVMLk=";
    super_editor = "sha256-4Kim4kGS0fNcPZqFjJ7fPS1BBDEpHQduGIyhCoXi3k0=";
    super_editor_markdown = "sha256-4Kim4kGS0fNcPZqFjJ7fPS1BBDEpHQduGIyhCoXi3k0=";
    super_text_layout = "sha256-4Kim4kGS0fNcPZqFjJ7fPS1BBDEpHQduGIyhCoXi3k0=";
  };

  nativeBuildInputs = [
    makeWrapper
    #  mimalloc
    #  pkg-config
  ];

  #buildInputs = [
  #  mpv-unwrapped
  #  gst_all_1.gst-libav
  #  gst_all_1.gst-plugins-base
  #  gst_all_1.gst-vaapi
  #  gst_all_1.gstreamer
  #  libunwind
  #  orc
  #  mimalloc
  #] ++ mpv-unwrapped.buildInputs ++ libplacebo.buildInputs;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "A framework that enables you to easily build realtime web, mobile, and desktop apps in Python. The frontend part";
    homepage = "https://flet.dev/";
    changelog = "https://github.com/flet-dev/flet/releases/tag/v${version}";
    license = lib.licenses.asl20;
    maintainers = [ lib.maintainers.ramblurr ];
    #mainProgram = "flet";
  };
}
