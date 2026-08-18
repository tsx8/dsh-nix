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

      # Render this module's options as Markdown (docs/options.md) without
      # importing the whole home-manager module set: a plain evalModules plus
      # small stubs for the home-manager options the module consumes.
      mkOptionsDoc =
        system:
        let
          pkgs = mkPkgs system;

          hmContextStub = {
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

          optionsEval = lib.evalModules {
            specialArgs = { inherit pkgs; };
            modules = [
              # A path module keeps its declaration site, unlike a lambda.
              ./modules/home-manager.nix
              hmContextStub
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
                name = "modules/home-manager.nix";
                url = "https://github.com/tsx8/dsh-nix/blob/main/modules/home-manager.nix";
              }) opt.declarations;
            };
        }).optionsCommonMark;

      mkDocs =
        system:
        let
          pkgs = mkPkgs system;
          optionsMd = mkOptionsDoc system;
        in
        pkgs.runCommand "dsh-nix-docs" { inherit optionsMd; } ''
          mkdir -p "$out"
          { echo "# DeepSeek Harness Home Manager options"
            echo
            echo "Auto-generated from the option declarations in \`modules/home-manager.nix\`."
            echo "CI keeps this file up to date on every push."
            echo "Regenerate locally with: \`nix build .#docs -o docs-build && cp docs-build/options.md docs/options.md\`."
            echo
            cat "$optionsMd"
          } > "$out/options.md"
        '';

      mkChecks =
        system:
        let
          pkgs = mkPkgs system;
          deepseek-harness = mkPackage system;
          homeConfiguration = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
              self.homeModules.deepseek-harness
              ./tests/home-manager.nix
            ];
          };
          homeManagerCheck =
            assert homeConfiguration.config.programs.deepseek-harness.package == null;
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
                test -f "$files/skills/text-fixture/SKILL.md"
                test -f "$files/skills/inline-fixture/SKILL.md"
                test -d "$files/.agent-presets/fixture"
                test -f "$files/.agent-presets/fixture/agent.cordis.yml"

                manifest="$files/profiles/fixture/package.json"
                jq -e '
                  .name == "dsh-profile-fixture"
                  and .private == true
                  and .dependencies == {}
                  and .dsh.profile.bundles == ["@deepseek-ai/dsh-base"]
                ' "$manifest"
                grep -Fx '    model: fixture-model' "$files/profiles/fixture/cordis.patch.yml"
                test "$(cat "$files/profiles/empty/cordis.patch.yml")" = '[]'
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
                export DSH_HOME="$HOME/dsh"
                export DSH_AGENTS_HOME="$HOME/agents"
                export DSH_TELEMETRY_DISABLED=1

                mkdir -p "$HOME" "$DSH_AGENTS_HOME"
                cp -RL "$activationPackage/home-files/.local/share/dsh-fixture" "$DSH_HOME"
                chmod -R u+w "$DSH_HOME"

                dsh --profile fixture --dump-config > "$TMPDIR/dsh-config.yml"
                test -f "$DSH_HOME/profiles/fixture/cordis.yml"
                grep -F 'model: fixture-model' "$TMPDIR/dsh-config.yml"

                touch "$out"
              '';
        in
        {
          package = deepseek-harness;
          home-manager = homeConfiguration.activationPackage;
          home-files = homeManagerCheck;
          home-manager-runtime = homeManagerRuntimeCheck;
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

      checks = forAllSystems mkChecks;

      formatter = forAllSystems (system: (mkPkgs system).nixfmt-tree);
    };
}
