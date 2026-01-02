"""Main Flask application for Photo-App."""

import os
from flask import Flask, render_template, request, redirect, url_for, flash, send_file
from flask_login import LoginManager, login_user, logout_user, login_required, current_user
from flask_wtf.csrf import CSRFProtect
from werkzeug.utils import secure_filename
from models import db, User, Event, Photo
import uuid
from io import BytesIO
import zipfile

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///photo_app.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Allowed file extensions
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

# Initialize extensions
db.init_app(app)
csrf = CSRFProtect(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# Create upload folder if it doesn't exist
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)


@login_manager.user_loader
def load_user(user_id):
    """Load user by ID for Flask-Login."""
    return User.query.get(int(user_id))


def allowed_file(filename):
    """Check if file extension is allowed."""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


@app.route('/')
def index():
    """Home page."""
    return render_template('index.html')


@app.route('/register', methods=['GET', 'POST'])
def register():
    """User registration page."""
    if current_user.is_authenticated:
        return redirect(url_for('events'))
    
    if request.method == 'POST':
        username = request.form.get('username')
        email = request.form.get('email')
        password = request.form.get('password')
        
        # Validate input
        if not username or not email or not password:
            flash('All fields are required', 'error')
            return render_template('register.html')
        
        # Check if user already exists
        if User.query.filter_by(username=username).first():
            flash('Username already exists', 'error')
            return render_template('register.html')
        
        if User.query.filter_by(email=email).first():
            flash('Email already registered', 'error')
            return render_template('register.html')
        
        # Create new user
        user = User(username=username, email=email)
        user.set_password(password)
        db.session.add(user)
        db.session.commit()
        
        flash('Registration successful! Please log in.', 'success')
        return redirect(url_for('login'))
    
    return render_template('register.html')


@app.route('/login', methods=['GET', 'POST'])
def login():
    """User login page."""
    if current_user.is_authenticated:
        return redirect(url_for('events'))
    
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        user = User.query.filter_by(username=username).first()
        
        if user and user.check_password(password):
            login_user(user)
            flash('Logged in successfully!', 'success')
            return redirect(url_for('events'))
        else:
            flash('Invalid username or password', 'error')
    
    return render_template('login.html')


@app.route('/logout')
@login_required
def logout():
    """Log out the current user."""
    logout_user()
    flash('Logged out successfully!', 'success')
    return redirect(url_for('index'))


@app.route('/events')
@login_required
def events():
    """List all events."""
    all_events = Event.query.order_by(Event.created_at.desc()).all()
    return render_template('events.html', events=all_events)


@app.route('/event/create', methods=['GET', 'POST'])
@login_required
def create_event():
    """Create a new event."""
    if request.method == 'POST':
        name = request.form.get('name')
        description = request.form.get('description')
        
        if not name:
            flash('Event name is required', 'error')
            return render_template('create_event.html')
        
        event = Event(name=name, description=description, creator_id=current_user.id)
        # Creator automatically joins the event
        event.members.append(current_user)
        db.session.add(event)
        db.session.commit()
        
        flash('Event created successfully!', 'success')
        return redirect(url_for('event_detail', event_id=event.id))
    
    return render_template('create_event.html')


@app.route('/event/<int:event_id>')
@login_required
def event_detail(event_id):
    """View event details and photos."""
    event = Event.query.get_or_404(event_id)
    is_member = current_user in event.members
    return render_template('event_detail.html', event=event, is_member=is_member)


@app.route('/event/<int:event_id>/join')
@login_required
def join_event(event_id):
    """Join an event."""
    event = Event.query.get_or_404(event_id)
    
    if current_user in event.members:
        flash('You are already a member of this event', 'info')
    else:
        event.members.append(current_user)
        db.session.commit()
        flash('Successfully joined the event!', 'success')
    
    return redirect(url_for('event_detail', event_id=event_id))


@app.route('/event/<int:event_id>/upload', methods=['GET', 'POST'])
@login_required
def upload_photo(event_id):
    """Upload a photo to an event."""
    event = Event.query.get_or_404(event_id)
    
    # Check if user is a member
    if current_user not in event.members:
        flash('You must be a member of this event to upload photos', 'error')
        return redirect(url_for('event_detail', event_id=event_id))
    
    if request.method == 'POST':
        # Check if files were uploaded
        if 'photos' not in request.files:
            flash('No files selected', 'error')
            return redirect(request.url)
        
        files = request.files.getlist('photos')
        uploaded_count = 0
        
        for file in files:
            if file and file.filename and allowed_file(file.filename):
                # Generate unique filename
                original_filename = secure_filename(file.filename)
                extension = original_filename.rsplit('.', 1)[1].lower()
                unique_filename = f"{uuid.uuid4()}.{extension}"
                
                # Save file
                file_path = os.path.join(app.config['UPLOAD_FOLDER'], unique_filename)
                file.save(file_path)
                
                # Create database entry
                photo = Photo(
                    filename=unique_filename,
                    original_filename=original_filename,
                    event_id=event_id,
                    uploader_id=current_user.id
                )
                db.session.add(photo)
                uploaded_count += 1
        
        if uploaded_count > 0:
            db.session.commit()
            flash(f'Successfully uploaded {uploaded_count} photo(s)!', 'success')
        else:
            flash('No valid photos were uploaded', 'error')
        
        return redirect(url_for('event_detail', event_id=event_id))
    
    return render_template('upload_photo.html', event=event)


@app.route('/photo/<int:photo_id>')
@login_required
def view_photo(photo_id):
    """View a single photo."""
    photo = Photo.query.get_or_404(photo_id)
    
    # Check if user is a member of the event
    if current_user not in photo.event.members:
        flash('You must be a member of this event to view photos', 'error')
        return redirect(url_for('events'))
    
    file_path = os.path.join(app.config['UPLOAD_FOLDER'], photo.filename)
    
    # Validate file path is within upload folder (prevent path traversal)
    upload_folder = os.path.abspath(app.config['UPLOAD_FOLDER'])
    abs_file_path = os.path.abspath(file_path)
    if not abs_file_path.startswith(upload_folder):
        flash('Invalid file path', 'error')
        return redirect(url_for('events'))
    
    # Determine MIME type based on file extension
    extension = photo.filename.rsplit('.', 1)[1].lower() if '.' in photo.filename else ''
    mime_types = {
        'png': 'image/png',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'gif': 'image/gif'
    }
    mimetype = mime_types.get(extension, 'image/jpeg')
    
    return send_file(abs_file_path, mimetype=mimetype)


@app.route('/event/<int:event_id>/download')
@login_required
def download_event_photos(event_id):
    """Download all photos from an event, excluding the user's own uploads."""
    event = Event.query.get_or_404(event_id)
    
    # Check if user is a member
    if current_user not in event.members:
        flash('You must be a member of this event to download photos', 'error')
        return redirect(url_for('event_detail', event_id=event_id))
    
    # Get all photos from the event except those uploaded by current user
    photos = Photo.query.filter(
        Photo.event_id == event_id,
        Photo.uploader_id != current_user.id
    ).all()
    
    if not photos:
        flash('No photos available to download (excluding your own uploads)', 'info')
        return redirect(url_for('event_detail', event_id=event_id))
    
    # Create zip file in memory
    memory_file = BytesIO()
    upload_folder = os.path.abspath(app.config['UPLOAD_FOLDER'])
    
    with zipfile.ZipFile(memory_file, 'w', zipfile.ZIP_DEFLATED) as zf:
        for photo in photos:
            file_path = os.path.join(app.config['UPLOAD_FOLDER'], photo.filename)
            abs_file_path = os.path.abspath(file_path)
            
            # Validate file path is within upload folder (prevent path traversal)
            if abs_file_path.startswith(upload_folder) and os.path.exists(abs_file_path):
                # Add file to zip with original filename
                zf.write(abs_file_path, photo.original_filename)
    
    memory_file.seek(0)
    
    return send_file(
        memory_file,
        mimetype='application/zip',
        as_attachment=True,
        download_name=f'{event.name}_photos.zip'
    )


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True, host='0.0.0.0', port=5000)
