{
  description = "Flake to setup test environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ] (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        isLinux = pkgs.stdenv.hostPlatform.isLinux;
          commonPackages = with pkgs; [
            bash
            coreutils
            gnugrep
            openssh
            rsync
            sshpass
          ] ++ lib.optional isLinux pkgs.iputils
            ++ lib.optional isLinux pkgs.iproute2;

        # TODO: ADT-1829 Use SOPS configuration to download Python packages
        pyproject_laserbeak = builtins.fromTOML (builtins.readFile ../../container_files/laserbeak/pyproject.toml);

        laserbeak = pkgs.python312Packages.buildPythonPackage rec {
          pname = pyproject_laserbeak.project.name;
          version = pyproject_laserbeak.project.version or "255.255.255";
          format = "pyproject";

          src = ../../container_files/laserbeak;

          nativeBuildInputs = with pkgs.python312Packages; [ flit-core ];
          propagatedBuildInputs = with pkgs.python312Packages;
            map (pkg: pkgs.python312Packages.${pkg}) (pyproject_laserbeak.project.dependencies or []);

          meta = {
            description = pyproject_laserbeak.project.description;
            authors = pyproject_laserbeak.project.authors;
          };
        };

        pyproject_snitch = builtins.fromTOML (builtins.readFile ../../container_files/snitch/pyproject.toml);
        snitch = pkgs.python312Packages.buildPythonPackage rec {
          pname = pyproject_snitch.project.name;
          version = pyproject_snitch.project.version or "255.255.255";
          format = "pyproject";

          src = ../../container_files/snitch;

          nativeBuildInputs = with pkgs.python312Packages; [ flit-core ];
          propagatedBuildInputs =
          let
            stdDeps = with pkgs.python312Packages;
              map (pkg: pkgs.python312Packages.${pkg}) (
                builtins.filter (dep: dep != "laserbeak") (pyproject_snitch.project.dependencies or [])
              );
          in stdDeps ++ [ laserbeak ];


          meta = {
            description = pyproject_snitch.project.description;
            authors = pyproject_snitch.project.authors;
          };
        };


        # Docs: https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/python.section.md#building-packages-and-applications-building-packages-and-applications
        pyproject_testzilla = builtins.fromTOML (builtins.readFile ../../test/pyproject.toml);

        testzilla = pkgs.python312Packages.buildPythonPackage rec {
          pname = pyproject_testzilla.project.name;
          version = pyproject_testzilla.project.version or "255.255.255";
          format = "pyproject";

          src = ../../test;

          nativeBuildInputs = with pkgs.python312Packages; [ setuptools wheel ];
          propagatedBuildInputs = with pkgs.python312Packages;
            map (pkg: pkgs.python312Packages.${pkg}) (pyproject_testzilla.project.dependencies or []);

          meta = {
            description = pyproject_testzilla.project.description;
            authors = pyproject_testzilla.project.authors;
          };
        };

        pythonEnv = pkgs.python312.withPackages (ps: [
          testzilla
          laserbeak
          snitch
          ps.pyyaml
          ps.playwright
          ps.pytest-random-order
        ]);


        extraLibs = with pkgs; [
          glibcLocales
          dejavu_fonts
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-cjk-serif
          noto-fonts-emoji
          liberation_ttf
          freefont_ttf
          unifont
        ];

        guiLibs = with pkgs; [
          glib
          xorg.libX11
          xorg.libXcomposite
          xorg.libXdamage
          xorg.libXrandr
          xorg.libXext
          xorg.libXrender
          xorg.libXi
          xorg.libXfixes
          xorg.libXcursor
          xorg.libxcb
          libxkbcommon
          mesa
          pango
          harfbuzz
          cairo
          freetype
          fontconfig
          gtk3
          gdk-pixbuf
          atk
          alsa-lib
          dbus
          stdenv.cc.cc.lib
        ] ++ (with pkgs.gst_all_1; [
          gstreamer
          gst-plugins-base
          gst-plugins-good
        ]) ++ extraLibs;

        # Dev shell
        shell = pkgs.mkShell {
          packages = [
            pythonEnv
            pkgs.playwright-driver
            pkgs.playwright-driver.browsers
          ] ++ commonPackages ++ guiLibs;
          shellHook = ''
            export PATH=${pythonEnv}/bin:$PATH
            export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
            export PYTHONPATH=${pythonEnv}/lib/python3.12/site-packages:$PYTHONPATH

            # Locale support (interactive-friendly)
            export LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive
            export LOCPATH=${pkgs.glibcLocales}/lib/locale
            export LANG=en_US.UTF-8
            export LC_ALL=en_US.UTF-8

            # Font configuration for Playwright
            export FONTCONFIG_FILE=${pkgs.fontconfig.out}/etc/fonts/fonts.conf
            export FONTCONFIG_PATH=${pkgs.fontconfig.out}/etc/fonts
          '';
        };

        # Build ContainerImage
        containerImage = pkgs.dockerTools.buildImage {
          name = "test-env";
          tag = "1.3.5";
          fromImageName = "nixos/nix";
          fromImageTag = "2.33.2";
          copyToRoot = pkgs.buildEnv {
            name = "python-env";
            paths = [
              pythonEnv
              pkgs.playwright-driver
              pkgs.playwright-driver.browsers
            ] ++ commonPackages ++ guiLibs;
            pathsToLink = [ "/bin" "/lib" "/share" ];
          };
          config = {
            Cmd = [ "/bin/bash" ];
            Env = [
              "PATH=${pythonEnv}/bin:/bin"
              "PYTHONPATH=${pythonEnv}/lib/python3.12/site-packages"
              "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1"
              "PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}"
              "PLAYWRIGHT_CHROMIUM_ARGS=--no-sandbox --disable-dev-shm-usage"
              # Deterministic locale for CI container
              "LANG=C.UTF-8"
              "LC_ALL=C.UTF-8"
              "USER=GITLAB_TESTER"
              # Font configuration for Playwright
              "FONTCONFIG_FILE=${pkgs.fontconfig.out}/etc/fonts/fonts.conf"
              "FONTCONFIG_PATH=${pkgs.fontconfig.out}/etc/fonts"
            ];
          };
          runAsRoot = ''
            #!${pkgs.runtimeShell}
            ${pkgs.dockerTools.shadowSetup}
          '';
        };

      in {
        devShells.test-environment = shell;
        devShells.default = shell;
        packages.containerImage = containerImage;
        packages.default = containerImage;
      }
    );

  nixConfig = {
    bash-prompt-suffix = "[test-environment-$SHLVL] ";
  };
}
