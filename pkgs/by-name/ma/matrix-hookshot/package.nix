{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchYarnDeps,
  makeWrapper,
  matrix-sdk-crypto-nodejs,
  mkYarnPackage,
  cargo,
  rustPlatform,
  rustc,
  napi-rs-cli,
  pkg-config,
  nodejs_22,
  openssl,
}:

let
  data = lib.importJSON ./pin.json;
in
mkYarnPackage rec {
  pname = "matrix-hookshot";
  version = data.version;

  src = fetchFromGitHub {
    owner = "matrix-org";
    repo = "matrix-hookshot";
    rev = data.version;
    hash = data.srcHash;
  };

  packageJSON = ./package.json;
  nodejs = nodejs_22;

  offlineCache = fetchYarnDeps {
    yarnLock = src + "/yarn.lock";
    sha256 = data.yarnHash;
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit pname version src;
    hash = data.cargoHash;
  };

  packageResolutions = {
    "@matrix-org/matrix-sdk-crypto-nodejs" =
      "${matrix-sdk-crypto-nodejs}/lib/node_modules/@matrix-org/matrix-sdk-crypto-nodejs";
  };

  extraBuildInputs = [ openssl ];

  nativeBuildInputs = [
    rustPlatform.cargoSetupHook
    pkg-config
    cargo
    rustc
    napi-rs-cli
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    cd deps/${pname}
    napi build --target ${stdenv.hostPlatform.rust.rustcTargetSpec} --dts ../src/libRs.d.ts --release ./lib
    yarn run build:app:fix-defs
    yarn run build:app
    yarn run build:web
    cd ../..
    runHook postBuild
  '';

  postInstall = ''
    makeWrapper '${nodejs_22}/bin/node' "$out/bin/matrix-hookshot" --add-flags \
        "$out/libexec/matrix-hookshot/deps/matrix-hookshot/lib/App/BridgeApp.js"
  '';

  postFixup = ''
    # Scrub reference to rustc
    rm $out/libexec/matrix-hookshot/deps/matrix-hookshot/target/.rustc_info.json
  '';

  doDist = false;

  meta = with lib; {
    description = "Bridge between Matrix and multiple project management services, such as GitHub, GitLab and JIRA";
    mainProgram = "matrix-hookshot";
    maintainers = with maintainers; [ chvp ];
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
