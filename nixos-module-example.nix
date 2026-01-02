# Example NixOS configuration using the Photo-App systemd service
# This can be used in /etc/nixos/configuration.nix

{ config, pkgs, ... }:

{
  imports = [
    # Import the Photo-App flake module
    # In practice, you would use: inputs.photo-app.nixosModules.default
  ];

  services.photo-app = {
    enable = true;
    host = "0.0.0.0";
    port = 5000;
    dataDir = "/var/lib/photo-app";
    # secretKeyFile = "/run/secrets/photo-app-secret-key";  # Optional: use with agenix or sops-nix
  };

  # Open firewall port (optional)
  networking.firewall.allowedTCPPorts = [ 5000 ];
}
