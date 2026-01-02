# Photo-App

A web application that allows groups of people to upload and share photos at events. Each person has their own profile and can create or join events. The app includes a special download feature that downloads all photos from an event **without** downloading photos that the user themselves uploaded.

## Features

- 👤 **User Profiles**: Register and create your own profile
- 🎉 **Event Management**: Create and join events with other users
- 📸 **Photo Upload**: Upload multiple photos to events you're a member of
- 📥 **Smart Download**: Download all photos from an event, excluding your own uploads
- 🔒 **Authentication**: Secure login system to protect your data

## Requirements

- Python 3.8 or higher
- Nix Package Manager (for Nix Flake support)

## Installation

### Method 1: Using Nix Flake (Recommended)

1. Install Nix Package Manager (if not already installed):
```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

2. Enable Flakes (add to `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`):
```
experimental-features = nix-command flakes
```

3. Clone the repository:
```bash
git clone https://github.com/carbonaraquel/Photo-App.git
cd Photo-App
```

4. Run the application using Nix:
```bash
nix run
```

Or enter the development shell:
```bash
nix develop
python app.py
```

### Method 2: Using Python Virtual Environment

1. Clone the repository:
```bash
git clone https://github.com/carbonaraquel/Photo-App.git
cd Photo-App
```

2. Create and activate a virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Run the application:
```bash
python app.py
```

## Usage

1. Open your web browser and navigate to `http://localhost:5000`

2. **Register** a new account with your username, email, and password

3. **Login** with your credentials

4. **Create an Event**:
   - Click "Create Event" in the navigation
   - Provide an event name and optional description
   - You'll automatically be added as a member

5. **Join an Event**:
   - Browse all events from the Events page
   - Click "View Event" and then "Join Event"

6. **Upload Photos**:
   - Navigate to an event you're a member of
   - Click "Upload Photos"
   - Select one or multiple image files (PNG, JPG, JPEG, GIF)
   - Submit the form

7. **Download Photos**:
   - Go to any event you're a member of
   - Click "Download All Photos (Excluding Mine)"
   - A ZIP file will be downloaded containing all photos uploaded by other members

## Project Structure

```
Photo-App/
├── app.py                 # Main Flask application
├── models.py             # Database models (User, Event, Photo)
├── requirements.txt      # Python dependencies
├── flake.nix            # Nix Flake configuration
├── templates/           # HTML templates
│   ├── base.html
│   ├── index.html
│   ├── login.html
│   ├── register.html
│   ├── events.html
│   ├── event_detail.html
│   ├── create_event.html
│   └── upload_photo.html
├── uploads/             # Directory for uploaded photos (created automatically)
└── photo_app.db        # SQLite database (created automatically)
```

## Technical Details

- **Backend**: Flask (Python 3)
- **Database**: SQLite with SQLAlchemy ORM
- **Authentication**: Flask-Login
- **Password Security**: Werkzeug password hashing
- **File Handling**: Secure file uploads with UUID-based filenames
- **Package Management**: Nix Flake for reproducible builds

## Security Considerations

- Passwords are hashed using Werkzeug's secure password hashing
- File uploads are limited to specific image formats
- Uploaded files are renamed with UUIDs to prevent collisions
- Users can only access events they're members of
- Maximum file upload size is 16MB

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the terms specified in the LICENSE file.
