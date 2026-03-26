{
  description = ''
    Flake for aws-tests repo
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    infra-utils = {
      type = "gitlab";
      owner = "esab";
      repo = "abw%2Finfra-and-test";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      infra-utils,
    }:
    {
      packages.x86_64-linux = {
        pre-commit = infra-utils.packages.x86_64-linux.pre-commit;
        gitlint = infra-utils.packages.x86_64-linux.gitlint;
        gittemplate = infra-utils.packages.x86_64-linux.gittemplate;
        nixfmt = infra-utils.packages.x86_64-linux.nixfmt;
      };
    };
}
