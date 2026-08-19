{
  fixtureDep,
  yamlTag,
  ...
}:
{
  home.username = "dsh-test";
  home.homeDirectory = "/tmp/dsh-test";
  home.stateVersion = "24.11";

  programs.deepseek-harness = {
    enable = true;
    package = null;
    dshHome = "/tmp/dsh-test/.local/share/dsh-fixture";

    agentsFile = ./fixtures/AGENTS.md;

    cordisPatch = [
      {
        id = "hmr";
        disabled = true;
      }
    ];

    skills = {
      file-fixture = ./fixtures/skill-text.md;
      directory-fixture = ./fixtures/skill;
    };

    agentPresets.my-preset = {
      agentCordis = [
        {
          id = "persona";
          name = "@deepseek-ai/dsh-persona";
          config = {
            text = "Fixture preset";
            complete = true;
          };
        }

        {
          id = "fs-local";
          name = "@deepseek-ai/dsh-fs-local";
          config.cwd = yamlTag "js" "process.env.DSH_CWD ?? process.cwd()";
        }
      ];

      preset = {
        name = "My Preset";
        description = "A fixture preset.";
        order = 10;
      };

      files."skills/local-helper" = ./fixtures/skill;
    };

    profiles.fixture = {
      dependencies."dsh-context" = fixtureDep;
      bundles = [
        "@deepseek-ai/dsh-base"
        "dsh-context"
      ];
      cordisPatch = [
        {
          id = "agent-default-model";
          config = {
            provider = "deepseek-official";
            model = "fixture-model";
          };
        }
      ];
    };

    profiles.bundle-only = {
      dependencies."dsh-context" = fixtureDep;
      bundles = [
        "@deepseek-ai/dsh-base"
        "dsh-context"
      ];
      cordisPatch = [ ];
    };
  };
}
