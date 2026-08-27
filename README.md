# sprite-nix

A Nix flake for the [Sprites](https://sprites.dev) CLI. Sprites gives you a
remote Linux machine that keeps its state. The command is `sprite`.

Platforms: `aarch64-darwin`, `x86_64-linux`, `aarch64-linux`.

## Install

Add the flake as an input:

```nix
inputs.sprite = {
  url = "github:rellen/sprite-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Apply the overlay in your nix-darwin or NixOS configuration:

```nix
nixpkgs.overlays = [ sprite.overlays.default ];
```

Let Nix use this unfree package:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "sprite" ];
```

Then install `pkgs.sprite`.

The overlay builds the package with your own `pkgs`. Your configuration
therefore records the licence decision. Use `packages.<system>.sprite` instead
for `nix build`, `nix run`, or CI.

## Update

Move to a new release:

```sh
nix flake update sprite
```

A workflow bumps this repository every hour. Your machine moves only when you
run the command above.

To bump this repository by hand, run `nix run .#update`.

## Why not `pkgs.sprite`

nixpkgs also ships this CLI, but it stays at an old version. Upstream changed the
release layout, so nixpkgs now fetches a file that upstream no longer publishes.
The nixpkgs update script also reads a frozen legacy address, so it reports no
new version. The header comment in `package.nix` records the measurements.

## Notes

- The binary is unfree. Upstream publishes no licence, and the Fly.io terms
  grant no redistribution right. Do not push this package to a public binary
  cache.
- `sprite upgrade` fails from the Nix store, because that store is read-only.
  Use `nix flake update sprite`.
- Upstream publishes no build for an Intel Mac.
- The MIT licence in `LICENSE` covers this packaging only. It does not cover the
  binary, which this repository never contains.
