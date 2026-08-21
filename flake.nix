{
  description = "Nix packaging and Home Manager integration for DeepSeek Harness";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      lib = nixpkgs.lib;

      # nixpkgs-unstable (26.11) has dropped x86_64-darwin, so importing
      # that system throws here; the package's version-adaptive
      # meta.platforms keeps it for consumers on nixpkgs 26.05.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = lib.genAttrs systems;

      mkPkgs = system: import nixpkgs { inherit system; };

      mkPackage = system: (mkPkgs system).callPackage ./packages/deepseek-harness/package.nix { };

      # The fixed-output dependency-closure hashes of the fixture profiles
      # (tests/home-manager.nix), per build system: `fixture` is the Git-hosted
      # regression profile, `registry` the registry-spec coverage profile.
      profileHashes = import ./tests/profile-hashes.nix;

      # Render a module's options as Markdown for docs/options.md without
      # importing the whole module set: a plain evalModules plus small stubs
      # for the options the module consumes.
      mkOptionsDoc =
        {
          system,
          modulePath,
          sectionName,
          stubOptions,
          stubConfig,
        }:
        let
          pkgs = mkPkgs system;
          optionsEval = lib.evalModules {
            specialArgs = { inherit pkgs; };
            modules = [
              modulePath
              {
                options = stubOptions;
                config = stubConfig;
              }
            ];
          };
        in
        (pkgs.nixosOptionsDoc {
          options = {
            programs.deepseek-harness = optionsEval.options.programs.deepseek-harness;
          };
          transformOptions =
            opt:
            opt
            // {
              declarations = map (_: {
                name = sectionName;
                url = "https://github.com/tsx8/dsh-nix/blob/main/${sectionName}";
              }) opt.declarations;
            };
        }).optionsCommonMark;

      homeManagerStub = {
        options = {
          home.homeDirectory = lib.mkOption { type = lib.types.str; };
          home.file = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
          };
          home.packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
          };
          home.sessionVariables = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
          };
          assertions = lib.mkOption {
            type = lib.types.listOf lib.types.unspecified;
            default = [ ];
          };
        };
        config = {
          home.homeDirectory = "/tmp/dsh-docs-home";
          home.file = { };
          home.packages = [ ];
          home.sessionVariables = { };
          assertions = [ ];
        };
      };

      nixosStub = {
        options = {
          environment.systemPackages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [ ];
          };
        };
        config = {
          environment.systemPackages = [ ];
        };
      };

      mkHomeManagerOptionsDoc =
        system:
        mkOptionsDoc {
          inherit system;
          modulePath = ./modules/home-manager.nix;
          sectionName = "modules/home-manager.nix";
          stubOptions = homeManagerStub.options;
          stubConfig = homeManagerStub.config;
        };

      mkNixosOptionsDoc =
        system:
        mkOptionsDoc {
          inherit system;
          modulePath = ./modules/nixos.nix;
          sectionName = "modules/nixos.nix";
          stubOptions = nixosStub.options;
          stubConfig = nixosStub.config;
        };

      mkDocs =
        system:
        let
          pkgs = mkPkgs system;
          hmOptionsMd = mkHomeManagerOptionsDoc system;
          nixosOptionsMd = mkNixosOptionsDoc system;
        in
        pkgs.runCommand "dsh-nix-docs"
          {
            inherit hmOptionsMd nixosOptionsMd;
          }
          ''
            mkdir -p "$out"
            {
              echo "# DeepSeek Harness options"
              echo
              echo "Auto-generated from the option declarations in \`modules/home-manager.nix\` and \`modules/nixos.nix\`."
              echo "CI keeps this file up to date on every push."
              echo "Regenerate locally with: \`nix build .#docs -o docs-build && cp docs-build/options.md docs/options.md\`."
              echo
              echo "## Home Manager"
              echo
              cat "$hmOptionsMd"
              echo
              echo "## NixOS"
              echo
              cat "$nixosOptionsMd"
            } > "$out/options.md"
          '';

      mkChecks =
        system:
        let
          pkgs = mkPkgs system;
          deepseek-harness = mkPackage system;
          profileHash = profileHashes.${system}.fixture;
          registryHash = profileHashes.${system}.registry;
          isLinux = lib.hasSuffix "linux" system;

          # Standalone Home Manager configuration: HM installs DSH itself
          # (same-repo package), so `finalPackage` must equal `package`.
          homeConfiguration = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            extraSpecialArgs = {
              hmPackage = deepseek-harness;
              inherit profileHash registryHash;
              yamlTag = self.lib.yamlTag;
            };
            modules = [
              self.homeModules.deepseek-harness
              ./tests/home-manager.nix
            ];
          };

          homeManagerCheck =
            assert homeConfiguration.config.programs.deepseek-harness.package == deepseek-harness;
            assert homeConfiguration.config.programs.deepseek-harness.finalPackage == deepseek-harness;
            assert
              homeConfiguration.config.home.sessionVariables.DSH_HOME == "/tmp/dsh-test/.local/share/dsh-fixture";
            assert lib.all (item: item.assertion) homeConfiguration.config.assertions;
            pkgs.runCommand "deepseek-harness-home-manager-check"
              {
                activationPackage = homeConfiguration.activationPackage;
                nativeBuildInputs = [ pkgs.jq ];
              }
              ''
                files="$activationPackage/home-files/.local/share/dsh-fixture"

                test -x "$activationPackage/activate"
                test -d "$files"
                cmp ${./tests/fixtures/AGENTS.md} "$files/AGENTS.md"

                test -d "$files/skills/directory-fixture"
                test -f "$files/skills/directory-fixture/SKILL.md"
                test -f "$files/skills/file-fixture/SKILL.md"

                test -f "$files/.agent-presets/my-preset/agent.cordis.yml"
                grep -Fx "    cwd: !!js 'process.env.DSH_CWD ?? process.cwd()'" "$files/.agent-presets/my-preset/agent.cordis.yml"
                grep -Fx 'name: My Preset' "$files/.agent-presets/my-preset/preset.yml"
                test -f "$files/.agent-presets/my-preset/skills/local-helper/SKILL.md"

                manifest="$files/profiles/fixture/package.json"
                jq -e '
                  .name == "dsh-profile-fixture"
                  and .private == true
                  and .dependencies == {"dsh-llm-codex": "github:NOirBRight/dsh-llm-codex#ac5866543ccd44c75a96ba779629ac7a47fc1f50"}
                  and .dsh.profile.bundles == ["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app", "dsh-llm-codex"]
                ' "$manifest"

                # The canonical pnpm workspace generated by DSH's initProfile.
                grep -Fx 'nodeLinker: hoisted' "$files/profiles/fixture/pnpm-workspace.yaml"
                grep -Fx 'autoInstallPeers: false' "$files/profiles/fixture/pnpm-workspace.yaml"

                # The profile node_modules is one whole directory symlink into
                # the runtime store (never recursive per-file links), and the
                # Git-hosted plugin's committed build artifacts are present.
                test -L "$files/profiles/fixture/node_modules"
                test -d "$files/profiles/fixture/node_modules"
                test -f "$files/profiles/fixture/node_modules/dsh-llm-codex/lib/index.js"

                # The profile patch layer is generated independently of the
                # dependency runtime.
                grep -Fx '    model: fixture-model' "$files/profiles/fixture/cordis.patch.yml"

                # The profile root config is DSH-owned: Home Manager never
                # deploys it, and the runtime derivation removed the copy DSH
                # wrote during the build-time dump.
                test ! -e "$files/profiles/fixture/cordis.yml"

                # The registry-spec coverage profile installs from the npm
                # registry; its manifest keeps the plain version spec.
                manifest="$files/profiles/registry/package.json"
                jq -e '
                  .name == "dsh-profile-registry"
                  and .private == true
                  and .dependencies == {"dsh-llm-codex": "0.1.2"}
                  and .dsh.profile.bundles == ["@deepseek-ai/dsh-base", "dsh-llm-codex"]
                ' "$manifest"
                test -L "$files/profiles/registry/node_modules"
                test -d "$files/profiles/registry/node_modules"
                test -f "$files/profiles/registry/node_modules/dsh-llm-codex/lib/index.js"

                # An installation-owned-only profile has no node_modules.
                test -f "$files/profiles/bundle-only/package.json"
                test -f "$files/profiles/bundle-only/pnpm-workspace.yaml"
                test ! -e "$files/profiles/bundle-only/node_modules"

                grep -Fx -- '- disabled: true' "$files/cordis.patch.yml"
                grep -Fx '  id: hmr' "$files/cordis.patch.yml"

                touch "$out"
              '';

          homeManagerRuntimeCheck =
            pkgs.runCommand "deepseek-harness-home-manager-runtime-check"
              {
                activationPackage = homeConfiguration.activationPackage;
                nativeBuildInputs = [ deepseek-harness ];
              }
              ''
                export HOME="$TMPDIR/home"
                export DSH_HOME="$HOME/.local/share/dsh-fixture"
                export DSH_TELEMETRY_DISABLED=1

                mkdir -p "$HOME"

                # Reproduce the activated file layout (real directories
                # holding read-only store symlinks) without Home Manager's
                # `activate` script, whose nix-store sanity checks need a
                # daemon connection that sandboxed builds do not have.
                # `cp -a` preserves the symlinks; home-files mirrors the
                # home root, so it is copied onto $HOME.
                cp -a "$activationPackage/home-files/." "$HOME"
                # `cp -a` preserved the store's read-only directory modes;
                # activation creates writable directories instead.
                find "$HOME" -type d -exec chmod u+w {} +

                test -L "$DSH_HOME/AGENTS.md"

                # The profile's node_modules is a single symlink whose
                # realpath sits inside the runtime derivation, next to the
                # DSH-generated host fallback.
                test -L "$DSH_HOME/profiles/fixture/node_modules"
                runtime="$(realpath "$DSH_HOME/profiles/fixture/node_modules")"
                test -d "$runtime/../node_modules"

                # Boot the real profile, wait for plugin module loading (the
                # web app announces its URL only after the tree settles),
                # keep it alive, then SIGTERM it.
                "${deepseek-harness}/bin/dsh" --profile fixture --port 0 --no-open > "$TMPDIR/dsh-boot.log" 2>&1 &
                bootPid=$!

                url=
                attempt=0
                while [ "$attempt" -lt 200 ]; do
                  url="$(sed -n 's|^dsh web: \(http://127\.0\.0\.1:[0-9][0-9]*\)$|\1|p' "$TMPDIR/dsh-boot.log" | head -n 1)"
                  if [ -n "$url" ]; then
                    break
                  fi
                  if ! kill -0 "$bootPid" 2>/dev/null; then
                    cat "$TMPDIR/dsh-boot.log" >&2
                    exit 1
                  fi
                  sleep 0.1
                  attempt=$((attempt + 1))
                done

                if [ -z "$url" ]; then
                  cat "$TMPDIR/dsh-boot.log" >&2
                  echo "dsh did not finish plugin module loading within 20 seconds" >&2
                  exit 1
                fi

                sleep 1
                if ! kill -0 "$bootPid" 2>/dev/null; then
                  cat "$TMPDIR/dsh-boot.log" >&2
                  exit 1
                fi

                # The profile root config stays a DSH-owned, writable file in
                # the user's home (rewritten on every boot).
                test -f "$DSH_HOME/profiles/fixture/cordis.yml"

                # Host peer resolution from the out-of-tree plugin's real
                # location: the fallback must hand out the DSH installation's
                # own copy of host packages, and the plugin's own dependencies
                # must live inside the profile runtime. dsh-llm-codex
                # (v0.2.5) declares its `@deepseek-ai/*` peers as
                # peer/devDependencies (autoInstallPeers is off), so they come
                # from the DSH host fallback, while its sole runtime
                # dependency `@earendil-works/pi-ai` must be present in the
                # profile runtime itself. pi-ai's package.json exports are
                # import-only, so the runtime check uses realpath rather than
                # CJS require.resolve.
                ${deepseek-harness.passthru.nodejs}/bin/node -e '
                  const { createRequire } = require("node:module");
                  const { realpathSync } = require("node:fs");
                  const runtime = realpathSync(process.env.DSH_HOME + "/profiles/fixture/node_modules");
                  const req = createRequire(runtime + "/dsh-llm-codex/lib/index.js");
                  const host = req.resolve("@deepseek-ai/dsh-home-paths");
                  if (!host.startsWith("${deepseek-harness}")) {
                    console.error("host package resolved outside the DSH installation: " + host);
                    process.exit(1);
                  }
                  const own = realpathSync(runtime + "/@earendil-works/pi-ai");
                  if (!own.startsWith(runtime)) {
                    console.error("plugin dependency resolved outside the profile runtime: " + own);
                    process.exit(1);
                  }
                '

                kill -TERM "$bootPid"
                for _ in $(seq 1 50); do
                  if ! kill -0 "$bootPid" 2>/dev/null; then
                    break
                  fi
                  sleep 0.1
                done
                if kill -0 "$bootPid" 2>/dev/null; then
                  echo "dsh did not exit after SIGTERM" >&2
                  kill -9 "$bootPid"
                  exit 1
                fi

                touch "$out"
              '';

          # NixOS module evaluation: enabling it installs its package into
          # environment.systemPackages.
          nixosModuleEval = lib.evalModules {
            specialArgs = { inherit pkgs; };
            modules = [
              self.nixosModules.deepseek-harness
              {
                programs.deepseek-harness.enable = true;
              }
              {
                options = nixosStub.options;
                config = nixosStub.config;
              }
            ];
          };

          nixosModuleCheck =
            assert lib.elem nixosModuleEval.config.programs.deepseek-harness.package
              nixosModuleEval.config.environment.systemPackages;
            pkgs.runCommand "deepseek-harness-nixos-module-check" { } "touch $out";

          # NixOS -> Home Manager bridge: the NixOS module owns the package,
          # HM sets package = null and must pick it up through finalPackage
          # without installing DSH into home.packages.
          bridgeHomeConfiguration = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            extraSpecialArgs = {
              osConfig = nixosModuleEval.config;
              hmPackage = null;
              inherit profileHash registryHash;
              yamlTag = self.lib.yamlTag;
            };
            modules = [
              self.homeModules.deepseek-harness
              ./tests/home-manager.nix
            ];
          };

          nixosHomeManagerBridgeCheck =
            assert bridgeHomeConfiguration.config.programs.deepseek-harness.package == null;
            assert
              bridgeHomeConfiguration.config.programs.deepseek-harness.finalPackage
              == nixosModuleEval.config.programs.deepseek-harness.package;
            assert !lib.elem deepseek-harness bridgeHomeConfiguration.config.home.packages;
            assert lib.all (item: item.assertion) bridgeHomeConfiguration.config.assertions;
            pkgs.runCommand "deepseek-harness-nixos-bridge-check"
              {
                activationPackage = bridgeHomeConfiguration.activationPackage;
              }
              ''
                test -x "$activationPackage/activate"
                test -L "$activationPackage/home-files/.local/share/dsh-fixture/profiles/fixture/node_modules"
                touch "$out"
              '';
        in
        {
          package = deepseek-harness;
          home-manager = homeConfiguration.activationPackage;
          home-files = homeManagerCheck;
          home-manager-runtime = homeManagerRuntimeCheck;
        }
        // lib.optionalAttrs isLinux {
          nixos-module = nixosModuleCheck;
          nixos-home-manager-bridge = nixosHomeManagerBridgeCheck;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          deepseek-harness = mkPackage system;
        in
        {
          inherit deepseek-harness;
          default = deepseek-harness;
          docs = mkDocs system;
        }
      );

      homeModules.deepseek-harness = import ./modules/home-manager.nix;
      homeModules.default = self.homeModules.deepseek-harness;
      # Compatibility alias used by older Home Manager conventions.
      homeManagerModules.deepseek-harness = self.homeModules.deepseek-harness;
      homeManagerModules.default = self.homeModules.deepseek-harness;

      nixosModules.deepseek-harness = import ./modules/nixos.nix;
      nixosModules.default = self.nixosModules.deepseek-harness;

      lib = {
        # Marker constructor for `!!<tag>` YAML scalars in composition values
        # (e.g. `dsh-nix.lib.yamlTag "js" "process.env.X"`). Pure: the pkgs
        # argument is bound but never forced for this attribute.
        yamlTag =
          (import ./lib/yaml.nix {
            lib = nixpkgs.lib;
            pkgs = mkPkgs "x86_64-linux";
          }).yamlTag;
      };

      checks = forAllSystems mkChecks;

      formatter = forAllSystems (system: (mkPkgs system).nixfmt-tree);
    };
}
