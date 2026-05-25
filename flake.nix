{
  description = "Localized Agentic Infrastructure - Loki & Ollama Workspace";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:

      let
        pkgs = import nixpkgs { inherit system; };

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

          nativeBuildInputs = [ pkgs.pkg-config pkgs.cmake ];
          buildInputs = [ pkgs.openssl pkgs.llvmPackages.libclang.lib ];

          preBuild = ''
            export LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib"
            export BINDGEN_EXTRA_CLANG_ARGS="-isystem ${pkgs.llvmPackages.libclang.lib}/lib/clang/${pkgs.llvmPackages.libclang.version}/include -isystem ${pkgs.glibc.dev}/include"
          '';
          doCheck = false;
        };

        mcpConfig = pkgs.writeText "mcp.json" (builtins.toJSON {
          mcpServers = {
            rescile-automation = {
              type = "http"; 
              url = "http://127.0.0.1:7600/mcp";
            };
          };
        });

        lokiConfig = pkgs.writeText "config.yaml" ''
          vault_password_file: "/home/torsten/.loki_password"
          model: ollama:gemma4
          clients:
            - type: openai-compatible
              name: ollama
              api_base: http://127.0.0.1:11434/v1
              models:
                - name: gemma4
                - name: llama3.2

          mcp_server_support: true
          enabled_mcp_servers: "rescile-automation"
        '';
      in
      {
      devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            local-loki
            start-ollama    # <--- Hier das neue Script einfügen!
            ollama          
            clinfo          
            intel-compute-runtime 
            netcat
            curl
            python3
            nixfmt          # <--- Direkt auf das neue saubere Paket geändert
            nil
          ];

          shellHook = ''
            # Pfade für Loki vorbereiten
            LOKI_CONFIG_DIR="$HOME/.config/loki"
            mkdir -p "$LOKI_CONFIG_DIR/functions"

            cp -f ${mcpConfig} "$LOKI_CONFIG_DIR/functions/mcp.json"
            cp -f ${lokiConfig} "$LOKI_CONFIG_DIR/config.yaml"

            # --- Lokale Ollama Umgebungsvariablen ---
            export OLLAMA_MODELS="$PWD/.ollama/models"
            export OLLAMA_HOST="127.0.0.1:11434"
            export OLLAMA_INTEL_GPU=1
            export OLLAMA_NUM_PARALLEL=2

            mkdir -p "$OLLAMA_MODELS"

            echo "--- Localized AI Workspace Ready (Loki 0.4.0) ---"
            echo "-> Run 'start-ollama' in a separate terminal to boot the local model server."
          '';
        };
      }
    );
}
