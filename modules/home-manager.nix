{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.deepseek-harness;
  types = lib.types;
  yaml = pkgs.formats.yaml { };

  defaultPackage = pkgs.callPackage ../packages/deepseek-harness/package.nix { };
  shippedPresetIds = [
    "standard"
    "code"
    "minimal"
    "cordis"
  ];
  legacyHeadlessBundles = [
    "@deepseek-ai/dsh-base"
    "@deepseek-ai/dsh-web-app"
    "@deepseek-ai/dsh-headless"
  ];

  cordisPatchType = types.submodule {
    options = {
      structured = lib.mkOption {
        type = types.nullOr (types.listOf (types.attrsOf yaml.type));
        default = null;
        description = ''
          A structured Cordis patch list. Use {option}`text` or
          {option}`source` for YAML tags such as `!!js`.
        '';
      };

      text = lib.mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Complete Cordis patch YAML text.";
      };

      source = lib.mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a complete Cordis patch YAML file.";
      };
    };
  };

  textSourceType = types.submodule {
    options = {
      text = lib.mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Inline file contents.";
      };

      source = lib.mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the source file or directory.";
      };
    };
  };

  exactlyOne = values: lib.length (lib.filter (value: value != null) values) == 1;
  exactlyOneCordis =
    value:
    exactlyOne [
      value.structured
      value.text
      value.source
    ];

  sourceExists = source: builtins.pathExists source;
  sourceIsDirectory = source: sourceExists source && lib.pathIsDirectory source;
  sourceIsFile = source: sourceExists source && lib.filesystem.pathIsRegularFile source;

  cordisFile =
    name: value:
    if value.structured != null then
      yaml.generate name value.structured
    else if value.text != null then
      pkgs.writeText name value.text
    else
      value.source;

  textSourceFile =
    name: value: if value.text != null then pkgs.writeText name value.text else value.source;

  homeDirectory = lib.removeSuffix "/" config.home.homeDirectory;
  dshHomePrefix = "${homeDirectory}/";
  dshHomeRelative = lib.removePrefix dshHomePrefix cfg.dshHome;
  dshHomeSegments = lib.splitString "/" dshHomeRelative;
  dshHomeValid =
    cfg.dshHome != homeDirectory
    && lib.hasPrefix dshHomePrefix cfg.dshHome
    && lib.all (segment: segment != "" && segment != "." && segment != "..") dshHomeSegments;

  profileNames = lib.attrNames cfg.profiles;
  profileNameValid =
    name:
    name != ""
    && !lib.elem name [
      "."
      ".."
      "node_modules"
    ]
    && !lib.hasInfix "/" name
    && !lib.hasInfix "\\" name;

  profilePatchFile =
    profile:
    if profile.cordisPatch == null then
      pkgs.writeText "cordis.patch.yml" "[]\n"
    else
      cordisFile "cordis.patch.yml" profile.cordisPatch;

  profileFiles = name: profile: {
    "${dshHomeRelative}/profiles/${name}/package.json".text = "${
      builtins.toJSON {
        name = "dsh-profile-${name}";
        private = true;
        dependencies = { };
        dsh = {
          profile = {
            bundles = profile.bundles;
          };
        };
      }
    }\n";

    "${dshHomeRelative}/profiles/${name}/cordis.patch.yml".source = profilePatchFile profile;
  };
in
{
  options.programs.deepseek-harness = {
    enable = lib.mkEnableOption "DeepSeek Harness user configuration";

    package =
      (lib.mkPackageOption pkgs "deepseek-harness" {
        nullable = true;
        default = null;
        extraDescription = ''
          The default is the same-repo package built with this module's
          `pkgs`. Set this to `null` when DSH is installed by NixOS or
          another package manager. Configuration generation does not depend
          on this package.
        '';
      })
      // {
        default = defaultPackage;
        defaultText = lib.literalExpression "pkgs.callPackage ../packages/deepseek-harness/package.nix { }";
      };

    dshHome = lib.mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.dsh";
      defaultText = lib.literalExpression ''config.home.homeDirectory + "/.dsh"'';
      description = ''
        Absolute, normalized directory used as `DSH_HOME`. It must be a
        strict descendant of {option}`home.homeDirectory`.
      '';
    };

    agentsFile = lib.mkOption {
      type = types.nullOr textSourceType;
      default = null;
      example = {
        text = ''
          # Project agents
          Instructions shared by all agents in this project.
        '';
      };
      description = ''
        The user-global `$DSH_HOME/AGENTS.md`. Exactly one of
        {option}`programs.deepseek-harness.agentsFile.text` or
        {option}`programs.deepseek-harness.agentsFile.source` must be set.
      '';
    };

    cordisPatch = lib.mkOption {
      type = types.nullOr cordisPatchType;
      default = null;
      example = {
        structured = [
          {
            id = "hmr";
            disabled = true;
          }
        ];
      };
      description = ''
        The global `$DSH_HOME/cordis.patch.yml`. Exactly one of
        {option}`structured`, {option}`text`, or {option}`source` must be set.
      '';
    };

    skills = lib.mkOption {
      type = types.attrsOf textSourceType;
      default = { };
      example = {
        hello.text = ''
          ---
          name: hello
          description: A sample skill.
          ---

          # Hello
        '';
      };
      description = ''
        Explicit skills under `$DSH_HOME/skills`. Each attribute must set
        exactly one of {option}`text` or {option}`source`; a source may be a
        `SKILL.md` file or a directory containing one.
      '';
    };

    agentPresets = lib.mkOption {
      type = types.attrsOf (
        types.submodule {
          options.source = lib.mkOption {
            type = types.path;
            description = "Preset directory containing `agent.cordis.yml`.";
          };
        }
      );
      default = { };
      example = lib.literalExpression "{ my-preset.source = ./my-preset; }";
      description = "Explicit user presets under `$DSH_HOME/.agent-presets`.";
    };

    profiles = lib.mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            bundles = lib.mkOption {
              type = types.listOf (types.addCheck types.str (bundle: bundle != ""));
              description = "Ordered package names in `dsh.profile.bundles`.";
            };

            cordisPatch = lib.mkOption {
              type = types.nullOr cordisPatchType;
              default = null;
              description = ''
                Profile-local `cordis.patch.yml`. A null value generates the
                valid empty patch list `[]`.
              '';
            };
          };
        }
      );
      default = { };
      example = {
        work.bundles = [ "@deepseek-ai/dsh-base" ];
      };
      description = ''
        Explicit immutable profiles under `$DSH_HOME/profiles`. The module
        owns only `package.json` and `cordis.patch.yml` inside each declared
        profile.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = dshHomeValid;
        message = "programs.deepseek-harness.dshHome must be a normalized absolute descendant of home.homeDirectory.";
      }
      {
        assertion =
          !(config.home.sessionVariables ? DSH_AGENTS_HOME)
          || config.home.sessionVariables.DSH_AGENTS_HOME != "";
        message = "home.sessionVariables.DSH_AGENTS_HOME must not be empty when DeepSeek Harness is enabled.";
      }
      {
        assertion =
          cfg.agentsFile == null
          || exactlyOne [
            cfg.agentsFile.text
            cfg.agentsFile.source
          ];
        message = "programs.deepseek-harness.agentsFile requires exactly one of text or source.";
      }
      {
        assertion =
          cfg.agentsFile == null || cfg.agentsFile.source == null || sourceIsFile cfg.agentsFile.source;
        message = "programs.deepseek-harness.agentsFile.source must be a regular file.";
      }
      {
        assertion = cfg.cordisPatch == null || exactlyOneCordis cfg.cordisPatch;
        message = "programs.deepseek-harness.cordisPatch requires exactly one of structured, text, or source.";
      }
      {
        assertion =
          cfg.cordisPatch == null || cfg.cordisPatch.source == null || sourceIsFile cfg.cordisPatch.source;
        message = "programs.deepseek-harness.cordisPatch.source must be a regular file.";
      }
    ]
    ++ lib.concatMap (name: [
      {
        assertion = builtins.match "^[a-z0-9]+(-[a-z0-9]+)*$" name != null;
        message = "programs.deepseek-harness.skills names must be lowercase kebab-case.";
      }
      {
        assertion = exactlyOne [
          cfg.skills.${name}.text
          cfg.skills.${name}.source
        ];
        message = "programs.deepseek-harness.skills.${name} requires exactly one of text or source.";
      }
      {
        assertion =
          cfg.skills.${name}.source == null
          || sourceIsFile cfg.skills.${name}.source
          || sourceIsDirectory cfg.skills.${name}.source;
        message = "programs.deepseek-harness.skills.${name}.source must be a file or directory.";
      }
      {
        assertion =
          cfg.skills.${name}.source == null
          || !sourceIsDirectory cfg.skills.${name}.source
          || sourceIsFile (cfg.skills.${name}.source + "/SKILL.md");
        message = "programs.deepseek-harness.skills.${name} directory must contain a regular SKILL.md file.";
      }
    ]) (lib.attrNames cfg.skills)
    ++ lib.concatMap (id: [
      {
        assertion = builtins.match "^[a-z0-9][a-z0-9-]*$" id != null && !lib.elem id shippedPresetIds;
        message = "programs.deepseek-harness.agentPresets IDs must match ^[a-z0-9][a-z0-9-]*$ and must not reuse a shipped preset ID.";
      }
      {
        assertion = sourceIsDirectory cfg.agentPresets.${id}.source;
        message = "programs.deepseek-harness.agentPresets.${id}.source must be a directory.";
      }
      {
        assertion = sourceIsFile (cfg.agentPresets.${id}.source + "/agent.cordis.yml");
        message = "programs.deepseek-harness.agentPresets.${id}.source must contain a regular agent.cordis.yml file.";
      }
    ]) (lib.attrNames cfg.agentPresets)
    ++ [
      {
        assertion = lib.all profileNameValid profileNames;
        message = "programs.deepseek-harness.profiles names must be non-empty, contain no slash or backslash, and not be '.', '..', or 'node_modules'.";
      }
      {
        assertion = lib.length (lib.unique (map lib.toLower profileNames)) == lib.length profileNames;
        message = "programs.deepseek-harness.profiles names must be unique case-insensitively.";
      }
    ]
    ++ lib.concatMap (name: [
      {
        assertion =
          cfg.profiles.${name}.cordisPatch == null || exactlyOneCordis cfg.profiles.${name}.cordisPatch;
        message = "programs.deepseek-harness.profiles.${name}.cordisPatch requires exactly one of structured, text, or source.";
      }
      {
        assertion =
          cfg.profiles.${name}.cordisPatch == null
          || cfg.profiles.${name}.cordisPatch.source == null
          || sourceIsFile cfg.profiles.${name}.cordisPatch.source;
        message = "programs.deepseek-harness.profiles.${name}.cordisPatch.source must be a regular file.";
      }
      {
        assertion = name != "headless" || cfg.profiles.${name}.bundles != legacyHeadlessBundles;
        message = "programs.deepseek-harness.profiles.headless cannot use the legacy installation-owned headless bundle tuple because DSH rewrites it at runtime.";
      }
    ]) profileNames;

    home.sessionVariables.DSH_HOME = cfg.dshHome;
    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file =
      (lib.optionalAttrs (cfg.agentsFile != null) {
        "${dshHomeRelative}/AGENTS.md".source = textSourceFile "AGENTS.md" cfg.agentsFile;
      })
      // (lib.optionalAttrs (cfg.cordisPatch != null) {
        "${dshHomeRelative}/cordis.patch.yml".source = cordisFile "cordis.patch.yml" cfg.cordisPatch;
      })
      // (lib.concatMapAttrs (
        name: value:
        if value.source != null && sourceIsDirectory value.source then
          {
            "${dshHomeRelative}/skills/${name}" = {
              source = value.source;
              recursive = true;
            };
          }
        else
          {
            "${dshHomeRelative}/skills/${name}/SKILL.md".source = textSourceFile "SKILL.md" value;
          }
      ) cfg.skills)
      // (lib.concatMapAttrs (id: value: {
        "${dshHomeRelative}/.agent-presets/${id}" = {
          source = value.source;
          recursive = true;
        };
      }) cfg.agentPresets)
      // (lib.concatMapAttrs profileFiles cfg.profiles);
  };
}
