{
  lib,
  fetchFromGitHub,
  php,
  dataDir ? "/var/lib/davis/",
  configDir ? "/etc/davis/",
}:
php.buildComposerProject (finalAttrs: {
  pname = "davis";
  version = "4.4.1";

  src = fetchFromGitHub {
    owner = "tchapi";
    repo = "davis";
    rev = "v${finalAttrs.version}";
    hash = "sha256-UBekmxKs4dveHh866Ix8UzY2NL6ygb8CKor+V3Cblns=";
  };

  composerLock = ./composer.lock;
  vendorHash = "sha256-WGeNwBRzfUXa7kPIwd7/5dPXDjaBxXirAJcm6lNzueY=";

  meta = with lib; {
    homepage = "https://github.com/tchapi/davis";
    description = "A simple, fully translatable webdav and webcal server and admin interface for sabre/dav inspired by Baïkal";
    license = licenses.mit;
    platforms = platforms.all;
  };
})
