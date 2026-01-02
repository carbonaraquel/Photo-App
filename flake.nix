{
  description = "Photo-App - A web application for sharing photos at events";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # NixOS module for the Photo-App systemd service
      nixosModule = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.photo-app;
        in
        {
          options.services.photo-app = {
            enable = mkEnableOption "Photo-App web application";

            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.default;
              description = "Photo-App package to use";
            };

            host = mkOption {
              type = types.str;
              default = "0.0.0.0";
              description = "Host address to bind to";
            };

            port = mkOption {
              type = types.port;
              default = 5000;
              description = "Port to listen on";
            };

            dataDir = mkOption {
              type = types.path;
              default = "/var/lib/photo-app";
              description = "Directory to store application data";
            };

            secretKeyFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Path to file containing the Flask secret key";
            };

            user = mkOption {
              type = types.str;
              default = "photo-app";
              description = "User account under which photo-app runs";
            };

            group = mkOption {
              type = types.str;
              default = "photo-app";
              description = "Group account under which photo-app runs";
            };
          };

          config = mkIf cfg.enable {
            users.users.${cfg.user} = {
              isSystemUser = true;
              group = cfg.group;
              home = cfg.dataDir;
              createHome = true;
            };

            users.groups.${cfg.group} = {};

            systemd.services.photo-app = {
              description = "Photo-App Web Application";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
                WorkingDirectory = cfg.dataDir;
                ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}/uploads";
                ExecStart = "${cfg.package}/bin/photo-app";
                Restart = "on-failure";
                RestartSec = "10s";
                
                # Security hardening
                PrivateTmp = true;
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                ReadWritePaths = [ cfg.dataDir ];
                
                # Environment
                Environment = [
                  "FLASK_APP=app.py"
                  "FLASK_ENV=production"
                ];
              };

              environment = {
                SECRET_KEY = if cfg.secretKeyFile != null 
                  then "$(cat ${cfg.secretKeyFile})"
                  else "change-this-in-production";
              };

              preStart = ''
                # Ensure upload directory exists
                mkdir -p ${cfg.dataDir}/uploads
                
                # Initialize database if it doesn't exist
                if [ ! -f ${cfg.dataDir}/photo_app.db ]; then
                  cd ${cfg.dataDir}
                  ${pkgs.python3}/bin/python -c "
                  import sys
                  sys.path.insert(0, '${cfg.package}/lib/photo-app')
                  from app import app, db
                  with app.app_context():
                      db.create_all()
                  "
                fi
              '';
            };
          };
        };
    in
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
            flask-wtf
            werkzeug
          ];

          format = "other";

          installPhase = ''
            mkdir -p $out/bin $out/lib/photo-app
            cp -r * $out/lib/photo-app/
            cat > $out/bin/photo-app <<EOF
            #!${pkgs.bash}/bin/bash
            cd \''${PHOTO_APP_DATA_DIR:-$out/lib/photo-app}
            export FLASK_APP=app.py
            ${python}/bin/python \$FLASK_APP
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
            pythonPackages.flask-wtf
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
    ) // {
      nixosModules.default = nixosModule;
      nixosModules.photo-app = nixosModule;
    };
}
