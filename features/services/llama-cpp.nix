{ lib, mkFeature, ... }:

let
  inherit (lib) mkOption types;

  modelType = types.submodule {
    options = {
      hfRepo = mkOption {
        type = types.str;
        example = "Qwen/Qwen2.5-3B-Instruct-GGUF";
        description = "HuggingFace GGUF repo, fetched on first start via `llama-server --hf-repo`";
      };
      quant = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "Q4_K_M";
        description = ''
          Quantization tag; selects the file via `--hf-repo <repo>:<quant>`
          instead of an exact filename. More robust than `hfFile` (no casing
          traps). Mutually exclusive with `hfFile`
        '';
      };
      hfFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "qwen2.5-3b-instruct-q4_k_m.gguf";
        description = "Exact GGUF filename in the repo (`--hf-file`). Null lets llama.cpp choose; prefer `quant`";
      };
      loadOnStartup = mkOption {
        type = types.bool;
        default = false;
        description = "Load this model when the server starts instead of on its first request";
      };
      settings = mkOption {
        type = types.attrs;
        default = { };
        example = { ctx-size = 8192; temp = 0.7; };
        description = "`llama-server` flags for this model (attr name = flag), overriding the shared `settings`";
      };
    };
  };
in
mkFeature {
  name = "llama-cpp";

  options = { config, pkgs, ... }:
    let
      cfg = config.features.llama-cpp;
      ## Package override flags per acceleration backend.
      backendArgs = {
        cpu = { };
        cuda = { cudaSupport = true; };
        vulkan = { vulkanSupport = true; };
        rocm = { rocmSupport = true; };
      };
    in
    {
      backend = mkOption {
        type = types.enum (builtins.attrNames backendArgs);
        default = "cpu";
        description = ''
          Acceleration backend for the default `package`. `cuda`/`rocm` need the
          matching unfree/config on the host (e.g. `nixpkgs.config.allowUnfree`).
          Ignored if `package` is set explicitly
        '';
      };

      package = mkOption {
        type = types.package;
        default = pkgs.llama-cpp.override backendArgs.${cfg.backend};
        defaultText = lib.literalExpression "pkgs.llama-cpp.override (backend flags)";
        description = "The llama.cpp package to use. Defaults to `pkgs.llama-cpp` built for `backend`";
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Bind address of the server";
      };

      port = mkOption {
        type = types.port;
        default = 8080;
        description = "Listen port of the server";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open `port` in the firewall";
      };

      settings = mkOption {
        type = types.attrs;
        default = { };
        example = { ctx-size = 8192; n-gpu-layers = 99; flash-attn = "on"; };
        description = "`llama-server` flags shared by all models (attr name = flag), e.g. `ctx-size`, `n-gpu-layers`, `flash-attn`";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = { GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM = "1"; };
        description = "Extra environment variables for every `llama-server`, e.g. `GGML_VK_*` backend tuning";
      };

      models = mkOption {
        type = types.attrsOf modelType;
        default = { };
        description = ''
          Models to serve from one `llama-server` in router mode. Requests pick
          a model by name (the `model` field); only one is loaded at a time,
          and requesting another one swaps it in
        '';
        example = lib.literalExpression ''
          {
            qwen = {
              hfRepo = "Qwen/Qwen2.5-3B-Instruct-GGUF";
              quant = "Q4_K_M";
              loadOnStartup = true;
            };
          }
        '';
      };
    };

  nixos = { config, pkgs, ... }:
    let
      cfg = config.features.llama-cpp;
      gpu = cfg.backend != "cpu";

      ## Router preset: shared settings in `[*]`, one section per model
      preset = pkgs.writeText "llama-cpp-models.ini" (lib.generators.toINIWithGlobalSection { } {
        globalSection.version = 1;
        sections = {
          ## Hide the cache entries of downloaded preset models in `/models`.
          "*" = { dedup-cache-models = true; } // cfg.settings;
        } // lib.mapAttrs (_: m:
          {
            hf-repo = m.hfRepo + lib.optionalString (m.quant != null) ":${m.quant}";
            load-on-startup = m.loadOnStartup;
          }
          // lib.optionalAttrs (m.hfFile != null) { hf-file = m.hfFile; }
          // m.settings) cfg.models;
      });
    in
    {
      assertions = lib.mapAttrsToList (name: m: {
        assertion = !(m.quant != null && m.hfFile != null);
        message = "features.llama-cpp.models.${name}: set either quant or hfFile, not both.";
      }) cfg.models;

      systemd.services.llama-cpp = {
        description = "llama.cpp server";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          ## One model loaded at a time; requesting another unloads it.
          ExecStart = toString [
            (lib.getExe' cfg.package "llama-server")
            "--host" cfg.host
            "--port" cfg.port
            "--models-preset" preset
            "--models-max" 1
          ];
          ExecReload = "${lib.getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
          Restart = "on-failure";
          RestartSec = 30;

          DynamicUser = true;
          StateDirectory = "llama-cpp";
          CacheDirectory = "llama-cpp";
          WorkingDirectory = "/var/lib/llama-cpp";
          Environment = [
            ## Where --hf-repo downloads land (persist across restarts).
            "LLAMA_CACHE=/var/cache/llama-cpp"
            ## Writable HOME so the Vulkan/RADV shader cache works; the default
            ## $HOME/.cache is unwritable under ProtectSystem=strict.
            "HOME=/var/cache/llama-cpp"
          ] ++ lib.mapAttrsToList (n: v: "${n}=${v}") cfg.environment;

          AmbientCapabilities = [ "" ];
          CapabilityBoundingSet = [ "" ];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = false; # Required for GPU support.
          PrivateMounts = true;
          PrivateTmp = true;
          PrivateUsers = true;
          ProcSubset = "pid";
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          RemoveIPC = true;
          RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallErrorNumber = "EPERM";
          SystemCallFilter = [ "@system-service" "~@privileged" ];
        }
        // lib.optionalAttrs gpu {
          SupplementaryGroups = [ "render" "video" ];
          PrivateUsers = false;
        };
      };

      networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;
    };
}
