{
  description = "landaire.net blog";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.default = pkgs.stdenv.mkDerivation {
        pname = "landaire-blog";
        version = "0.1.0";
        src = ./.;

        nativeBuildInputs = with pkgs; [
          zola
          tailwindcss
        ];

        buildPhase = ''
          tailwindcss -i tailwind-input.css -o static/css/style.css --minify
          zola build
        '';

        installPhase = ''
          cp -r public $out
        '';
      };

      apps.default = {
        type = "app";
        program = let
          script = pkgs.writeShellScript "dev" ''
            cleanup() { kill 0; }
            trap cleanup EXIT
            ${pkgs.tailwindcss}/bin/tailwindcss -i tailwind-input.css -o static/css/style.css --watch &
            ${pkgs.zola}/bin/zola serve "$@"
          '';
        in
          "${script}";
      };

      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          zola
          tailwindcss
        ];

        shellHook = ''
          echo "landaire.net dev shell"
          echo "  zola $(zola --version)"
          echo ""
          echo "Run: nix run    (tailwind watch + zola serve)"
        '';
      };
    });
}
