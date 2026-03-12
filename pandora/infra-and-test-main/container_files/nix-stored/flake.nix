{
  description = "Docker container wrapper around nix-stored";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    nix-stored.url = "github:ChrisOboe/nix-stored";
  };

  outputs = { self, nixpkgs, flake-utils, nix-stored }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        bin = nix-stored.packages.${system}.default;
        version = nix-stored.packages.${system}.default.version;
        date = nix-stored.lastModifiedDate;

        containerImage = pkgs.dockerTools.buildImage {
            name = "nix-stored";
            tag = "1.0.1";

            copyToRoot = [ bin ];

            config = {
              Cmd = [ "/bin/nix-stored" ];
              Env = [ "NIX_STORED_LOG_LEVEL=DEBUG" ];
              Labels = {
                "nix-stored.version" = version;
                "nix-stored.build-date" = date;
              };
            };
          };
      in
      with pkgs;
      {
        packages = {
          inherit containerImage bin;
          default = bin;
        };
        devShells.default = mkShell {
          inputsFrom = [ bin ];
        };
      }
    );
}
