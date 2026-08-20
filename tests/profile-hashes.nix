# Fixed-output hashes of the fixture profiles' dependency closures, per build
# system and per profile:
#
#   fixture  dsh-llm-codex from Git (github:NOirBRight/dsh-llm-codex pinned to
#            the v0.2.5 commit ac5866543ccd44c75a96ba779629ac7a47fc1f50), the
#            non-registry regression profile.
#   registry dsh-llm-codex 0.1.2 from the npm registry, the registry-spec
#            coverage profile.
#
# Each closure is resolved and fetched with `fetchPnpmDeps fetcherVersion = 4`
# using the DSH-paired pnpm; the hash covers the resolved `pnpm-lock.yaml`
# plus the fetched pnpm store.
#
# The hash is expected to be identical across systems: `--force` fetches every
# package in the lockfile (all platform variants), the lockfile is resolved
# platform-independently, the store index DB holds only the sorted
# `package_index` table with `checkedAt` normalized to 0, and the tarball is
# reproduced with a fixed mtime. The map is kept per system anyway so a
# platform that ever differs can carry its own hash without re-litigating the
# structure.
#
# Obtain or refresh a hash: set `pnpmDepsHash = null` (the module then uses
# `lib.fakeHash`), build, and copy the `got: sha256-...` from the failed
# fixed-output build.
{
  x86_64-linux = {
    fixture = "sha256-TAQiJ4iDWSzPxdn2s2msReTsoXZO7y4xI/qTBSOwsp4=";
    registry = "sha256-nHloXiNvKb1UjZ/lbqpIV8IIV7A3jjSeXDC7yqavKC0=";
  };
  aarch64-linux = {
    fixture = "sha256-TAQiJ4iDWSzPxdn2s2msReTsoXZO7y4xI/qTBSOwsp4=";
    registry = "sha256-nHloXiNvKb1UjZ/lbqpIV8IIV7A3jjSeXDC7yqavKC0=";
  };
  aarch64-darwin = {
    fixture = "sha256-TAQiJ4iDWSzPxdn2s2msReTsoXZO7y4xI/qTBSOwsp4=";
    registry = "sha256-nHloXiNvKb1UjZ/lbqpIV8IIV7A3jjSeXDC7yqavKC0=";
  };
}
