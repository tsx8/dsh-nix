# DeepSeek Harness Home Manager options

Auto-generated from the option declarations in `modules/home-manager.nix`.
CI keeps this file up to date on every push.
Regenerate locally with: `nix build .#docs -o docs-build && cp docs-build/options.md docs/options.md`.

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



The deepseek-harness package to use\. The default is the same-repo package built with this module’s
` pkgs `\. Set this to ` null ` when DSH is installed by NixOS or
another package manager\. Configuration generation does not depend
on this package\.



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
must match ` ^[a-z0-9][a-z0-9-]*$ ` and must not reuse a shipped
preset ID (DSH silently shadows such presets with its own)\.



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



## programs\.deepseek-harness\.profiles



Explicit Home Manager-managed profiles under ` $DSH_HOME/profiles `\.
A declared profile is fully owned by Home Manager (` package.json `,
` cordis.patch.yml `, ` node_modules `); do not run ` dsh plugin ` on it\.
Undeclared profiles keep DSH’s native pnpm-backed management\.



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
      "dsh-context" = dshContext;
    };
    bundles = [
      "@deepseek-ai/dsh-base"
      "@deepseek-ai/dsh-web-app"
      "dsh-context"
    ];
    cordisPatch = [
      {
        id = "some-profile-override";
        config.foo = "bar";
      }
    ];
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
` programs.deepseek-harness.cordisPatch `\.



*Type:*
YAML 1\.1 value



*Default:*

```nix
[ ]
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.profiles\.\<name>\.dependencies



External Node packages of this profile, keyed by npm
package name\. Each package must expose
` ${pkg}/lib/node_modules/<name>/ ` (the ` buildNpmPackage `
layout); it is linked into the profile’s ` node_modules ` as
a read-only store tree\. Build details (lockfiles, fetchers,
build scripts) belong to the package derivation, not to
this module\. In-box bundle names always resolve from the
DSH installation first, so a dependency whose name collides
with an installed package is shadowed for bundle resolution\.



*Type:*
attribute set of package



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  "dsh-context" = dshContext;
  "@chaoset/sandbox-extra-roots" = sandboxExtraRoots;
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


