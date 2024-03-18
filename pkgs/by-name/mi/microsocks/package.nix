{
  stdenv,
  fetchFromGitHub,
  lib
}:
stdenv.mkDerivation rec {
  pname = "microsocks";
  version = "1.0.4";
  src = fetchFromGitHub {
    owner = "rofl0r";
    repo = "microsocks";
    rev = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-cB2XMWjoZ1zLAmAfl/nqjdOyBDKZ+xtlEmqsZxjnFn0=";
  };

  installPhase = ''
    install -Dm 755 microsocks -t $out/bin/
  '';

  meta = with lib; {
    description = "Tiny, portable SOCKS5 server with very moderate resource usage";
    homepage = "https://github.com/rofl0r/microsocks";
    license = licenses.mit;
    mainProgram = "microsocks";
    maintainers = with maintainers; [ ramblurr ];
    platforms = platforms.all;
  };
}
