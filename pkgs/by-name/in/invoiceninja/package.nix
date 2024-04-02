{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
  php82,
  dataDir ? "/var/lib/invoiceninja",
  runtimeDir ? "/run/invoiceninja",
}:

let
  # NOTE to maintainers:
  #   this package contains two deriviations invoiceninja (the main one) and invoiceninja-ui (an inner one)
  #   when updating make sure to update both (if necessary)
  invoiceninja-ui = buildNpmPackage rec {
    pname = "invoiceninja-ui";
    version = "02.04.2024.1";

    src = fetchFromGitHub {
      owner = "invoiceninja";
      repo = "ui";
      rev = version;
      hash = "sha256-RjdQJ2QpFh0QzS1WiyjEOi/yl+BUwGqk/UA9lELWz5k=";
    };

    npmDepsHash = "sha256-SW5QbOT0jJrxx81GKI6/kCN+IxGDSnzWQpw7h5B5Mm0=";

    dontNpmBuild = true;

    # This mimics upstream's own release process https://github.com/invoiceninja/ui/blob/main/.github/workflows/release.yml
    postBuild = ''
      cp .env.example .env
      npm run build
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/
      cp -r dist/* $out/

      runHook postInstall
    '';

    meta = {
      changelog = "https://github.com/invoiceninja/ui/releases/tag/${version}";
      homepage = "https://github.com/invoiceninja/ui";
      description = "Invoice Ninja: Web admin portal built with React";
      license = lib.licenses.elastic20;
      maintainers = with lib.maintainers; [ ramblurr ];
    };
  };
in

php82.buildComposerProject (finalAttrs: {
  pname = "invoiceninja";
  version = "5.8.39";

  src = fetchFromGitHub {
    owner = "invoiceninja";
    repo = "invoiceninja";
    rev = "v${finalAttrs.version}";
    hash = "sha256-kt1dFfXPV/OKrRFGZ3LzMcAavxjZ1qeJLdifDtJnWr8=";
  };

  vendorHash = "sha256-wI5W6ZrUTEi2BPvMWuDq1MS6WfZJg6bvYYkYE0IwauQ=";

  # the composer.json is valid but has a few warnings that are not critical for our package
  # - invalid spdx license (elastic20)
  # - "webpatser/laravel-countries" is pointing to a commit-ref
  composerStrictValidation = false;

  patches = [
    # support connection to mysql and redis with unix domain sockets
    # upstream has not yet accepted this patch
    ./invoiceninja.patch
  ];

  postInstall = ''
    mv "$out/share/php/${finalAttrs.pname}"/* $out
    mv "$out/share/php/${finalAttrs.pname}"/.env.example $out
    mv $out/bootstrap $out/bootstrap-static
    mv $out/storage $out/storage-static
    mv $out/resources $out/resources-static
    ln -s ${dataDir}/.env $out/.env
    ln -s ${dataDir}/storage $out/
    rm -rf $out/public/storage
    ln -s ${dataDir}/storage-public $out/public/storage
    ln -s ${runtimeDir}/bootstrap $out/bootstrap
    ln -s ${runtimeDir}/resources $out/resources

    # Install the UI
    mkdir -p $out/public/react/v${finalAttrs.version}/
    cp -r ${invoiceninja-ui}/react/* $out/public/react/v${finalAttrs.version}/
    cp -r ${invoiceninja-ui}/react/* $out/public/react/
    set -eo pipefail # error out when upstream totally changes things
    tinymce_version=$(basename $(ls -d ${invoiceninja-ui}/tinymce_* | sort -V | tail -n1))

    mkdir -p $out/public/$tinymce_version
    cp -r ${invoiceninja-ui}/$tinymce_version/* $out/public/$tinymce_version/
    echo ${invoiceninja-ui.version} > $out/UI_VERSION
    rm -rf "$out/share"
    chmod +x $out/artisan
  '';

  meta = {
    changelog = "https://github.com/invoiceninja/invoiceninja/releases/tag/v${finalAttrs.version}";
    homepage = "https://github.com/invoiceninja/invoiceninja";
    description = "Free invoicing software for small businesses";
    license = lib.licenses.elastic20;
    maintainers = with lib.maintainers; [ ramblurr ];
  };
})
