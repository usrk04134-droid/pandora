{
  description = "Git hooks and config setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      pre-commit-hooks,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        gitmessageFile = pkgs.writeText "gitmessage" (builtins.readFile ./.gitmessage);

        pythonVersion = pkgs.python3.pythonVersion;
        sitePackages = "lib/python${pythonVersion}/site-packages";
        gitlintPaths = rec {
          contribBase = "${sitePackages}/gitlint/contrib";
          rules = "${contribBase}/rules";
          config = "${contribBase}/config";
        };

        customGitlint = pkgs.gitlint.overrideAttrs (oldAttrs: {
          postInstall = ''
            mkdir -p $out/${gitlintPaths.rules} $out/${gitlintPaths.config}
            cp ${./container_files/gitlint/src}/*.py $out/${gitlintPaths.rules}/
            cp ${./container_files/gitlint}/.gitlint $out/${gitlintPaths.config}/
          '';
        });

        gitlintHook = {
          enable = true;
          name = "gitlint";
          entry = "${customGitlint}/bin/gitlint --config ${customGitlint}/${gitlintPaths.config}/.gitlint --msg-filename";
          stages = [ "commit-msg" ];
        };

        # Helm template validation hook
        helmTemplateHook = {
          enable = true;
          name = "helm-template";
          description = "Validate Helm charts with lint and template";
          entry = toString (
            pkgs.writeShellScript "helm-template-check.sh" ''
              set -e
              CHART_DIRS=$(find infrastructure/helm -name Chart.yaml -exec dirname {} \; 2>/dev/null || true)
              if [ -z "$CHART_DIRS" ]; then
                exit 0
              fi

              for chart in $CHART_DIRS; do
                echo "Validating Helm chart: $chart"
                ${pkgs.kubernetes-helm}/bin/helm lint "$chart" || exit 1
                ${pkgs.kubernetes-helm}/bin/helm template "$chart" release-name > /dev/null || exit 1
                echo "✓ $chart passed validation"
              done
            ''
          );
          files = "^infrastructure/helm/";
          pass_filenames = false;
        };
      in
      let
        preCommitCheck = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            inherit gitlintHook helmTemplateHook;

            # File formatting checks
            end-of-file-fixer.enable = true;
            nixfmt-rfc-style.enable = true;
            terraform-format.enable = true;
            hadolint.enable = true;

            # Security checks
            check-added-large-files.enable = true;
          };
        };
      in
      {
        checks.pre-commit-check = preCommitCheck;

        packages = {
          pre-commit = pkgs.writeShellScriptBin "setup-git-hooks" ''
            export PATH="${pkgs.pre-commit}/bin:$PATH"

            if [[ "$1" = "--uninstall" ]]; then
              pre-commit uninstall
              # Manually remove hook files in case pre-commit uninstall misses them
              rm -f .git/hooks/pre-commit .git/hooks/commit-msg .git/hooks/pre-merge-commit .git/hooks/pre-push .git/hooks/prepare-commit-msg
              if [[ -f .pre-commit-config.yaml ]]; then
                rm .pre-commit-config.yaml
                echo "Removed .pre-commit-config.yaml"
              fi
              echo "Pre-commit hooks removed successfully!"
              exit 0
            fi

            if [[ "$1" = "run" ]]; then
              shift
              if [[ ! -f .pre-commit-config.yaml ]]; then
                echo "Error: Pre-commit hooks not installed. Run 'nix run .#pre-commit' first."
                exit 1
              fi
              pre-commit run "$@"
              exit $?
            fi

            ${preCommitCheck.shellHook}
            if [[ $? -eq 0 ]]; then
              echo "Pre-commit hooks configured successfully!"
            else
              echo "Failed to configure pre-commit hooks!"
              exit 1
            fi
          '';

          gittemplate = pkgs.writeShellScriptBin "setup-git-template" ''
            handle_template() {
              local scope=$1
              local action=$2
              local template_path="${gitmessageFile}"
              local cmd="git config"
              [[ "$scope" = "global" ]] && cmd+=" --global"
              
              if [[ "$action" = "uninstall" ]]; then
                $cmd --unset commit.template
                echo "Git commit template removed ''${scope}ly!"
              else
                $cmd commit.template "$template_path"
                echo "Git commit template configured ''${scope}ly!"
              fi
            }

            scope="local"
            action="install"

            for arg in "$@"; do
              case $arg in
                "--global") scope="global" ;;
                "--uninstall") action="uninstall" ;;
                *) 
                  echo "Error: Unknown argument '$arg'"
                  echo "Usage: $0 [--global] [--uninstall]"
                  exit 1
                  ;;
              esac
            done

            handle_template "$scope" "$action"
          '';

          gitlint = pkgs.writeShellScriptBin "gitlint" ''
            ${customGitlint}/bin/gitlint --config ${customGitlint}/${gitlintPaths.config}/.gitlint "$@"
          '';

          mdlint = pkgs.writeShellScriptBin "mdlint" ''
            config="${./container_files/markdownlint_cli2/.markdownlint-cli2.yaml}"
            local_config="$(mktemp /tmp/mdlint.XXXXXX.markdownlint-cli2.yaml)"

            # CI config references formatter plugins that are not packaged in nixpkgs.
            # Keep all lint rules, but drop outputFormatters for local usage.
            awk '
              /^outputFormatters:/ { skip = 1; next }
              skip && /^[^[:space:]]/ { skip = 0 }
              !skip { print }
            ' "$config" > "$local_config"
            trap 'rm -f "$local_config"' EXIT

            if [[ $# -eq 0 ]]; then
              set -- "**/*.md"
            fi

            ${pkgs.markdownlint-cli2}/bin/markdownlint-cli2 --config "$local_config" "$@"
          '';

          mdformat = pkgs.writeShellScriptBin "mdformat" ''
            config="${./container_files/markdownlint_cli2/.markdownlint-cli2.yaml}"
            local_config="$(mktemp /tmp/mdformat.XXXXXX.markdownlint-cli2.yaml)"

            # CI config references formatter plugins that are not packaged in nixpkgs.
            # Keep all lint rules, but drop outputFormatters for local usage.
            awk '
              /^outputFormatters:/ { skip = 1; next }
              skip && /^[^[:space:]]/ { skip = 0 }
              !skip { print }
            ' "$config" > "$local_config"
            trap 'rm -f "$local_config"' EXIT

            if [[ $# -eq 0 ]]; then
              set -- "**/*.md"
            fi

            ${pkgs.markdownlint-cli2}/bin/markdownlint-cli2 --fix --config "$local_config" "$@"
          '';

          eslint = pkgs.nodePackages.eslint;
          prettier = pkgs.nodePackages.prettier;
          typescript = pkgs.nodePackages.typescript;
          nixfmt = pkgs.nixfmt-rfc-style;
        };
      }
    );
}
