{
  description = "Relocation utility flake";

  inputs.nixrewrite = {
    url = "github:timjrd/nixrewrite";
    flake = false;
  };
  outputs = { self, nixrewrite, nixpkgs }: {

    packages.x86_64-linux.nixrewrite =
    nixpkgs.legacyPackages.x86_64-linux.stdenv.mkDerivation {
      pname = "nixrewrite";
      version = "0.1";
      src = nixrewrite;
      installPhase = ''
          ls -alh
          install -Dm755 pack $out/bin/pack
          install -Dm755 unpack $out/bin/unpack
          install -Dm755 nixrewrite $out/bin/nixrewrite
      '';
    };

    legacyPackages.x86_64-linux =
    with nixpkgs.legacyPackages.x86_64-linux;
    let rel = callPackage ./relocate.nix {
      nixrewrite = self.packages.x86_64-linux.nixrewrite;
     };
      in stdenv.mkDerivation {
      name = "test";
      buildCommand = ''
        echo hi > $out
      '';
      passthru = with builtins; mapAttrs (n: v:
           rel {
                  drv = v;
                  verbose = true;
                }
          ) nixpkgs.legacyPackages.x86_64-linux;
    };
  };
}
