# Home Manager module for DeepSeek Harness (`dsh`).
#
# This module models DSH's file layout, configuration layering, and
# ownership boundaries under `$DSH_HOME`. YAML content is always a plain
# Nix value; the Cordis/DSH schemas are validated by DSH itself at runtime.
# The module only enforces invariants it actually owns: path safety, name
# formats, file conflicts, and the Node package output contract of profile
# dependencies.
#
# DSH-owned, never managed here: `settings.yaml`, `.credentials.yaml`,
# `.env`, the profile root `cordis.yml` (rewritten by DSH on every boot),
# and the shared `$DSH_HOME/profiles/node_modules` fallback DSH heals at
# boot. Declared profiles must not be mutated through `dsh plugin` (pnpm
# would write through the read-only store links and create a second source
# of truth).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.deepseek-harness;
  types = lib.types;
  yamlType = (pkgs.formats.yaml { }).type;
  yamlLib = import ../lib/yaml.nix { inherit lib pkgs; };

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

  # npm package-name syntax (scoped or unscoped), matching npm's own rules.
  npmNamePattern = "^(@[a-z0-9~*-][a-z0-9*._~-]*/)?[a-z0-9~*-][a-z0-9*._~-]*$";

  sourceExists = source: builtins.pathExists source;
  sourceIsDirectory = source: sourceExists source && lib.pathIsDirectory source;
  sourceIsFile = source: sourceExists source && lib.filesystem.pathIsRegularFile source;

  uniqueCaseInsensitive = names: lib.length (lib.unique (map lib.toLower names)) == lib.length names;

  # A relative, normalized, single-segment-safe path key (no absolute path,
  # no backslash, no empty, ".", or ".." segments).
  relativePathKeyValid =
    key:
    key != ""
    && !lib.hasPrefix "/" key
    && !lib.hasSuffix "/" key
    && !lib.hasInfix "\\" key
    && lib.all (segment: segment != "" && segment != "." && segment != "..") (lib.splitString "/" key);

  # No key may be a path prefix of another key, since both would map onto
  # overlapping `home.file` targets.
  filesConflict =
    keys:
    lib.any (
      key:
      lib.any (
        other: key != other && (lib.hasPrefix "${key}/" other || lib.hasPrefix "${other}/" key)
      ) keys
    ) keys;

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

  profileFiles = name: profile: {
    "${dshHomeRelative}/profiles/${name}/package.json".text = "${
      builtins.toJSON {
        name = "dsh-profile-${name}";
        private = true;
        dependencies = lib.mapAttrs (_: _: "*") profile.dependencies;
        dsh = {
          profile = {
            bundles = profile.bundles;
          };
        };
      }
    }\n";

    "${dshHomeRelative}/profiles/${name}/cordis.patch.yml".source =
      yamlLib.generate "cordis.patch.yml" profile.cordisPatch;
  };

  profileDependencyFiles =
    name: profile:
    lib.concatMapAttrs (depName: dep: {
      "${dshHomeRelative}/profiles/${name}/node_modules/${depName}" = {
        source = "${dep}/lib/node_modules/${depName}";
        recursive = true;
      };
    }) profile.dependencies;
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
      type = types.nullOr types.path;
      default = null;
      example = lib.literalExpression "./AGENTS.md";
      description = ''
        The user-global `$DSH_HOME/AGENTS.md`. Inline content can be passed
        as a derivation, e.g. `pkgs.writeText "AGENTS.md" '''...'''`.
      '';
    };

    cordisPatch = lib.mkOption {
      type = types.nullOr yamlType;
      default = null;
      example = lib.literalExpression ''
        [
          {
            id = "hmr";
            disabled = true;
          }
        ]
      '';
      description = ''
        The global `$DSH_HOME/cordis.patch.yml` composition layer, applied
        over every profile's own layer. A `null` value means Home Manager
        does not own the file.
      '';
    };

    skills = lib.mkOption {
      type = types.attrsOf types.path;
      default = { };
      example = lib.literalExpression ''
        {
          j-space = ./skills/j-space;
        }
      '';
      description = ''
        Explicit skills under `$DSH_HOME/skills`. A directory value is
        linked as `skills/<name>/`; a regular file value is linked as
        `skills/<name>/SKILL.md`. The effective skill id is the `name` in
        the SKILL.md frontmatter, which DSH validates at runtime; the
        attribute name only picks the directory segment.
      '';
    };

    agentPresets = lib.mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            agentCordis = lib.mkOption {
              type = yamlType;
              description = ''
                The preset composition, written to `agent.cordis.yml`. Use
                `dsh-nix.lib.yamlTag` for `!!js` expressions.
              '';
            };

            preset = lib.mkOption {
              type = types.nullOr yamlType;
              default = null;
              description = ''
                Optional `preset.yml` display metadata. DSH defines its
                accepted fields; unknown fields are DSH's to ignore.
              '';
            };

            files = lib.mkOption {
              type = types.attrsOf types.path;
              default = { };
              description = ''
                Additional preset resources, keyed by a safe relative path
                inside the preset directory (e.g. `"skills/foo"`). Keys
                must not be `agent.cordis.yml` or `preset.yml`, and no key
                may be a path prefix of another key.
              '';
            };
          };
        }
      );
      default = { };
      example = lib.literalExpression ''
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
      '';
      description = ''
        Explicit user presets under `$DSH_HOME/.agent-presets`. Preset IDs
        must match `^[a-z0-9][a-z0-9-]*$` and must not reuse a shipped
        preset ID (DSH silently shadows such presets with its own).
      '';
    };

    profiles = lib.mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            dependencies = lib.mkOption {
              type = types.attrsOf types.package;
              default = { };
              example = lib.literalExpression ''
                {
                  "dsh-context" = dshContext;
                  "@chaoset/sandbox-extra-roots" = sandboxExtraRoots;
                }
              '';
              description = ''
                External Node packages of this profile, keyed by npm
                package name. Each package must expose
                `''${pkg}/lib/node_modules/<name>/` (the `buildNpmPackage`
                layout); it is linked into the profile's `node_modules` as
                a read-only store tree. Build details (lockfiles, fetchers,
                build scripts) belong to the package derivation, not to
                this module. In-box bundle names always resolve from the
                DSH installation first, so a dependency whose name collides
                with an installed package is shadowed for bundle resolution.
              '';
            };

            bundles = lib.mkOption {
              type = types.listOf (types.addCheck types.str (bundle: bundle != ""));
              description = "Ordered package names in `dsh.profile.bundles`.";
            };

            cordisPatch = lib.mkOption {
              type = yamlType;
              default = [ ];
              description = ''
                The profile-local `cordis.patch.yml` layer, applied after
                every bundle layer and before the global
                {option}`programs.deepseek-harness.cordisPatch`.
              '';
            };
          };
        }
      );
      default = { };
      example = lib.literalExpression ''
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
      '';
      description = ''
        Explicit Home Manager-managed profiles under `$DSH_HOME/profiles`.
        A declared profile is fully owned by Home Manager (`package.json`,
        `cordis.patch.yml`, `node_modules`); do not run `dsh plugin` on it.
        Undeclared profiles keep DSH's native pnpm-backed management.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = dshHomeValid;
        message = "programs.deepseek-harness.dshHome must be a normalized absolute descendant of home.homeDirectory.";
      }
    ]
    ++ lib.mapAttrsToList (name: _: {
      assertion = builtins.match "^[a-z0-9]+(-[a-z0-9]+)*$" name != null;
      message = "programs.deepseek-harness.skills.${name}: the attribute name must match ^[a-z0-9]+(-[a-z0-9]+)*$; it only picks the directory segment under $DSH_HOME/skills.";
    }) cfg.skills
    ++ lib.mapAttrsToList (name: source: {
      assertion = !sourceIsDirectory source || sourceIsFile (source + "/SKILL.md");
      message = "programs.deepseek-harness.skills.${name}: a directory source must contain a regular SKILL.md file.";
    }) cfg.skills
    ++ [
      {
        assertion = uniqueCaseInsensitive (lib.attrNames cfg.agentPresets);
        message = "programs.deepseek-harness.agentPresets IDs must be unique case-insensitively.";
      }
    ]
    ++ lib.mapAttrsToList (id: _: {
      assertion = builtins.match "^[a-z0-9][a-z0-9-]*$" id != null && !lib.elem id shippedPresetIds;
      message = "programs.deepseek-harness.agentPresets.${id}: preset IDs must match ^[a-z0-9][a-z0-9-]*$ and must not reuse a shipped preset ID (DSH would silently shadow it).";
    }) cfg.agentPresets
    ++ lib.concatMap (
      id:
      let
        files = lib.attrNames cfg.agentPresets.${id}.files;
      in
      [
        {
          assertion = lib.all relativePathKeyValid files;
          message = "programs.deepseek-harness.agentPresets.${id}.files: keys must be safe relative paths without absolute, backslash, empty, '.', or '..' segments.";
        }
        {
          assertion = lib.all (
            key:
            !lib.elem (lib.toLower key) [
              "agent.cordis.yml"
              "preset.yml"
            ]
          ) files;
          message = "programs.deepseek-harness.agentPresets.${id}.files: keys must not be agent.cordis.yml or preset.yml (case-insensitively).";
        }
        {
          assertion = !filesConflict files;
          message = "programs.deepseek-harness.agentPresets.${id}.files: no key may be a path prefix of another key.";
        }
      ]
    ) (lib.attrNames cfg.agentPresets)
    ++ [
      {
        assertion = lib.all profileNameValid profileNames;
        message = "programs.deepseek-harness.profiles names must be non-empty, contain no slash or backslash, and not be '.', '..', or 'node_modules'.";
      }
      {
        assertion = uniqueCaseInsensitive profileNames;
        message = "programs.deepseek-harness.profiles names must be unique case-insensitively.";
      }
    ]
    ++ lib.mapAttrsToList (name: profile: {
      assertion = lib.all (depName: builtins.match npmNamePattern depName != null) (
        lib.attrNames profile.dependencies
      );
      message = "programs.deepseek-harness.profiles.${name}.dependencies: keys must be valid npm package names.";
    }) cfg.profiles
    ++ lib.mapAttrsToList (name: profile: {
      assertion = name != "headless" || profile.bundles != legacyHeadlessBundles;
      message = "programs.deepseek-harness.profiles.headless cannot use the legacy installation-owned headless bundle tuple because DSH rewrites it in place at boot, which would write through the read-only store link.";
    }) cfg.profiles;

    home.sessionVariables.DSH_HOME = cfg.dshHome;
    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file =
      (lib.optionalAttrs (cfg.agentsFile != null) {
        "${dshHomeRelative}/AGENTS.md".source = cfg.agentsFile;
      })
      // (lib.optionalAttrs (cfg.cordisPatch != null) {
        "${dshHomeRelative}/cordis.patch.yml".source = yamlLib.generate "cordis.patch.yml" cfg.cordisPatch;
      })
      // (lib.concatMapAttrs (
        name: source:
        if sourceIsDirectory source then
          {
            "${dshHomeRelative}/skills/${name}" = {
              inherit source;
              recursive = true;
            };
          }
        else
          {
            "${dshHomeRelative}/skills/${name}/SKILL.md".source = source;
          }
      ) cfg.skills)
      // (lib.concatMapAttrs (
        id: preset:
        {
          "${dshHomeRelative}/.agent-presets/${id}/agent.cordis.yml".source =
            yamlLib.generate "agent.cordis.yml" preset.agentCordis;
        }
        // (lib.optionalAttrs (preset.preset != null) {
          "${dshHomeRelative}/.agent-presets/${id}/preset.yml".source =
            yamlLib.generate "preset.yml" preset.preset;
        })
        // (lib.concatMapAttrs (key: source: {
          "${dshHomeRelative}/.agent-presets/${id}/${key}" = {
            inherit source;
            recursive = sourceIsDirectory source;
          };
        }) preset.files)
      ) cfg.agentPresets)
      // (lib.concatMapAttrs (
        name: profile: profileFiles name profile // profileDependencyFiles name profile
      ) cfg.profiles);
  };
}
