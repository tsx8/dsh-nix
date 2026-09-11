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
            prefix = "Fixture preset";
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
    # the runtime builder. dsh-llm-codex v0.3.10 ships committed `lib/`
    # artifacts and has no install/prepare/postinstall scripts, so its
    # runtime needs no allowBuilds; the host-peer scenario is covered by the
    # runtime check.
    profiles.fixture = {
      dependencies = {
        "dsh-llm-codex" = "github:NOirBRight/dsh-llm-codex#653c12002d4e5941a0b09e367697a3bf32de9412";
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

    # Registry-spec compatibility: dsh-context publishes an explicit DSH
    # release-compatibility matrix and installs through the ordinary npm
    # registry path. Its browser half exercises the web-app plugin injection
    # surface, so the runtime check boots this profile too.
    profiles.registry = {
      dependencies = {
        "dsh-context" = "0.41.3";
      };
      bundles = [
        "@deepseek-ai/dsh-base"
        "@deepseek-ai/dsh-web-app"
        "dsh-context"
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
      patchReload = "startup";
      cordisPatch = [ ];
    };

    # Shipped profiles use their template lifecycle only for the exact shipped
    # bundle tuple. These cover both sides of that rule without depending on
    # DSH rewriting a Home Manager-owned manifest.
    profiles.web = {
      dependencies = { };
      bundles = [
        "@deepseek-ai/dsh-base"
        "@deepseek-ai/dsh-web-app"
      ];
      cordisPatch = [ ];
    };

    profiles.headless = {
      dependencies = { };
      bundles = [
        "@deepseek-ai/dsh-base"
        "@deepseek-ai/dsh-headless"
      ];
      cordisPatch = [ ];
    };

    profiles.headless-custom = {
      dependencies = { };
      bundles = [
        "@deepseek-ai/dsh-base"
        "@deepseek-ai/dsh-headless"
      ];
      cordisPatch = [ ];
    };
  };
}
