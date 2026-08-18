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

Explicit user presets under ` $DSH_HOME/.agent-presets `\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```



*Example:*

```nix
{ my-preset.source = ./my-preset; }
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.agentPresets\.\<name>\.source



Preset directory containing ` agent.cordis.yml `\.



*Type:*
absolute path

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.agentsFile



The user-global ` $DSH_HOME/AGENTS.md `\. Exactly one of
` programs.deepseek-harness.agentsFile.text ` or
` programs.deepseek-harness.agentsFile.source ` must be set\.



*Type:*
null or (submodule)



*Default:*

```nix
null
```



*Example:*

```nix
{
  text = ''
    # Project agents
    Instructions shared by all agents in this project.
  '';
}
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.agentsFile\.source



Path to the source file or directory\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.agentsFile\.text



Inline file contents\.



*Type:*
null or strings concatenated with “\\n”



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.cordisPatch



The global ` $DSH_HOME/cordis.patch.yml `\. Exactly one of
` structured `, ` text `, or ` source ` must be set\.



*Type:*
null or (submodule)



*Default:*

```nix
null
```



*Example:*

```nix
{
  structured = [
    {
      disabled = true;
      id = "hmr";
    }
  ];
}
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.cordisPatch\.source



Path to a complete Cordis patch YAML file\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.cordisPatch\.structured



A structured Cordis patch list\. Use ` text ` or
` source ` for YAML tags such as ` !!js `\.



*Type:*
null or (list of attribute set of (YAML 1\.1 value))



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.cordisPatch\.text



Complete Cordis patch YAML text\.



*Type:*
null or strings concatenated with “\\n”



*Default:*

```nix
null
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



Explicit immutable profiles under ` $DSH_HOME/profiles `\. The module
owns only ` package.json ` and ` cordis.patch.yml ` inside each declared
profile\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  work = {
    bundles = [
      "@deepseek-ai/dsh-base"
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



Profile-local ` cordis.patch.yml `\. A null value generates the
valid empty patch list ` [] `\.



*Type:*
null or (submodule)



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.profiles\.\<name>\.cordisPatch\.source



Path to a complete Cordis patch YAML file\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.profiles\.\<name>\.cordisPatch\.structured



A structured Cordis patch list\. Use ` text ` or
` source ` for YAML tags such as ` !!js `\.



*Type:*
null or (list of attribute set of (YAML 1\.1 value))



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.profiles\.\<name>\.cordisPatch\.text



Complete Cordis patch YAML text\.



*Type:*
null or strings concatenated with “\\n”



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.skills



Explicit skills under ` $DSH_HOME/skills `\. Each attribute must set
exactly one of ` text ` or ` source `; a source may be a
` SKILL.md ` file or a directory containing one\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  hello = {
    text = ''
      ---
      name: hello
      description: A sample skill.
      ---
      
      # Hello
    '';
  };
}
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.skills\.\<name>\.source



Path to the source file or directory\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)



## programs\.deepseek-harness\.skills\.\<name>\.text



Inline file contents\.



*Type:*
null or strings concatenated with “\\n”



*Default:*

```nix
null
```

*Declared by:*
 - [modules/home-manager\.nix](https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix)


