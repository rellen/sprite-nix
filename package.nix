# The Sprites CLI (https://sprites.dev), built from the upstream release
# manifest.
#
# Not `pkgs.sprite`: nixpkgs fetches a tarball path that upstream stopped
# publishing, and its update.sh reads a frozen legacy address, so it never sees
# a new release. jamiebrynes7/sprite-cli-nix reads the same dead addresses.
#
# VERIFIED 2026-08-27 by curl:
#   client/latest                                -> 2026-08-21
#   client/2026-08-21/manifest.json              -> 200
#   client/rc.txt                                -> v0.0.1-rc48  (frozen)
#   client/release.txt                           -> 404
#   client/2026-08-21/sprite-darwin-arm64.tar.gz -> 404
#   client/v0.0.1-rc48/manifest.json             -> 404
# No version publishes both forms.
#
# version.json comes from scripts/update-version.sh. The manifest sha256 is the
# digest of the file fetchurl fetches, so that script downloads nothing.
{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:
let
  info = lib.importJSON ./version.json;
  entry =
    info.platforms.${stdenv.hostPlatform.system}
      or (throw "sprite: upstream publishes no build for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "sprite";
  version = info.version;

  src = fetchurl {
    url = "https://sprites-binaries.t3.storage.dev/client/${finalAttrs.version}/sprite-${entry.asset}";
    inherit (entry) hash;
  };

  dontUnpack = true;

  # The binary is Go 1.24 built with CGO_ENABLED=1, so the Linux builds link
  # glibc dynamically and need their interpreter and rpath rewritten. The macOS
  # build links only /usr/lib and system frameworks, which need no patching.
  nativeBuildInputs = [ makeWrapper ] ++ lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/sprite
    # Suppress the passive "upgrade available" notice. A store copy cannot
    # replace itself, so the notice is never actionable in place. Whether the
    # current binary honours this variable is UNVERIFIED: an older build
    # documented UPGRADE_CHECK=true as a cache bypass, and the current build
    # documents no environment variable at all.
    wrapProgram $out/bin/sprite --set UPGRADE_CHECK false
    runHook postInstall
  '';

  # `sprite --version` probes for a config directory, so give it a writable HOME.
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckProgramArg = "--version";
  versionCheckKeepEnvironment = [ "HOME" ];
  doInstallCheck = true;

  meta = {
    description = "CLI for sprites.dev, stateful sandbox environments with checkpoint and restore";
    homepage = "https://sprites.dev";
    downloadPage = "https://docs.sprites.dev/cli/installation/";
    # Upstream publishes no licence for this binary. The Fly.io terms of
    # service grant no redistribution right and forbid sublicensing, so
    # `unfree` (redistributable = false) is the supportable call.
    # `unfreeRedistributable` would claim a permission nobody granted.
    # Consequence: never push this derivation to a public binary cache.
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "sprite";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
