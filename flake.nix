{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dotfiles = {
      url = "github:ncaq/dotfiles";
      flake = false; # ファイルだけ欲しいのでflakeとして扱う必要はない。
    };
  };

  outputs =
    inputs@{
      flake-parts,
      treefmt-nix,
      ...
    }:
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
          packages = {
            default = pkgs.runCommand "ncaq-net" { nativeBuildInputs = [ pkgs.gnupg ]; } ''
              mkdir -p $out
              cp -r --no-preserve=mode ${./public}/. $out/

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

            # flake.lockの管理バージョンをre-exportすることで安定した利用を促進。
            inherit (pkgs)
              nix-fast-build
              ;
          };
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
              typos.enable = true;
              zizmor.enable = true;
            };
            settings.formatter = {
              editorconfig-checker = {
                command = pkgs.editorconfig-checker;
                includes = [ "*" ];
              };
              zizmor.options = [ "--pedantic" ];
            };
          };
          checks = config.packages;

          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              # treefmtで指定したプログラムの単体版。
              actionlint
              deadnix
              editorconfig-checker
              nixfmt
              prettier
              shellcheck
              shfmt
              statix
              typos
              zizmor

              # nixの関連ツール。
              nil
              nix-fast-build

              # GitHub関連ツール。
              gh

              # プロジェクト固有ツール。
              wrangler
            ];
          };
        };
    };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org/"
      "https://niks3-public.ncaq.net/"
      "https://ncaq.cachix.org/"
      "https://nix-community.cachix.org/"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3-public.ncaq.net-1:e/B9GomqDchMBmx3IW/TMQDF8sjUCQzEofKhpehXl04="
      "ncaq.cachix.org-1:XF346GXI2n77SB5Yzqwhdfo7r0nFcZBaHsiiMOEljiE="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
