{ ... }:

let
  fixturePreset = ./fixtures/preset;
in
{
  home.username = "dsh-test";
  home.homeDirectory = "/tmp/dsh-test";
  home.stateVersion = "24.11";

  programs.deepseek-harness = {
    enable = true;
    package = null;
    dshHome = "/tmp/dsh-test/.local/share/dsh-fixture";
    agentsFile = {
      source = ./fixtures/AGENTS.md;
    };

    cordisPatch.structured = [
      {
        id = "hmr";
        disabled = true;
      }
    ];

    skills = {
      text-fixture = {
        source = ./fixtures/skill-text.md;
      };
      directory-fixture = {
        source = ./fixtures/skill;
      };
      inline-fixture.text = ''
        ---
        name: inline-fixture
        description: A fixture skill generated from inline Nix text.
        ---

        # Inline skill
      '';
    };

    agentPresets.fixture = {
      source = fixturePreset;
    };

    profiles.fixture = {
      bundles = [ "@deepseek-ai/dsh-base" ];
      cordisPatch.text = ''
        - id: agent-default-model
          config:
            provider: deepseek-official
            model: fixture-model
      '';
    };

    profiles.empty.bundles = [ ];
  };
}
