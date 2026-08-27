{
  description = "The sprites.dev CLI, tracked from the upstream release manifest";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems f;

      # The package is unfree, so some pkgs instance must permit it. There are
      # two consumption routes, and they answer that question differently on
      # purpose.
      #
      #   overlays.default   -- for a nix-darwin or NixOS config. The package is
      #                         built with YOUR pkgs, so YOUR allowUnfreePredicate
      #                         decides. That keeps the licence decision visible
      #                         in the config that installs it.
      #
      #   packages.<system>  -- for `nix build`, `nix run` and this repo's CI.
      #                         Allows the one name, scoped to this flake. It
      #                         does not leak into a consumer's config.
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: lib.getName pkg == "sprite";
        };
    in
    {
      overlays.default = final: _prev: {
        sprite = final.callPackage ./package.nix { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        rec {
          sprite = pkgs.callPackage ./package.nix { };
          default = sprite;
        }
      );

      # `nix run .#update` resolves the current release and rewrites
      # version.json. It downloads nothing: the upstream manifest's sha256 is
      # the digest of the exact file fetchurl fetches.
      apps = forAllSystems (system: {
        update = {
          type = "app";
          program = "${
            (pkgsFor system).writeShellApplication {
              name = "update-sprite-version";
              runtimeInputs = with (pkgsFor system); [
                curl
                jq
              ];
              text = builtins.readFile ./scripts/update-version.sh;
            }
          }/bin/update-sprite-version";
        };
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              curl
              jq
              nixfmt
            ];
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);

      checks = forAllSystems (system: {
        sprite = self.packages.${system}.sprite;
      });
    };
}
