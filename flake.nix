{
  description = "Localized Agentic Infrastructure - Loki & Ollama Workspace";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
    }:
    utils.lib.eachDefaultSystem (
      system:

      let
        # Allow unfree packages so Intel's OneAPI/SYCL toolkit can compile
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # Ein echtes, portables Script-Paket für den Ollama-Start
        start-ollama = pkgs.writeScriptBin "start-ollama" ''
          #!${pkgs.bash}/bin/bash
          echo "-> Starting localized Ollama server..."
          exec ollama serve
        '';

        local-loki = pkgs.rustPlatform.buildRustPackage rec {
          pname = "loki-ai";
          version = "0.4.0";
          auditable = false;

          src = pkgs.fetchCrate {
            inherit pname version;
            hash = "sha256-CgvVJinNBV+yYayPPIrgM/Yuq+Gal92/X8QtkqfSXzg=";
          };
          cargoHash = "sha256-ve+jK2HOczIhDOoEKEb80si2Jp8yWTj8D3JYzM03H6Y=";

          nativeBuildInputs = [
            pkgs.pkg-config
            pkgs.cmake
          ];
          buildInputs = [
            pkgs.openssl
            pkgs.llvmPackages.libclang.lib
          ];

          preBuild = ''
            export LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib"
            export BINDGEN_EXTRA_CLANG_ARGS="-isystem ${pkgs.llvmPackages.libclang.lib}/lib/clang/${pkgs.llvmPackages.libclang.version}/include -isystem ${pkgs.glibc.dev}/include"
          '';
          doCheck = false;
        };

        mcpConfig = pkgs.writeText "mcp.json" (
          builtins.toJSON {
            mcpServers = {
              rescile-automation = {
                type = "http";
                url = "http://127.0.0.1:7600/mcp";
                # Explicitly pass the headers your server demands to pass validation
                headers = {
                  "Accept" = "text/event-stream";
                };
              };
            };
          }
        );

        # Wrap the configuration in a writeText & builtins.toJSON block
        lokiConfigFile = pkgs.writeText "config.yaml" (
          builtins.toJSON {
            vault_password_file = "/home/torsten/.loki_password";
            model = "ollama:qwen2.5-coder:7b";

            # ADDED: Explicitly set a stable temperature and streaming defaults
            temperature = 0.2;
            stream = true;

            clients = [
              {
                type = "openai-compatible";
                name = "ollama";
                api_base = "http://127.0.0.1:11434/v1";
                models = [
                  {
                    name = "qwen2.5-coder:7b";
                    type = "chat";
                    supports_tools = true;
                  }
                  { name = "gemma4:E4B"; }
                  { name = "llama3.2"; }
                ];
              }
            ];
            mcp_server_support = true;
            enabled_mcp_servers = "rescile-automation";
          }
        );

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            local-loki
            start-ollama
            ollama
            clinfo
            vulkan-tools
            intel-compute-runtime
            intel-media-driver
            ocl-icd # Added for SYCL runtime support
            netcat
            curl
            python3
            nixfmt
            nil
          ];

          shellHook = ''
            # Pfade für Loki vorbereiten
            LOKI_CONFIG_DIR="$HOME/.config/loki"
            mkdir -p "$LOKI_CONFIG_DIR/functions"

            # Copy mcp.json to BOTH possible locations to ensure Loki detects it
            cp -f ${mcpConfig} "$LOKI_CONFIG_DIR/mcp.json"
            cp -f ${mcpConfig} "$LOKI_CONFIG_DIR/functions/mcp.json"

            cp -f ${lokiConfigFile} "$LOKI_CONFIG_DIR/config.yaml"

            # --- Force clean terminal encoding output ---
            export LANG="en_US.UTF-8"
            export LC_ALL="en_US.UTF-8"

            export OLLAMA_MODELS="$PWD/.ollama/models"
            export OLLAMA_HOST="127.0.0.1:11434"
            export OLLAMA_NUM_PARALLEL=2


            # --- Point OpenCL to your Intel Compute vendor directory ---
            export OCL_ICD_VENDORS="${pkgs.intel-compute-runtime}/etc/OpenCL/vendors/"
            export LD_LIBRARY_PATH="${pkgs.intel-compute-runtime}/lib:${pkgs.intel-media-driver}/lib:${pkgs.ocl-icd}/lib:$LD_LIBRARY_PATH"

            mkdir -p "$OLLAMA_MODELS"

            echo "--- Localized AI Workspace Ready (Loki 0.4.0) ---"
            echo "-> Run 'start-ollama' in a separate terminal to boot the local model server."
          '';
        };
      }
    );
}
