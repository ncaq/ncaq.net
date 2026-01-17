{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    dotfiles = {
      url = "github:ncaq/dotfiles";
      flake = false; # ファイルだけ欲しいのでflakeとして扱う必要はない。
    };
  };

  outputs =
    inputs@{ treefmt-nix, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        treefmt-nix.flakeModule
      ];

      systems = [ "x86_64-linux" ];

      perSystem =
        {
          pkgs,
          config,
          ...
        }:
        {
          packages.default = pkgs.runCommand "ncaq-net" { nativeBuildInputs = [ pkgs.gnupg ]; } ''
            mkdir -p $out
            cp -r ${./public}/* $out/

            export GNUPGHOME=$(mktemp -d)
            gpg --import ${inputs.dotfiles}/key/ncaq-public-key.asc

            # WKD用ディレクトリ構造を生成
            mkdir -p $out/.well-known/openpgpkey
            gpg --list-options show-only-fpr-mbox -k ncaq@ncaq.net | \
              gpg-wks-client --install-key -C $out/.well-known/openpgpkey

            # gpg-wks-clientはAdvanced Method用に ncaq.net/ サブディレクトリを作るので
            # Direct Method用にhu/を直下に移動
            mv $out/.well-known/openpgpkey/ncaq.net/hu $out/.well-known/openpgpkey/
            mv $out/.well-known/openpgpkey/ncaq.net/policy $out/.well-known/openpgpkey/
            rmdir $out/.well-known/openpgpkey/ncaq.net
          '';
          treefmt.config = {
            projectRootFile = "flake.nix";
            programs = {
              actionlint.enable = true;
              deadnix.enable = true;
              nixfmt.enable = true;
              prettier.enable = true;
              shellcheck.enable = true;
              shfmt.enable = true;
              statix.enable = true;
            };
          };
          checks = config.packages;
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [ wrangler ];
          };
        };
    };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://ncaq-net.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "ncaq-net.cachix.org-1:x11ioC1/NZ2oJDpJJoaHjJjiPsj4xICn0uG+pSH5PZw="
    ];
  };
}
