{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs@{ nixpkgs, flake-utils, ... }:
  flake-utils.lib.eachDefaultSystem (system:
  let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        (final: prev: {
          unstable = import inputs.unstable {
            system = final.system;
            config.allowUnfree = true;
          };
        })
      ];
      config.allowUnfree = true;
    };
    
  in rec {
    packages.pn-interface = pkgs.stdenvNoCC.mkDerivation rec {
      pname = "pn-interface";
      version = pkgs.lib.strings.fileContents "${src}/version.txt";
      gsd-version = pkgs.lib.strings.fileContents "${src}/gsd/version.txt";
      src = ./.;

      buildInputs = with pkgs; [
        (python312.withPackages (pythonPackages: with pythonPackages; [
          jinja2
          pyyaml
        ]))
      ];

      dontUnpack = true;

      buildPhase = ''
        echo "Building..."
        python3 $src/render-jinja.py ./GSDML.xml $src/gsd/GSDML.xml.jinja2 $src/pn-interface.yaml
      '';

      installPhase = ''
        echo "Installing..."
        install -Dm644 ./GSDML.xml $out/lib/GSDML-V2.44-ESAB-Adaptio\ Controller-${gsd-version}.xml
        install -Dm644 ${./pn-interface.yaml} $out/etc/pn-interface.yaml
        install -Dm755 ${./render-jinja.py} $out/bin/render-jinja
      '';
    };

    packages.default = packages.pn-interface;
  });
}
