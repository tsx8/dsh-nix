# DeepSeek Harness options

Auto-generated from the option declarations in `modules/home-manager.nix` and `modules/nixos.nix`.
CI keeps this file up to date on every push.
Regenerate locally with: `nix build .#docs -o docs-build && cp docs-build/options.md docs/options.md`.

## Home Manager

## programs\.deepseek-harness\.enable



Whether to enable DeepSeek Harness user configuration\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.package



The deepseek-harness package to use\. Set this to ` null ` when DSH is installed by NixOS or another
package manager\. It only controls whether Home Manager installs
DSH into ` home.packages `; the effective runtime is always
` programs.deepseek-harness.finalPackage `\.



*Type:*
null or package



*Default:*

```nix
pkgs.callPackage ../packages/deepseek-harness/package.nix { }
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.agentPresets

Explicit user presets under ` $DSH_HOME/.agent-presets `\. Preset IDs
must match ` ^[a-z0-9][a-z0-9-]*$ `\. A preset whose ID collides with a
shipped preset is shadowed by DSH’s own root precedence\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  my-code = {
    agentCordis = [
      {
        id = "persona";
        name = "@deepseek-ai/dsh-persona";
        config.text = "You are a software engineering assistant.";
      }
    ];
    preset = {
      name = "My Code";
      description = "Custom coding preset.";
      order = 10;
    };
    files."skills/local-helper" = ./skills/local-helper;
  };
}

```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.agentPresets\.\<name>\.agentCordis



The preset composition, written to ` agent.cordis.yml `\. Use
` dsh-nix.lib.yamlTag ` for ` !!js ` expressions\.



*Type:*
YAML 1\.1 value



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.agentPresets\.\<name>\.files



Additional preset resources, keyed by a safe relative path
inside the preset directory (e\.g\. ` "skills/foo" `)\. Keys
must not be ` agent.cordis.yml ` or ` preset.yml `, and no key
may be a path prefix of another key\.



*Type:*
attribute set of absolute path



*Default:*

```nix
{ }
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.agentPresets\.\<name>\.preset



Optional ` preset.yml ` display metadata\. DSH defines its
accepted fields; unknown fields are DSH’s to ignore\.



*Type:*
null or YAML 1\.1 value



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.agentsFile



The user-global ` $DSH_HOME/AGENTS.md `\. Inline content can be passed
as a derivation, e\.g\. ` pkgs.writeText "AGENTS.md" ''...'' `\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
./AGENTS.md
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.cordisPatch



The global ` $DSH_HOME/cordis.patch.yml ` composition layer, applied
over every profile’s own layer\. A ` null ` value means Home Manager
does not own the file\.



*Type:*
null or YAML 1\.1 value



*Default:*

```nix
null
```



*Example:*

```nix
[
  {
    id = "hmr";
    disabled = true;
  }
]

```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.dshHome



Absolute, normalized directory used as ` DSH_HOME `\. It must be a
strict descendant of ` home.homeDirectory `\.



*Type:*
string



*Default:*

```nix
config.home.homeDirectory + "/.dsh"
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.finalPackage



The DSH package declared profiles are built against, resolved with
fixed precedence: the ` programs.deepseek-harness.package `
option, then the package of an enabled NixOS module
` programs.deepseek-harness ` (when this Home Manager configuration is
evaluated as a NixOS module), then ` null `\. ` null ` means no DSH
runtime is known; declaring profiles then fails evaluation\.



*Type:*
null or package *(read only)*



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.profiles



Explicit Home Manager-managed profiles under ` $DSH_HOME/profiles `\.
A declared profile is fully owned by Home Manager (` package.json `,
` pnpm-workspace.yaml `, ` cordis.patch.yml `, ` node_modules `); do not
run ` dsh plugin ` on it\. Undeclared profiles keep DSH’s native
pnpm-backed management\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  web = {
    dependencies = {
      "dsh-llm-codex" = "0.1.2";
    };
    bundles = [
      "@deepseek-ai/dsh-base"
      "@deepseek-ai/dsh-web-app"
      "dsh-llm-codex"
    ];
    cordisPatch = [
      {
        id = "some-profile-override";
        config.foo = "bar";
      }
    ];
    pnpmDepsHash = "sha256-...";
  };
}

```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.profiles\.\<name>\.bundles



Ordered package names in ` dsh.profile.bundles `\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.profiles\.\<name>\.cordisPatch



The profile-local ` cordis.patch.yml ` layer, applied after
every bundle layer and before the global
` programs.deepseek-harness.cordisPatch `\. Changing
this layer never rebuilds the profile’s dependency runtime\.



*Type:*
YAML 1\.1 value



*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.profiles\.\<name>\.dependencies



The profile’s external Node packages, keyed by npm package
name, with the pnpm spec written verbatim into
` package.json.dependencies ` (e\.g\. ` "^1.2.0" `,
` "workspace:*" `, ` "github:user/repo" `)\. The dependency
closure is resolved and fetched by ` fetchPnpmDeps `; the hash
goes in ` programs.deepseek-harness.profiles.<name>.pnpmDepsHash `\.
DSH’s in-box packages are never needed here: they resolve
from the installation first\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  "dsh-context" = "0.13.0";
  "dsh-llm-codex" = "0.1.2";
}

```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.profiles\.\<name>\.pnpmDepsHash



The fixed-output hash of the profile’s dependency closure
(resolved lockfile + fetched pnpm store)\. Must be ` null `
when ` programs.deepseek-harness.profiles.<name>.dependencies `
is empty\. When it is ` null ` with dependencies, the build
fails once with the real ` got: ` hash — copy it back here\.
See the README for the exact workflow\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.profiles\.\<name>\.pnpmWorkspace



The profile’s ` pnpm-workspace.yaml `\. ` null ` keeps the
canonical workspace the current DSH generates on profile
initialization\. A non-` null ` value completely replaces it —
e\.g\. ` allowBuilds ` controls which dependency build scripts
run during the profile build\. Registry and prebuilt Git/URL
dependencies are fully supported; a Git-hosted dependency
whose distributable package must first be produced by a
source-only ` prepare ` step depends on pnpm/fetchPnpmDeps
support for that source form and is not guaranteed\.



*Type:*
null or YAML 1\.1 value



*Default:*

```nix
null
```



*Example:*

```nix
{
  packages = [ "." ];
  nodeLinker = "hoisted";
  autoInstallPeers = false;
  allowBuilds."<package>" = true;
}

```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.skills



Explicit skills under ` $DSH_HOME/skills `\. A directory value is
linked as ` skills/<name>/ `; a regular file value is linked as
` skills/<name>/SKILL.md `\. The effective skill id is the ` name ` in
the SKILL\.md frontmatter, which DSH validates at runtime; the
attribute name only picks the directory segment\.



*Type:*
attribute set of absolute path



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  j-space = ./skills/j-space;
}

```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## NixOS

## programs\.deepseek-harness\.enable

Whether to enable DeepSeek Harness\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [modules/nixos\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/nixos.nix)



## programs\.deepseek-harness\.package



The DeepSeek Harness package installed into the system environment\.
Home Manager’s ` programs.deepseek-harness.finalPackage ` resolves to
this package when its own ` package ` is ` null `\.



*Type:*
package



*Default:*

```nix
pkgs.callPackage ../packages/deepseek-harness/package.nix { }
```

*Declared by:*
 - [modules/nixos\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/nixos.nix)


