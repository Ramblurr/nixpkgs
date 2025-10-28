{
  lib,
  fetchFromGitHub,
  php,
  nixosTests,
}:

php.buildComposerProject2 (finalAttrs: {
  pname = "davis";
  version = "5.3.0-alpha1";

  src = fetchFromGitHub {
    owner = "tchapi";
    repo = "davis";
    #tag = "v${finalAttrs.version}";
    rev = "6fecdb43d372c252f3cf7cedfb95955fb539dabf";
    hash = "sha256-b5WcMP+6mf/GIU9x8I7+IX4v45PdF0RNt0pQZFOoU/M=";
  };

  vendorHash = "sha256-bUQZ1TgxuCCETd7Nhi9LvmF6FGhWatjqK2nj2RV3DDc=";

  composerNoPlugins = false;

  postInstall = ''
    chmod -R u+w $out/share
    # Only include the files needed for runtime in the derivation
    mv $out/share/php/davis/{migrations,public,src,config,bin,templates,tests,translations,vendor,symfony.lock,composer.json,composer.lock} $out
    # Save the upstream .env file for reference, but rename it so it is not loaded
    mv $out/share/php/davis/.env $out/env-upstream
    rm -rf "$out/share"
  '';

  passthru = {
    php = php;
    tests = {
      inherit (nixosTests) davis;
    };
  };

  meta = {
    changelog = "https://github.com/tchapi/davis/releases/tag/v${finalAttrs.version}";
    homepage = "https://github.com/tchapi/davis";
    description = "Simple CardDav and CalDav server inspired by Baïkal";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ramblurr ];
  };
})
