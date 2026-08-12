{ lib, mkFeature, ... }:

let
  inherit (lib) mkOption types;

  modelType = types.submodule {
    options = {
      hfRepo = mkOption {
        type = types.str;
        example = "Qwen/Qwen2.5-3B-Instruct-GGUF";
        description = "HuggingFace GGUF repo, fetched on first start via `llama-server --hf-repo`.";
      };
      quant = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "Q4_K_M";
        description = ''
          Quantization tag; selects the file via `--hf-repo <repo>:<quant>`
          instead of an exact filename. More robust than `hfFile` (no casing
          traps). Mutually exclusive with `hfFile`.
        '';
      };
      hfFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "qwen2.5-3b-instruct-q4_k_m.gguf";
        description = "Exact GGUF filename in the repo (`--hf-file`). Null lets llama.cpp choose; prefer `quant`.";
      };
      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Bind address for this model's server.";
      };
      port = mkOption {
        type = types.port;
        example = 8080;
        description = "Listen port (must be unique across models).";
      };
      settings = mkOption {
        type = types.attrs;
        default = { };
        example = { ctx-size = 8192; n-gpu-layers = 99; temp = 0.7; };
        description = "Extra `llama-server` flags (attr name = flag), e.g. `ctx-size`, `n-gpu-layers`, `temp`, `flash-attn`.";
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
          Ignored if `package` is set explicitly.
        '';
      };

      package = mkOption {
        type = types.package;
        default = pkgs.llama-cpp.override backendArgs.${cfg.backend};
        defaultText = lib.literalExpression "pkgs.llama-cpp.override (backend flags)";
        description = "The llama.cpp package to use. Defaults to `pkgs.llama-cpp` built for `backend`.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open each model's port in the firewall.";
      };

      models = mkOption {
        type = types.attrsOf modelType;
        default = { };
        description = ''
          Models to serve; each becomes a `llama-server` systemd service
          (`llama-cpp-<name>.service`) on its own port. Extra flags go under
          `settings`.
        '';
        example = lib.literalExpression ''
          {
            qwen = {
              hfRepo = "Qwen/Qwen2.5-3B-Instruct-GGUF";
              quant = "Q4_K_M";
              port = 8080;
              settings.ctx-size = 8192;
            };
          }
        '';
      };
    };

  nixos = { config, pkgs, ... }:
    let
      cfg = config.features.llama-cpp;
      gpu = cfg.backend != "cpu";

      ## Model -> llama-server CLI args. Typed fields map to their flags; extra
      ## `settings` are passed through as `--<name> <value>`.
      mkArgs = m:
        {
          hf-repo = m.hfRepo + lib.optionalString (m.quant != null) ":${m.quant}";
          host = m.host;
          port = m.port;
        }
        // lib.optionalAttrs (m.hfFile != null) { hf-file = m.hfFile; }
        // m.settings;

      ## Same flag formatting the nixpkgs services.llama-cpp module uses.
      mkExecStart = m: toString [
        (lib.getExe' cfg.package "llama-server")
        (lib.cli.toCommandLine
          (optionName: {
            option = if builtins.stringLength optionName > 1 then "--${optionName}" else "-${optionName}";
            sep = " ";
            explicitBool = false;
            formatArg = lib.generators.mkValueStringDefault { };
          })
          (mkArgs m))
      ];

      mkService = name: m: {
        name = "llama-cpp-${name}";
        value = {
          description = "llama.cpp server (${name})";
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            ExecStart = mkExecStart m;
            ExecReload = "${lib.getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
            Restart = "on-failure";
            RestartSec = 30;

            DynamicUser = true;
            StateDirectory = "llama-cpp-${name}";
            CacheDirectory = "llama-cpp-${name}";
            WorkingDirectory = "/var/lib/llama-cpp-${name}";
            Environment = [
              ## Where --hf-repo downloads land (persist across restarts).
              "LLAMA_CACHE=/var/cache/llama-cpp-${name}"
              ## Writable HOME so the Vulkan/RADV shader cache works; the default
              ## $HOME/.cache is unwritable under ProtectSystem=strict.
              "HOME=/var/cache/llama-cpp-${name}"
            ];

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
          ## GPU backends: grant the DynamicUser access to the DRI render node.
          ## PrivateUsers must be off, or the render group maps to `nobody` in
          ## the user namespace and device access is denied.
          // lib.optionalAttrs gpu {
            SupplementaryGroups = [ "render" "video" ];
            PrivateUsers = false;
          };
        };
      };
    in
    {
      assertions = lib.mapAttrsToList (name: m: {
        assertion = !(m.quant != null && m.hfFile != null);
        message = "features.llama-cpp.models.${name}: set either quant or hfFile, not both.";
      }) cfg.models;

      systemd.services = lib.listToAttrs (lib.mapAttrsToList mkService cfg.models);

      networking.firewall.allowedTCPPorts =
        lib.optionals cfg.openFirewall (lib.mapAttrsToList (_: m: m.port) cfg.models);
    };
}
