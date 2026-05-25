{
  description = "Localized Agentic Infrastructure & Loki Workspace";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

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
              type = "http"; # Oder "sse", je nachdem was wir herausfinden
              url = "http://127.0.0.1:7600/mcp";
            };
          };
        });

        lokiConfig = pkgs.writeText "config.yaml" ''
          vault_password_file: "/home/torsten/.loki_password"
          model: ollama:llama3.2
          clients:
            - type: openai-compatible
              name: ollama
              api_base: http://127.0.0.1:11434/v1
              models:
                - name: llama3.2
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            netcat
            curl
            python3
            local-loki
          ];

          shellHook = ''
            LOKI_CONFIG_DIR="$HOME/.config/loki"
            mkdir -p "$LOKI_CONFIG_DIR/functions"

            cp -f ${mcpConfig} "$LOKI_CONFIG_DIR/functions/mcp.json"
            cp -f ${lokiConfig} "$LOKI_CONFIG_DIR/config.yaml"

            echo "--- Loki environment successfully initialized (Rust ${pkgs.rustc.version}) ---"
          '';
        };
      }
    );
}
