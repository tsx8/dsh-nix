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

```nix
{
  homeConfigurations.example = home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    modules = [
      dsh-nix.homeModules.default
      {
        programs.deepseek-harness = {
          enable = true;
          skills.hello.text = ''
            ---
            name: hello
            description: A sample skill.
            ---

            # Hello
          '';
        };
      }
    ];
  };
}
```

The module installs `dsh` and generates `$DSH_HOME` (default `~/.dsh`) from
`skills`, `agentPresets`, `profiles`, `agentsFile`, and `cordisPatch`.
All module options are documented in [docs/options.md](docs/options.md)
(auto-generated from the option declarations).

See all outputs with `nix flake show github:tsx8/dsh-nix`.

## License

MIT
