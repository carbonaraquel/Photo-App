# Systemd Service for Photo-App

This document explains how to use the Photo-App systemd service on NixOS and non-NixOS systems.

## NixOS Configuration

The Photo-App flake includes a NixOS module that provides a systemd service for running the application.

### Basic Setup

Add the Photo-App flake to your system's `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    photo-app.url = "github:carbonaraquel/Photo-App";
  };

  outputs = { self, nixpkgs, photo-app, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        photo-app.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### Configuration Options

In your `configuration.nix`, enable and configure the service:

```nix
{ config, pkgs, ... }:

{
  services.photo-app = {
    enable = true;
    host = "0.0.0.0";         # Listen on all interfaces
    port = 5000;              # Port to bind to
    dataDir = "/var/lib/photo-app";  # Data directory
    
    # Optional: Path to a file containing the Flask secret key
    # secretKeyFile = "/run/secrets/photo-app-secret-key";
    
    # Optional: Custom user and group
    # user = "photo-app";
    # group = "photo-app";
  };

  # Optional: Open firewall port
  networking.firewall.allowedTCPPorts = [ 5000 ];
}
```

### Available Options

- **`enable`**: Whether to enable the Photo-App service (default: `false`)
- **`package`**: The Photo-App package to use (default: auto-detected from flake)
- **`host`**: Host address to bind to (default: `"0.0.0.0"`)
- **`port`**: Port to listen on (default: `5000`)
- **`dataDir`**: Directory to store application data, database, and uploads (default: `"/var/lib/photo-app"`)
- **`secretKeyFile`**: Path to file containing the Flask secret key (default: `null`, uses hardcoded key)
- **`user`**: User account under which photo-app runs (default: `"photo-app"`)
- **`group`**: Group account under which photo-app runs (default: `"photo-app"`)

### Service Management

After applying your NixOS configuration:

```bash
# Check service status
systemctl status photo-app

# View logs
journalctl -u photo-app -f

# Restart service
systemctl restart photo-app

# Stop service
systemctl stop photo-app
```

## Non-NixOS Systems (User Service)

For non-NixOS systems with Nix installed, you can run Photo-App as a user systemd service.

### Setup

1. Build the Photo-App package:
   ```bash
   cd Photo-App
   nix build .#default
   ```

2. Create the service file:
   ```bash
   mkdir -p ~/.config/systemd/user/
   ```

3. Copy and edit the service file:
   ```bash
   cp photo-app.service ~/.config/systemd/user/
   ```

4. Edit `~/.config/systemd/user/photo-app.service` and update the `ExecStart` path to point to your built package:
   ```ini
   ExecStart=/nix/store/<hash>-photo-app-1.0.0/bin/photo-app
   ```

5. Create the data directory:
   ```bash
   mkdir -p ~/photo-app-data/uploads
   ```

6. Enable and start the service:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable photo-app
   systemctl --user start photo-app
   ```

### User Service Management

```bash
# Check status
systemctl --user status photo-app

# View logs
journalctl --user -u photo-app -f

# Restart service
systemctl --user restart photo-app

# Stop service
systemctl --user stop photo-app

# Disable service
systemctl --user disable photo-app
```

## Security Considerations

The NixOS module includes several security hardening options:

- **PrivateTmp**: Service has a private `/tmp` directory
- **NoNewPrivileges**: Service cannot gain new privileges
- **ProtectSystem**: File system is read-only except for specific paths
- **ProtectHome**: Home directories are inaccessible
- **ReadWritePaths**: Only the data directory is writable

### Secret Key Management

For production use, always set a custom secret key:

**NixOS with agenix or sops-nix:**
```nix
services.photo-app.secretKeyFile = "/run/secrets/photo-app-secret-key";
```

**User service:**
Edit the service file to set a secure secret key in the Environment line:
```ini
Environment="SECRET_KEY=<generate-a-random-32-character-string>"
```

Generate a secure key:
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

## Reverse Proxy Setup (Optional)

For production deployments, it's recommended to run Photo-App behind a reverse proxy like nginx.

### NixOS nginx Example

```nix
services.nginx = {
  enable = true;
  virtualHosts."photos.example.com" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:5000";
      proxyWebsockets = true;
    };
  };
};

services.photo-app = {
  enable = true;
  host = "127.0.0.1";  # Only listen on localhost
  port = 5000;
};
```

## Testing the Service

After installation, test the service:

```bash
# Check if service is running
systemctl status photo-app  # or: systemctl --user status photo-app

# Test the HTTP endpoint
curl http://localhost:5000

# Check if you can access the web interface
# Open in browser: http://localhost:5000
```

## Troubleshooting

### Service fails to start

Check the logs:
```bash
journalctl -u photo-app -n 50
# or for user service:
journalctl --user -u photo-app -n 50
```

### Permission errors

Ensure the data directory has correct permissions:
```bash
# NixOS (system service)
sudo ls -la /var/lib/photo-app

# User service
ls -la ~/photo-app-data
```

### Database initialization issues

The service automatically initializes the database on first run. If there are issues, you can manually initialize:

```bash
# Navigate to data directory
cd /var/lib/photo-app  # or ~/photo-app-data

# Run Python to initialize database
python3 -c "
import sys
sys.path.insert(0, '/nix/store/<hash>-photo-app-1.0.0/lib/photo-app')
from app import app, db
with app.app_context():
    db.create_all()
"
```
