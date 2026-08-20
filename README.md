# dsh-nix

Nix flake with a package, a Home Manager module, and a NixOS module for
[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (`dsh`).

## Installation

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dsh-nix.url = "github:tsx8/dsh-nix";
  };

  outputs = { nixpkgs, home-manager, dsh-nix, ... }: {
    # ...
  };
}
```

Run the package directly:

```console
$ nix run github:tsx8/dsh-nix
```

Packages build for `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`.

## Home Manager

The module models DSH's file layout, configuration layering, and ownership
boundaries under `$DSH_HOME`. YAML content (cordis patches, preset files) is
written as plain Nix values; DSH validates their schemas at runtime.

```nix
{
  homeConfigurations.example = home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    modules = [
      dsh-nix.homeModules.default
      {
        programs.deepseek-harness = {
          enable = true;

          agentsFile = ./dsh/AGENTS.md;

          cordisPatch = [
            {
              id = "hmr";
              disabled = true;
            }
          ];

          skills = {
            j-space = ./dsh/skills/j-space;
          };

          agentPresets.my-code = {
            agentCordis = [
              {
                id = "persona";
                name = "@deepseek-ai/dsh-persona";
                config.text = "You are a software engineering assistant.";
              }
              {
                id = "fs-local";
                name = "@deepseek-ai/dsh-fs-local";
                config.cwd =
                  dsh-nix.lib.yamlTag "js"
                    "process.env.DSH_CWD ?? process.cwd()";
              }
            ];
            preset = {
              name = "My Code";
              description = "Custom coding preset.";
              order = 10;
            };
          };

          profiles.web = {
            dependencies = {
              "dsh-llm-codex" = "0.1.2";
              "dsh-context" = "0.13.0";
            };
            bundles = [
              "@deepseek-ai/dsh-base"
              "@deepseek-ai/dsh-web-app"
              "dsh-llm-codex"
            ];
            cordisPatch = [ ];
            pnpmDepsHash = "sha256-...";
          };
        };
      }
    ];
  };
}
```

### Profile dependencies

`profiles.<name>.dependencies` maps npm package names to pnpm specs, written
verbatim into the profile's `package.json.dependencies`. You never run pnpm,
never maintain `pnpm-lock.yaml`, and never package plugins separately: the
module resolves and fetches the whole dependency closure with
`fetchPnpmDeps` (fetcherVersion 4, the exact pnpm the DSH runtime pairs
with) and installs it offline into a sandboxed profile runtime. DSH's own
in-box packages are never listed here — they resolve from the installation
first.

Adding or upgrading a dependency:

1. Edit `dependencies` (and `bundles` if the plugin is a bundle).
2. Delete `pnpmDepsHash` (or set it to `null`).
3. Run your usual build (`nix build`, `home-manager switch`, ...).
4. The fixed-output build fails and prints `got: sha256-...`.
5. Copy that hash into `pnpmDepsHash`.
6. Build again.

`pnpmWorkspace.allowBuilds` controls which dependency build scripts run during
the profile build. Registry and prebuilt Git/URL dependencies are supported.
Git-hosted dependencies whose distributable package must first be produced by
a source-only `prepare` step (a build needing the repo's own devDependencies)
depend on pnpm/fetchPnpmDeps support for that source form and are not
guaranteed:

```nix
profiles.web = {
  dependencies."my-plugin" = "github:user/my-plugin#v1.2.3"; # pin a commit or tag
  pnpmWorkspace = {
    packages = [ "." ];
    nodeLinker = "hoisted";
    autoInstallPeers = false;
    allowBuilds."<package>" = true; # the exact key pnpm prints
  };
  pnpmDepsHash = "sha256-...";
};
```

Pin Git/URL dependencies to a commit or tag: an unpinned branch like `#main`
resolves differently over time, breaking the fixed-output hash.

`pnpmWorkspace = null` (the default) keeps the canonical
`pnpm-workspace.yaml` the current DSH generates; a non-`null` value fully
replaces it. A profile with no dependencies needs no hash and has no
profile-local `node_modules` — only `package.json` and
`pnpm-workspace.yaml` are deployed.

### Package ownership

`programs.deepseek-harness.package` controls whether Home Manager installs
DSH into `home.packages`. The effective runtime every declared profile is
built against is `programs.deepseek-harness.finalPackage` (read-only):

```text
HM package > NixOS module package > null
```

Set `package = null` when DSH comes from the NixOS module or another package
manager; `finalPackage` then picks up the system package automatically, so
declared profiles still build against the running DSH. Declaring profiles
without any known DSH runtime fails evaluation.

### Ownership boundaries

- Home Manager owns only what is declared: `AGENTS.md`,
  `cordis.patch.yml`, `skills/`, `.agent-presets/`, and declared
  `profiles/` (each profile's `package.json`, `pnpm-workspace.yaml`,
  `node_modules`, and `cordis.patch.yml`). These are read-only store links;
  each profile's `node_modules` is one whole directory symlink into the
  profile runtime, whose parent `profiles/` directory holds the DSH host
  fallback the runtime was built with.
- DSH owns `settings.yaml`, `.credentials.yaml`, `.env`, the per-profile
  `cordis.yml` root config (rewritten on every boot), and the shared
  `$DSH_HOME/profiles/node_modules` fallback it heals at boot. Manage these
  outside this module if needed (e.g. with SOPS); `.credentials.yaml` must
  stay `0600`.
- Do not run `dsh plugin` on a declared profile: pnpm would write through
  the read-only links and create a second source of truth. Undeclared
  profiles keep DSH's native pnpm-backed management.

## NixOS

```nix
{
  nixosConfigurations.example = nixpkgs.lib.nixosSystem {
    modules = [
      dsh-nix.nixosModules.default
      {
        programs.deepseek-harness.enable = true;
      }
    ];
  };
}
```

The NixOS module only installs `programs.deepseek-harness.package` into
`environment.systemPackages`. All user configuration stays under
`$DSH_HOME` and is managed by the Home Manager module, which resolves this
package through its read-only `finalPackage` when its own `package` is
`null`.

All module options are documented in [docs/options.md](docs/options.md)
(auto-generated from the option declarations).

See all outputs with `nix flake show github:tsx8/dsh-nix`.

## License

MIT
