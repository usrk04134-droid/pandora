{
  description = ''
  Flake for NixOS in HIL PC
  '';

  #nixConfig = {
  #  extra-substituters = [
  #    "https://nix-community.cachix.org"
  #  ];
  #  extra-trusted-public-keys = [
  #    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  #  ];
  #};

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    raspberry-pi-nix = {
      url = "github:nix-community/raspberry-pi-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-stored = {
      url = "github:ChrisOboe/nix-stored";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, disko, ... }:
  let
    generateAutoInstaller = { system, target, name }:
      (nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./modules/auto-installer
          ({ pkgs, lib, ... }: {
            system.stateVersion = "25.11";
            image.baseName = lib.mkForce "${name}-installer";
            auto-installer = {
              enable = true;
              target = target;
              hilName = name;
            };
          })
        ];
      }).config.system.build.isoImage;

    mkHilPC = name:
      let
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      in nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        inherit pkgs;
        modules = [
          disko.nixosModules.disko
          ./hosts/${name}
        ];
      };

    hilNames = [ "hil-gbg-01" "hil-gbg-02" "hil-chn-01" ];

    hilPCConfigs = builtins.listToAttrs (map (name: {
      inherit name;
      value = mkHilPC name;
    }) hilNames);
  in
  {
    nixosConfigurations = hilPCConfigs // {
      rpi5 = let
        pkgs = import nixpkgs {
          system = "aarch64-linux";
          config.allowUnfree = true;
        };
      in nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        inherit pkgs;
        modules = [
          ./hosts/rpi5
          ./modules/common/services/hil-runner
        ];
      };
    };

    packages = {
      x86_64-linux =
        builtins.listToAttrs (map (name: {
          name = "${name}-installer";
          value = generateAutoInstaller {
            system = "x86_64-linux";
            target = hilPCConfigs.${name};
            name = name;
          };
        }) hilNames)
        //
        builtins.listToAttrs (map (name: {
          name = "${name}";
          value = self.nixosConfigurations.${name}.config.system.build.toplevel;
        }) hilNames);

      aarch64-linux = rec {
        inherit
          (self.nixosConfigurations."rpi5".config.system.build)
          toplevel
          sdImage;

        default = sdImage;
      };
    };
  };
}
