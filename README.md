# sprite-nix

A Nix flake for the [Sprites](https://sprites.dev) CLI (`sprite`), Fly.io's
stateful sandbox environments. Covers `aarch64-darwin`, `x86_64-linux` and
`aarch64-linux`.

## Why this repo exists

nixpkgs ships `sprite`, and it cannot move. Upstream changed its release layout:
the release channel now uses **date versions** and publishes a **raw
per-platform binary** with a `manifest.json`. The old `v0.0.1-rcNN` tarball
layout is frozen.

Measured 2026-08-27 with `curl`:

| endpoint | result |
| --- | --- |
| `client/latest` | `2026-08-21` |
| `client/2026-08-21/manifest.json` | 200 |
| `client/release.txt` | 404 |
| `client/rc.txt` | `v0.0.1-rc48` (frozen) |
| `client/v0.0.1-rc48/sprite-darwin-arm64.tar.gz` | 200 |
| `client/2026-08-21/sprite-darwin-arm64.tar.gz` | 404 |
| `client/v0.0.1-rc48/manifest.json` | 404 |

No version publishes both forms, so the two schemes never overlap.

nixpkgs' `update.sh` reads `release.txt`, then falls back to `rc.txt`. It
therefore reports "up to date" at rc48 for ever, and its `fetchurl` hardcodes a
tarball path that 404s for every date release. The r-ryantm bot cannot fix that;
a human must rewrite the derivation. `jamiebrynes7/sprite-cli-nix` reads the
same two endpoints and last moved on 2026-04-03.

This repo reads `client/latest`.

## Use it

```nix
{
  inputs.sprite = {
    url = "github:rellen/sprite-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then apply the overlay in your nix-darwin or NixOS config:

```nix
nixpkgs.overlays = [ sprite.overlays.default ];
```

and install `pkgs.sprite`.

The package is **unfree**, so a predicate must permit it:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "sprite" ];
```

The overlay route is deliberate. It builds the package with *your* `pkgs`, so
your own config records the licence decision. `packages.<system>.sprite` exists
too, for `nix build`, `nix run` and this repo's CI. That route permits the one
name internally and does not leak into a consumer's config.

## Freshness

`update.yml` runs hourly, resolves `client/latest`, rewrites `version.json`,
builds it, and pushes. Your machine still moves on `nix flake update sprite`.
That is on purpose: the lock file diff is reviewable, and `darwin-rebuild build`
still checks the thing you are about to switch to.

`scripts/update-version.sh` downloads nothing. The manifest's sha256 is the
digest of the exact file `fetchurl` fetches, so the script converts three hex
digests to SRI form. Exit codes: `0` current, `10` update available (`--check`
only), `1` failure.

```sh
nix run .#update          # rewrite version.json
./scripts/update-version.sh --check
```

## The 60-day trap

GitHub disables a scheduled workflow after 60 days with no repository activity.
That is the most likely reason `sprite-cli-nix` went quiet: its last push was
2026-04-03, the next upstream release landed 2026-06-17, and the gap crossed the
threshold. It is a likely cause, not a proven one — its Actions history was not
read.

Two defences ship here. `workflow_dispatch` on every workflow lets you wake one
by hand. `keepalive.yml` commits a monthly timestamp. Whether a
`GITHUB_TOKEN`-authored commit counts as the activity that rearms the timer is
UNVERIFIED. If `update.yml` goes quiet for longer than upstream does, run it from
the Actions tab and treat the keepalive as broken.

## Notes

* The binary is Go 1.24 with `CGO_ENABLED=1`. Linux builds link glibc
  dynamically and get `autoPatchelfHook`. The macOS build links only `/usr/lib`
  and system frameworks.
* `wrapProgram --set UPGRADE_CHECK false` suppresses the passive upgrade notice.
  Whether the current binary honours that variable is UNVERIFIED: an older build
  documented `UPGRADE_CHECK=true` as a cache *bypass*, and the current build
  documents no environment variable at all.
* `sprite upgrade` cannot work from the Nix store, which is read-only. Use
  `nix flake update sprite`.
* An out-of-date client is not rejected by the server. A build 18 releases
  behind still runs, and the binary holds no enforcement strings.
* Upstream ships no Intel macOS build.
