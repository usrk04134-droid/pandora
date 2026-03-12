{ lib, config, inputs, ... }:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = ../../../../secrets.yaml;

    age = {
      keyFile = "/persist/sops/age/keys.txt";
      sshKeyPaths = [];
    };

    secrets = {
      "hosts/${config.networking.hostName}/runner-registration-token" = {};
    };
  };
}
