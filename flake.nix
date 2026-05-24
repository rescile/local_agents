{
  description = "Localized Agentic Infrastructure & Loki Workspace";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils, ... }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        # Nutzt direkt den nativen rustPlatform Compiler deines aktuellen NixOS-Stands
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
            echo "⚡ Nativer Loki-Workspace geladen (Rust ${pkgs.rustc.version}) ⚡"
          '';
        };
      });
}
