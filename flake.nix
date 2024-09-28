{
  description = "php-handlebars";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    mustache_spec = {
      url = "github:mustache/spec";
      flake = false;
    };
    handlebars_spec = {
      url = "github:jbboehr/handlebars-spec";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    handlebars-c = {
      url = "github:jbboehr/handlebars.c";
      #inputs.mustache_spec.follows = "mustache_spec";
      #inputs.handlebars_spec.follows = "handlebars_spec";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    php-psr = {
      url = "github:jbboehr/php-psr";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
    };
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
      inputs.gitignore.follows = "gitignore";
    };
    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    systems,
    flake-utils,
    mustache_spec,
    handlebars_spec,
    handlebars-c,
    php-psr,
    gitignore,
    pre-commit-hooks,
    nix-github-actions,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
        lib = pkgs.lib;

        src' = gitignore.lib.gitignoreSource ./.;
        src = pkgs.lib.cleanSourceWith {
          name = "php-handlebars-source";
          src = src';
          filter = gitignore.lib.gitignoreFilterWith {
            basePath = ./.;
            extraRules = ''
              .clang-format
              composer.json
              composer.lock
              .editorconfig
              .envrc
              .gitattributes
              .github
              .gitignore
              *.md
              *.nix
              flake.*
            '';
          };
        };

        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = src';
          hooks = {
            actionlint.enable = true;
            alejandra.enable = true;
            #markdownlint.enable = true;
            #shellcheck.enable = true;
          };
        };

        makePackage = {
          stdenv ? pkgs.stdenv,
          php ? pkgs.php,
          astSupport ? false,
          checkSupport ? false,
          coverageSupport ? false,
        }:
          pkgs.callPackage ./nix/derivation.nix {
            inherit src;
            inherit stdenv php;
            inherit astSupport checkSupport coverageSupport;
            buildPecl = pkgs.callPackage (nixpkgs + "/pkgs/build-support/php/build-pecl.nix") {
              inherit php stdenv;
            };
            mustache_spec = mustache_spec;
            handlebars_spec = handlebars_spec.packages.${system}.handlebars-spec;
            handlebarsc = handlebars-c.packages.${system}.handlebars-c;
            php_psr = php-psr.packages.${system}.php-psr;
          };

        makeCheck = package:
          package.override {
            checkSupport = true;
            WerrorSupport = true;
          };

        makeDevShell = package:
          (pkgs.mkShell.override {
            stdenv = package.stdenv;
          }) {
            inputsFrom = [package];
            buildInputs = with pkgs; [
              actionlint
              autoconf-archive
              clang-tools
              lcov
              gdb
              package.php.packages.composer
              pre-commit
              valgrind
            ];
            shellHook = ''
              ${pre-commit-check.shellHook}
              mkdir -p .direnv/include
              unlink .direnv/include/php
              ln -sf ${package.php.unwrapped.dev}/include/php/ .direnv/include/php
              export REPORT_EXIT_STATUS=1
              export NO_INTERACTION=1
              export PATH="$PWD/vendor/bin:$PATH"
            '';
          };

        matrix = with pkgs; {
          php = {
            inherit php81 php82 php83;
            php84 = pkgs-unstable.php84;
          };
          stdenv = {
            gcc = stdenv;
            clang = clangStdenv;
            # totally broken
            #musl = pkgsMusl.stdenv;
          };
        };

        # @see https://github.com/NixOS/nixpkgs/pull/110787
        buildConfs =
          (lib.cartesianProductOfSets {
            php = ["php81" "php82" "php83" "php84"];
            stdenv = [
              "gcc"
              "clang"
              # totally broken
              # "musl"
            ];
            astSupport = [true false];
            coverageSupport = [false];
          })
          ++ (lib.cartesianProductOfSets {
            php = ["php81" "php82" "php83" "php84"];
            stdenv = ["gcc"];
            astSupport = [true];
            coverageSupport = [true];
          });

        buildFn = {
          php,
          stdenv,
          astSupport ? false,
          coverageSupport ? false,
        }:
          lib.nameValuePair
          (lib.concatStringsSep "-" (lib.filter (v: v != "") [
            "${php}"
            "${stdenv}"
            (
              if astSupport
              then "ast"
              else ""
            )
            (
              if coverageSupport
              then "coverage"
              else ""
            )
          ]))
          (
            makePackage {
              php = matrix.php.${php};
              stdenv = matrix.stdenv.${stdenv};
              inherit astSupport coverageSupport;
            }
          );

        packages = builtins.listToAttrs (builtins.map buildFn buildConfs);
      in {
        packages =
          packages
          // {
            default = packages.php81-gcc;
            php-handlebars = packages.php81-gcc; # old package name
            php-handlebars-dist =
              pkgs.runCommand "handlebars-pecl.tgz"
              {
                buildInputs = [pkgs.php];
                inherit src;
              } ''
                cp -r $src/* .
                PHP_PEAR_PHP_BIN=${pkgs.php}/bin/php pecl package
                mv handlebars-*.tgz $out
              '';
          };

        devShells = builtins.mapAttrs (name: package: makeDevShell package) (packages
          // {
            default = packages.php81-gcc;
          });

        checks =
          {inherit pre-commit-check;}
          // (builtins.mapAttrs (name: package: makeCheck package) packages);

        formatter = pkgs.alejandra;
      }
    )
    // {
      # prolly gonna break at some point
      githubActions.matrix.include = let
        cleanFn = v: v // {name = builtins.replaceStrings ["githubActions." "checks." "x86_64-linux."] ["" "" ""] v.attr;};
      in
        builtins.map cleanFn
        (nix-github-actions.lib.mkGithubMatrix {
          attrPrefix = "checks";
          checks = nixpkgs.lib.getAttrs ["x86_64-linux"] self.checks;
        })
        .matrix
        .include;
    };
}
