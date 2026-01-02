{
  description = "Photo-App - A web application for sharing photos at events";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python3;
        pythonPackages = python.pkgs;
      in
      {
        packages.default = pythonPackages.buildPythonApplication {
          pname = "photo-app";
          version = "1.0.0";
          src = ./.;

          propagatedBuildInputs = with pythonPackages; [
            flask
            flask-sqlalchemy
            flask-login
            werkzeug
          ];

          format = "other";

          installPhase = ''
            mkdir -p $out/bin $out/lib/photo-app
            cp -r * $out/lib/photo-app/
            cat > $out/bin/photo-app <<EOF
            #!${pkgs.bash}/bin/bash
            cd $out/lib/photo-app
            ${python}/bin/python app.py
            EOF
            chmod +x $out/bin/photo-app
          '';
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python3
            pythonPackages.flask
            pythonPackages.flask-sqlalchemy
            pythonPackages.flask-login
            pythonPackages.werkzeug
          ];

          shellHook = ''
            echo "Photo-App development environment"
            echo "Run 'python app.py' to start the application"
          '';
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/photo-app";
        };
      }
    );
}
