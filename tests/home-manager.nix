{
  yamlTag,
  profileHash,
  hmPackage ? null,
  ...
}:
{
  home.username = "dsh-test";
  home.homeDirectory = "/tmp/dsh-test";
  home.stateVersion = "24.11";

  programs.deepseek-harness = {
    enable = true;
    # The standalone check passes the same-repo package; the NixOS bridge
    # check passes `null` so DSH comes from the NixOS module only.
    package = hmPackage;

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
          id = "agent-default-model";
          config = {
            provider = "deepseek-official";
            model = "fixture-model";
          };
        }
      ];
      pnpmDepsHash = profileHash;
    };

    # An installation-owned-only profile: no dependency closure, no fetch,
    # no profile-local node_modules.
    profiles.bundle-only = {
      dependencies = { };
      bundles = [
        "@deepseek-ai/dsh-base"
      ];
      cordisPatch = [ ];
    };
  };
}
