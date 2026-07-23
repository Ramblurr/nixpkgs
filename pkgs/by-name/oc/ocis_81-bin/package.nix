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
      hash_386-linux = "sha256-sPv7H3zMNj2rcP7hOnkakssdPshyVu91mxjhbja1oQ0=";
      hash_amd64-linux = "sha256-jhGTMZkegKZYQAiEwX5LX9irUuBzrhMzhlAKXVUD6yU=";
      hash_arm64-linux = "sha256-7wlOBm/xKCphRXFbVhlsQpNl03/oPHqZ6qkbz6VCA6U=";
      hash_arm-linux = "sha256-dhvr7mjgMbMqVpAhqAxUhNtGBYv+7JfJIA3F6r1URUs=";
      hash_arm64-darwin = "sha256-Nj+OjLwtn1cWwC/pAXMp/IpzvFiT6ASAZr7NMb39S8U=";
    }
    ."hash_${arch}-${os}";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ocis_81-bin";
  version = "8.1.0";

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
      ../ocis_70-bin/update.py
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
