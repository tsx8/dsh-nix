# dsh-nix

Nix flake with a package and a Home Manager module for
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
              "dsh-context" = dshContext; # Nix package exposing lib/node_modules/dsh-context
            };
            bundles = [
              "@deepseek-ai/dsh-base"
              "@deepseek-ai/dsh-web-app"
              "dsh-context"
            ];
            cordisPatch = [ ];
          };
        };
      }
    ];
  };
}
```

Ownership boundaries:

- Home Manager owns only what is declared: `AGENTS.md`,
  `cordis.patch.yml`, `skills/`, `.agent-presets/`, and declared
  `profiles/` (including each profile's `node_modules`). These are
  read-only store links.
- DSH owns `settings.yaml`, `.credentials.yaml`, `.env`, the per-profile
  `cordis.yml` root config (rewritten on every boot), and the shared
  `$DSH_HOME/profiles/node_modules` fallback. Manage these outside this
  module if needed (e.g. with SOPS); `.credentials.yaml` must stay `0600`.
- Do not run `dsh plugin` on a declared profile: pnpm writes through the
  read-only links and creates a second source of truth. Undeclared
  profiles keep DSH's native pnpm-backed management.

All module options are documented in [docs/options.md](docs/options.md)
(auto-generated from the option declarations).

See all outputs with `nix flake show github:tsx8/dsh-nix`.

## License

MIT
