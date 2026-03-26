{
  description = '''';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    pndriver-lib = {
      type = "gitlab";
      owner = "esab";
      repo = "abw%2Fpndriver";
      # ref = "main";
      rev = "0027554941c95f9947fa8b35388a015eb71b9cfb";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    infra-utils = {
      type = "gitlab";
      owner = "esab";
      repo = "abw%2Finfra-and-test";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pn-interface = {
      type = "gitlab";
      owner = "esab";
      repo = "abw%2Fplc%2Fpn-interface";
      # ref = "main";
      rev = "5adeff2820b16843850ca23250d9e603c1f6e791";
    };
    pylon-software = {
      type = "gitlab";
      owner = "esab";
      repo = "abw%2Fpylon-software";
      # ref = "main";
      rev = "e7fbac8a736902b99f1a3f323bfa699a1f27af1e";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      pndriver-lib,
      infra-utils,
      pn-interface,
      pylon-software,
      ...
    }:
    flake-utils.lib.eachSystem
      [
        flake-utils.lib.system.x86_64-linux
        flake-utils.lib.system.aarch64-linux
      ]
      (
        system:
        let
          enablePnDriver = system == "x86_64-linux";
          enablePylon = system == "x86_64-linux";

          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                opencv = prev.opencv.override {
                  enableGtk2 = true;
                };

                pn-interface = pn-interface.packages.${final.stdenv.hostPlatform.system}.default;

                # Override ceres-solver to disable SuiteSparse, CXSparse and LAPACK
                #
                # Merely linking against libceres.so (with above packages enabled) causes
                # thread creation (pthread_create) to fail inside civetweb (mg_start call).
                # Disabling these packages removes several library dependencies including
                # a direct libpthread dependency from LAPACK.
                #
                # Note: CivetWeb is linked indirectly via prometheus-cpp-pull.so,
                # so this issue occurs even if the application doesn't link CivetWeb directly.
                ceres-solver = prev.ceres-solver.overrideAttrs (oldAttrs: {
                  cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
                    "-DSUITESPARSE=OFF"
                    "-DCXSPARSE=OFF"
                    "-DLAPACK=OFF"
                  ];
                });
              })
            ];
            config.allowUnfree = true;
            config.permittedInsecurePackages = [
            ];
          };

          pndriver = if enablePnDriver then pndriver-lib.defaultPackage.${system} else null;

          pylon-lib = if enablePylon then pylon-software.packages.${system}.pylon-lib else null;
          pylon-dev = if enablePylon then pylon-software.packages.${system}.pylon-dev else null;

          # Make an adaptio package, with the ability to select debug, test binaries etc.
          makeAdaptioPackage =
            {
              application ? true,
              debug ? false,
              unitTests ? false,
              blockTests ? false,
              extraCmakeFlags ? [ ],
            }:
            let
              src = ./.;
              python-packages =
                ps: with ps; [
                  jinja2
                  pytest
                  pyyaml
                  pyzmq
                  dataclasses-json
                  setuptools
                  numpy
                  matplotlib
                  websocket-client
                  pandas
                ];
              revShort =
                if (self ? rev) then
                  self.shortRev
                else if (self ? dirtyRev) then
                  self.dirtyShortRev
                else
                  "dirty-inputs";

              # Make sure to build tests with Debug
              debugBuild = debug || unitTests || blockTests;
              pnamePostFix = (
                if unitTests || blockTests then
                  "-tests"
                else if debug then
                  "-debug"
                else
                  ""
              );

            in
            pkgs.llvmPackages_21.stdenv.mkDerivation {
              pname = "adaptio" + pnamePostFix;
              version = pkgs.lib.strings.fileContents "${src}/version.txt";
              inherit src;

              PnDriver_ROOT = pkgs.lib.optionalString enablePnDriver "${pndriver}";

              Pylon_LIB = pkgs.lib.optionalString enablePylon "${pylon-lib}";

              Pylon_DEV = pkgs.lib.optionalString enablePylon "${pylon-dev}";

              cmakeFlags = [
                "-DGIT_REV_SHORT=${revShort}"
              ]
              ++ pkgs.lib.optional (!enablePnDriver) "-DENABLE_PNDRIVER=OFF"
              ++ pkgs.lib.optional (!enablePylon) "-DENABLE_PYLON=OFF"
              ++ extraCmakeFlags;

              cmakeBuildType = if !debugBuild then "Release" else "Debug";

              dontStrip = debugBuild;

              ninjaFlags =
                (if application then [ "adaptio" ] else [ ])
                ++ (if unitTests then [ "adaptio-unit-tests" ] else [ ])
                ++ (if blockTests then [ "adaptio-block-tests" ] else [ ]);

              buildInputs =
                with pkgs;
                [
                  # Utilities
                  boost181
                  fmt
                  nlohmann_json

                  # Infrastructure
                  cppzmq
                  openssl

                  # Data collection
                  prometheus-cpp

                  # Persistent storage
                  yaml-cpp
                  sqlite
                  sqlitecpp

                  # Hardware interfaces
                ]
                ++ pkgs.lib.optional enablePnDriver pndriver
                ++ pkgs.lib.optional enablePylon pylon-lib
                ++ (with pkgs; [

                  # Testing
                  doctest # Unit tests
                  trompeloeil # Mocking library

                  # Maths
                  eigen
                  opencv
                  ceres-solver
                  pcl # point cloud library (ransac)

                  libtiff
                ]);

              nativeBuildInputs = with pkgs; [
                (python311.withPackages python-packages)
                cmake
                curl
                doxygen
                git
                graphviz
                ninja
                autoPatchelfHook
              ];

              env = {
                PN_INTERFACE = "${pkgs.pn-interface}";
              };

              installPhase = ''
                runHook preInstall

                # Create output directories
                mkdir -p $out/bin

                # Install the specific adaptio binary from src directory
              ''
              + (
                if application then
                  ''
                    install -m755 src/adaptio $out/bin/adaptio
                    cp -r ../assets/ $out/
                  ''
                else
                  ''''
              )
              + (
                if unitTests then
                  ''
                    install -m755 src/adaptio-unit-tests $out/bin/adaptio-unit-tests
                  ''
                else
                  ''''
              )
              + (
                if blockTests then
                  ''
                    install -m755 src/adaptio-block-tests $out/bin/adaptio-block-tests
                  ''
                else
                  ''''
              )
              + ''
                runHook postInstall
              '';

              postFixup =
                if application then
                  ''
                      mv $out/bin/adaptio $out/bin/.adaptio-wrapped

                      cat > $out/bin/adaptio <<EOF
                      #!/usr/bin/env bash

                      ulimit -c unlimited
                      exec $out/bin/.adaptio-wrapped "\$@"
                    EOF

                      chmod a+rx $out/bin/adaptio
                  ''
                else
                  '''';
            };

        in
        rec {
          ################################
          ## Package derivations
          ################################

          packages.default = packages.adaptio;

          packages = {
            pre-commit = infra-utils.packages.${system}.pre-commit;
            gitlint = infra-utils.packages.${system}.gitlint;
            gittemplate = infra-utils.packages.${system}.gittemplate;
          };

          packages.adaptio = makeAdaptioPackage { };
          packages.adaptio-debug = makeAdaptioPackage { debug = true; };
          packages.adaptio-tests = makeAdaptioPackage {
            application = false;
            unitTests = true;
            blockTests = true;
          };

          packages.adaptio-dev = pkgs.stdenv.mkDerivation {
            name = "adaptio-dev";

            src = ./adaptio.sh;

            dontUnpack = true;
            dontBuild = true;

            installPhase = ''
              mkdir -p $out/bin
              cp $src $out/bin/adaptio
            '';
          };

          packages.adaptio-docker =
            let
              adaptio = self.packages.${system}.default;
            in
            pkgs.dockerTools.buildLayeredImage {
              name = adaptio.name;
              tag = adaptio.version;
              created = builtins.substring 0 8 self.lastModifiedDate;

              contents = [
                adaptio
                pkgs.bash
              ];

              config = {
                Cmd = [ "${pkgs.bash}/bin/bash" ];
                Volumes = {
                  "/etc/timezone:/etc/timezone:ro" = { };
                  "/etc/localtime:/etc/localtime:ro" = { };
                };
              };
            };

          ################################
          ## Environment
          ################################
          packages.env =
            let
              llvmPackages = pkgs.llvmPackages_21;
            in
            pkgs.mkShell.override { stdenv = llvmPackages.stdenv; } {
              PnDriver_ROOT = pkgs.lib.optionalString enablePnDriver "${pndriver}";
              PN_INTERFACE = "${pkgs.pn-interface}";
              Pylon_LIB = pkgs.lib.optionalString enablePylon "${pylon-lib}";
              Pylon_DEV = pkgs.lib.optionalString enablePylon "${pylon-dev}";
              packages =
                with pkgs;
                [
                  pkgs.pn-interface
                  valgrind
                  perf-tools
                  packages.adaptio-dev # Our dev script
                  llvmPackages.libllvm # Puts llvm-symbolizer in path for use with ASAN
                  lldb_21
                  hotspot
                  llvmPackages_21.clang-tools
                  graphviz
                  markdownlint-cli2
                ]
                ++ builtins.filter (x: x != git) packages.adaptio.nativeBuildInputs
                ++ packages.adaptio.buildInputs;
            };

          devShells.default = packages.env;
          packages.nixfmt = infra-utils.packages.x86_64-linux.nixfmt;
        }
      );
}
