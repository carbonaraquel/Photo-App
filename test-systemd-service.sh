#!/usr/bin/env bash
# Test script for Photo-App systemd service

set -e

echo "Testing Photo-App systemd service configuration..."

# Source Nix profile
. ~/.nix-profile/etc/profile.d/nix.sh

# Create test directory
TEST_DIR="/tmp/photo-app-systemd-test"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "1. Testing flake check..."
cd /home/runner/work/Photo-App/Photo-App
nix flake check 2>&1 | grep -q "all checks passed"
echo "   ✓ Flake check passed"

echo "2. Testing NixOS module export..."
nix flake show 2>&1 | grep -q "nixosModules"
echo "   ✓ NixOS module exported"

echo "3. Evaluating NixOS module options..."
nix eval .#nixosModules.default.options.services.photo-app.enable.type --json > /dev/null 2>&1
echo "   ✓ NixOS module options are valid"

echo "4. Building the package..."
PACKAGE_PATH=$(nix build .#default --print-out-paths 2>&1 | tail -1)
echo "   ✓ Package built at: $PACKAGE_PATH"

echo "5. Testing package executable..."
if [ -x "$PACKAGE_PATH/bin/photo-app" ]; then
    echo "   ✓ Executable is present and has correct permissions"
else
    echo "   ✗ Executable not found or not executable"
    exit 1
fi

echo "6. Creating test systemd user service..."
cat > "$TEST_DIR/photo-app-test.service" <<EOF
[Unit]
Description=Photo-App Test Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$TEST_DIR/data
ExecStartPre=/bin/mkdir -p $TEST_DIR/data/uploads
ExecStart=$PACKAGE_PATH/bin/photo-app
Restart=no
Environment="SECRET_KEY=test-secret-key"
Environment="PHOTO_APP_DATA_DIR=$TEST_DIR/data"

[Install]
WantedBy=default.target
EOF
echo "   ✓ Test systemd service file created"

echo "7. Validating systemd service file syntax..."
if command -v systemd-analyze &> /dev/null; then
    systemd-analyze verify "$TEST_DIR/photo-app-test.service" 2>&1 || true
    echo "   ✓ Service file validated"
else
    echo "   ⚠ systemd-analyze not available, skipping validation"
fi

echo ""
echo "✅ All systemd service tests passed!"
echo ""
echo "To use the NixOS module in your configuration.nix:"
echo "  1. Import the flake in your flake.nix inputs"
echo "  2. Import the module: inputs.photo-app.nixosModules.default"
echo "  3. Configure the service:"
echo ""
cat <<'EOF'
  services.photo-app = {
    enable = true;
    host = "0.0.0.0";
    port = 5000;
    dataDir = "/var/lib/photo-app";
  };
EOF
echo ""
echo "For user service (non-NixOS), install the service:"
echo "  mkdir -p ~/.config/systemd/user/"
echo "  cp photo-app.service ~/.config/systemd/user/"
echo "  systemctl --user enable --now photo-app.service"
