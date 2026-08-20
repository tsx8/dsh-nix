{
  yamlTag,
  profileHash,
  registryHash,
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

    # The main regression profile: a real Git-hosted plugin (pinned commit)
    # exercising the non-registry dependency path through fetchPnpmDeps and
    # the runtime builder. dsh-llm-codex v0.2.5 ships committed `lib/`
    # artifacts and has no install/prepare/postinstall scripts, so its
    # runtime needs no allowBuilds; the host-peer scenario is covered by the
    # runtime check.
    profiles.fixture = {
      dependencies = {
        "dsh-llm-codex" = "github:NOirBRight/dsh-llm-codex#ac5866543ccd44c75a96ba779629ac7a47fc1f50";
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

    # Registry-spec coverage: the same plugin fetched from the npm registry,
    # proving the registry dependency path still works alongside the Git one.
    profiles.registry = {
      dependencies = {
        "dsh-llm-codex" = "0.1.2";
      };
      bundles = [
        "@deepseek-ai/dsh-base"
        "dsh-llm-codex"
      ];
      cordisPatch = [ ];
      pnpmDepsHash = registryHash;
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
