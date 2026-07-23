{
  autoPatchelfHook,
  fetchurl,
  lib,
  nixosTests,
  stdenv,
}:

let
  systemToArch = {
    i686-linux = "386";
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
    armv7l-linux = "arm";
    aarch64-darwin = "arm64";
  };

  arch =
    systemToArch.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  os =
    if stdenv.hostPlatform.isLinux then
      "linux"
    else if stdenv.hostPlatform.isDarwin then
      "darwin"
    else
      throw "Unsupported OS";

  hash =
    {
      hash_386-linux = "sha256-eR5yPDwjbjCsm6/ynI/xCCyzlQUMXSlc7xPebNWQxZ8=";
      hash_amd64-linux = "sha256-MOLyuhslnKJlCbCgm+bAg/K1pFk8Q8miREOuap3egBQ=";
      hash_arm64-linux = "sha256-P1oZI7oGyQ8JmeXdBbG5WHqdXbR9zwPvHmmkiV0ajH8=";
      hash_arm-linux = "sha256-RhXkCzT8fb5/au+nJLsHRYSgLpXwFzhx2vayR/P4cfg=";
      hash_arm64-darwin = "sha256-s+Lv2OBrlRCTu4K89rJeirudzXrGBdjqKA2WBTwioUE=";
    }
    ."hash_${arch}-${os}";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ocis_70-bin";
  version = "7.0.1";

  src = fetchurl {
    url = "https://github.com/owncloud/ocis/releases/download/v${finalAttrs.version}/ocis-${finalAttrs.version}-${os}-${arch}";
    inherit hash;
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    install -D $src $out/bin/ocis
    runHook postInstall
  '';

  passthru = {
    tests.ocis = nixosTests.ocis.${finalAttrs.pname};
    updateScript = [
      ./update.py
      finalAttrs.pname
    ];
  };

  meta = {
    description = "ownCloud Infinite Scale Stack";
    homepage = "https://owncloud.dev/ocis/";
    changelog = "https://github.com/owncloud/ocis/releases/tag/v${finalAttrs.version}";
    # oCIS is licensed under a non-free EULA:
    # https://github.com/owncloud/ocis/releases/download/v5.0.1/End-User-License-Agreement-for-ownCloud-Infinite-Scale.pdf
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ ramblurr ];
    platforms = builtins.attrNames systemToArch;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "ocis";
  };
})
