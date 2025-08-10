# Flask Sync API - Clean Version
# Server -> Terminal: downloads/
# Terminal -> Server: uploads/
# User customizations: downloads/users/{user_id}/

import os
import jwt
import pytz
import datetime
import json
import hashlib
from typing import Optional, Tuple

from flask import Flask, request, jsonify, send_file

app = Flask(__name__)

# Configuration
JWT_KEY = 'MyOwnSecretKey'
DATA_HOME = './dataroot'
TOKEN_DURATION = 300  # 5 minutes

# Simple user management (can be loaded from YAML)
jwt_users = {
    'androiduser': 'secret',
    'U001': 'password1',
    'U002': 'password2',
    'myuser': 'mysecret',
    'sync_client': 'sync_password'
}

# Management users that can access any folder and don't have default folders
MANAGEMENT_USERS = ['androiduser', 'sync_client']

# Global restriction: if True, regular users can ONLY use their user_id as folder
RESTRICTED = False  # Set to True to enforce user_id = folder_name


def ensure_user_directories(user_folder: str) -> None:
    """Create directories for a specific user folder if they don't exist"""
    if not user_folder:
        return

    # Create user-specific download directory
    user_download_dir = os.path.join(DATA_HOME, 'downloads', 'users', user_folder)
    os.makedirs(user_download_dir, exist_ok=True)

    # Create user-specific upload directory
    user_upload_dir = os.path.join(DATA_HOME, 'uploads', user_folder)
    os.makedirs(user_upload_dir, exist_ok=True)


def setup_directories() -> None:
    """Create required directory structure"""
    dirs = [
        'downloads',           # Server -> Terminal files
        'uploads',            # Terminal -> Server files
        'downloads/users',    # User-specific downloads
        'logs'               # Sync logs
    ]

    for dir_path in dirs:
        full_path = os.path.join(DATA_HOME, dir_path)
        os.makedirs(full_path, exist_ok=True)

    # Create directories for regular users (user_id = folder_name by default)
    for login_user in jwt_users.keys():
        if login_user not in MANAGEMENT_USERS:
            ensure_user_directories(login_user)


def log_sync_operation(user_id: str, operation: str, details: str):
    """Log sync operations"""
    timestamp = datetime.datetime.now().isoformat()
    log_entry = {
        'timestamp': timestamp,
        'user_id': user_id,
        'operation': operation,
        'details': details
    }

    log_file = os.path.join(DATA_HOME, 'logs', f'sync_{datetime.date.today().isoformat()}.json')

    # Append to daily log file
    logs = []
    if os.path.exists(log_file):
        with open(log_file, 'r') as f:
            try:
                logs = json.load(f)
            except json.JSONDecodeError:
                logs = []

    logs.append(log_entry)

    with open(log_file, 'w') as f:
        json.dump(logs, f, indent=2)


def get_user_folder(login_user: str, requested_folder: Optional[str] = None) -> Optional[str]:
    """Get data folder for user with global restriction option"""

    # Management users can access any folder
    if login_user in MANAGEMENT_USERS:
        return requested_folder if requested_folder else login_user

    # If RESTRICTED mode: regular users can ONLY use their user_id as folder
    if RESTRICTED:
        if requested_folder and requested_folder != login_user:
            return None  # Permission denied - can only use own user_id
        return login_user  # Always use user_id as folder

    # Non-restricted mode: use requested folder or fallback to user_id
    return requested_folder or login_user


def verify_token(token_str: str) -> Optional[Tuple[str, Optional[str]]]:
    """Verify JWT token and return (user_id, user_folder)"""
    try:
        payload = jwt.decode(token_str, JWT_KEY, algorithms=["HS256"])
        return payload['user_id'], payload.get('user_folder')
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:  # More generic exception
        return None
    except Exception:
        return None


@app.route('/api/v1/token', methods=['POST'])
def token():
    """Generate JWT token for user authentication"""
    try:
        user_id = request.form['user']
        password = request.form['password']
        requested_folder = request.form.get('folder')  # Optional folder parameter

        if user_id not in jwt_users or jwt_users[user_id] != password:
            log_sync_operation(user_id, 'AUTH_FAILED', 'Invalid credentials')
            return jsonify(error=True, message="Invalid credentials.")

    except KeyError as e:
        return jsonify(error=True, message=f"Missing parameter: {e}")

    # Get user folder with restriction check
    user_folder = get_user_folder(user_id, requested_folder)

    # Check if access was denied due to restriction
    if user_folder is None:
        log_sync_operation(user_id, 'AUTH_FAILED', 'Restricted mode: can only access own folder')
        return jsonify(error=True, message="In restricted mode, users can only access their own folder.")

    # Ensure directories exist for the assigned folder
    if user_folder:
        ensure_user_directories(user_folder)

    # Create JWT token
    payload = {
        'user_id': user_id,
        'user_folder': user_folder,  # Include folder in token
        'exp': datetime.datetime.now(tz=pytz.utc) + datetime.timedelta(seconds=TOKEN_DURATION)
    }

    # Handle different PyJWT versions
    try:
        # PyJWT >= 2.0
        token = jwt.encode(payload, JWT_KEY, algorithm="HS256")
    except AttributeError:
        # PyJWT < 2.0 (returns bytes, need to decode)
        token = jwt.encode(payload, JWT_KEY, algorithm="HS256").decode('utf-8')

    log_info = f'Token generated for {TOKEN_DURATION}s'
    if user_folder:
        log_info += f', folder: {user_folder}'

    log_sync_operation(user_id, 'AUTH_SUCCESS', log_info)

    return jsonify(
        error=False,
        message=f"Token valid for {TOKEN_DURATION} seconds.",
        token=token,
        user_folder=user_folder  # Return assigned folder to client
    )


@app.route('/api/v1/downloads', methods=['POST'])
def list_downloads():
    """List files available for download (Server -> Terminal)"""
    try:
        token_str = request.form['token']
        auth_result = verify_token(token_str)

        if not auth_result:
            return jsonify(error=True, message="Invalid or expired token.")

        user_id, user_folder = auth_result

    except KeyError:
        return jsonify(error=True, message="Missing token parameter.")

    files = []

    # Global download files (for all users)
    downloads_dir = os.path.join(DATA_HOME, 'downloads')
    if os.path.exists(downloads_dir):
        for item in os.listdir(downloads_dir):
            item_path = os.path.join(downloads_dir, item)
            if os.path.isfile(item_path):  # Only files, not subdirectories
                files.append(f'downloads/{item}')

    # User-specific files (if user has assigned folder)
    if user_folder:
        user_downloads = os.path.join(DATA_HOME, 'downloads', 'users', user_folder)
        if os.path.exists(user_downloads):
            for item in os.listdir(user_downloads):
                item_path = os.path.join(user_downloads, item)
                if os.path.isfile(item_path):
                    files.append(f'downloads/users/{user_folder}/{item}')

    log_sync_operation(user_id, 'LIST_DOWNLOADS', f'Found {len(files)} files, folder: {user_folder}')

    return jsonify(
        error=False,
        message="Files available for download.",
        files=files
    )


@app.route('/api/v1/download_auto', methods=['POST'])
def download_file_auto():
    """Download file with automatic fallback: user-specific -> global"""
    try:
        token_str = request.form['token']
        filename = request.form['file']  # Just filename, not full path

        auth_result = verify_token(token_str)
        if not auth_result:
            return jsonify(error=True, message="Invalid or expired token.")

        user_id, user_folder = auth_result

    except KeyError as e:
        return jsonify(error=True, message=f"Missing parameter: {e}")

    # Security check: prevent path traversal in filename
    if '..' in filename or '/' in filename or '\\' in filename:
        return jsonify(error=True, message="Invalid filename. Use filename only, no paths.")

    # Priority 1: User-specific file (if user has folder)
    if user_folder:
        user_file_path = os.path.join(DATA_HOME, 'downloads', 'users', user_folder, filename)
        if os.path.exists(user_file_path) and os.path.isfile(user_file_path):
            log_sync_operation(user_id, 'DOWNLOAD_AUTO', f'User file: downloads/users/{user_folder}/{filename}')
            return send_file(user_file_path)

    # Priority 2: Global shared file
    global_file_path = os.path.join(DATA_HOME, 'downloads', filename)
    if os.path.exists(global_file_path) and os.path.isfile(global_file_path):
        log_sync_operation(user_id, 'DOWNLOAD_AUTO', f'Global file: downloads/{filename}')
        return send_file(global_file_path)

    # File not found in either location
    log_sync_operation(user_id, 'DOWNLOAD_AUTO_NOT_FOUND', f'File: {filename}, folder: {user_folder}')
    return jsonify(error=True, message=f"File '{filename}' not found in user or global directories.")


@app.route('/api/v1/download', methods=['POST'])
def download_file():
    """Download a specific file"""
    try:
        token_str = request.form['token']
        file_path = request.form['file']

        auth_result = verify_token(token_str)
        if not auth_result:
            return jsonify(error=True, message="Invalid or expired token.")

        user_id, user_folder = auth_result

    except KeyError as e:
        return jsonify(error=True, message=f"Missing parameter: {e}")

    # Security check: ensure file is in allowed directories
    allowed = (
        file_path.startswith('downloads/') and
        (not file_path.startswith('downloads/users/') or
         (user_folder and file_path.startswith(f'downloads/users/{user_folder}/')))
    )

    if not allowed:
        return jsonify(error=True, message="Access denied to requested file.")

    full_path = os.path.join(DATA_HOME, file_path)

    if not os.path.exists(full_path) or not os.path.isfile(full_path):
        return jsonify(error=True, message="File not found.")

    log_sync_operation(user_id, 'DOWNLOAD', f'File: {file_path}, folder: {user_folder}')

    return send_file(full_path)


@app.route('/api/v1/upload', methods=['POST'])
def upload_files():
    """Upload files from terminal to server"""
    try:
        token_str = request.form['token']
        auth_result = verify_token(token_str)

        if not auth_result:
            return jsonify(error=True, message="Invalid or expired token.")

        user_id, user_folder = auth_result

    except KeyError:
        return jsonify(error=True, message="Missing token parameter.")

    if not request.files:
        return jsonify(error=True, message="No files provided.")

    # Use user_folder for upload directory, fallback to user_id if no folder mapping
    upload_folder = user_folder or user_id

    # Ensure upload directory exists
    upload_dir = os.path.join(DATA_HOME, 'uploads', upload_folder)
    os.makedirs(upload_dir, exist_ok=True)

    uploaded_files = []

    for key in request.files.keys():
        file = request.files[key]
        if file.filename:
            # Use original filename (client guarantees uniqueness)
            filename = file.filename
            file_path = os.path.join(upload_dir, filename)

            file.save(file_path)
            uploaded_files.append(filename)

    log_sync_operation(user_id, 'UPLOAD', f'Files: {uploaded_files}, folder: {upload_folder}')

    return jsonify(
        error=False,
        message="Files uploaded successfully.",
        uploaded_files=uploaded_files,
        upload_folder=upload_folder
    )


@app.route('/api/v1/uploads', methods=['POST'])
def list_uploads():
    """List uploaded files from terminals (for server processing)"""
    try:
        token_str = request.form['token']
        auth_result = verify_token(token_str)

        if not auth_result:
            return jsonify(error=True, message="Invalid or expired token.")

        user_id, user_folder = auth_result

        # Only allow listing uploads for management users
        if user_id not in MANAGEMENT_USERS:
            return jsonify(error=True, message="Access denied.")

    except KeyError:
        return jsonify(error=True, message="Missing token parameter.")

    all_uploads = {}
    uploads_dir = os.path.join(DATA_HOME, 'uploads')

    if os.path.exists(uploads_dir):
        for user_folder_name in os.listdir(uploads_dir):
            user_upload_path = os.path.join(uploads_dir, user_folder_name)
            if os.path.isdir(user_upload_path):
                files = [f for f in os.listdir(user_upload_path)
                         if os.path.isfile(os.path.join(user_upload_path, f))]
                if files:
                    all_uploads[user_folder_name] = files

    log_sync_operation(user_id, 'LIST_UPLOADS', f'Found uploads for {len(all_uploads)} folders')

    return jsonify(
        error=False,
        message="Upload files listed.",
        uploads=all_uploads
    )


@app.route('/api/v1/sync_upload', methods=['POST'])
def sync_upload():
    """Upload file to specific server path (for sync client)"""
    try:
        token_str = request.form['token']
        target_path = request.form['target_path']

        auth_result = verify_token(token_str)
        if not auth_result:
            return jsonify(error=True, message="Invalid or expired token.")

        user_id, user_folder = auth_result

        # Only sync clients can use this endpoint
        if user_id not in MANAGEMENT_USERS:
            return jsonify(error=True, message="Access denied.")

    except KeyError as e:
        return jsonify(error=True, message=f"Missing parameter: {e}")

    if 'file' not in request.files:
        return jsonify(error=True, message="No file provided.")

    file = request.files['file']
    if not file.filename:
        return jsonify(error=True, message="Empty file.")

    # Security check: prevent path traversal
    if '..' in target_path or target_path.startswith('/'):
        return jsonify(error=True, message="Invalid target path.")

    # Prevent overwriting uploads and logs from sync client
    if target_path.startswith('uploads/') or target_path.startswith('logs/'):
        return jsonify(error=True, message="Cannot sync to uploads or logs directories.")

    full_path = os.path.join(DATA_HOME, target_path)

    # Create directory if needed
    os.makedirs(os.path.dirname(full_path), exist_ok=True)

    # Save file
    file.save(full_path)

    log_sync_operation(user_id, 'SYNC_UPLOAD', f'File: {target_path}')

    return jsonify(
        error=False,
        message="File synced successfully.",
        path=target_path
    )


@app.route('/api/v1/sync_delete', methods=['POST'])
def sync_delete():
    """Delete file from server (for sync client cleanup)"""
    try:
        token_str = request.form['token']
        file_path = request.form['file']

        auth_result = verify_token(token_str)
        if not auth_result:
            return jsonify(error=True, message="Invalid or expired token.")

        user_id, user_folder = auth_result

        # Only sync clients can use this endpoint
        if user_id not in MANAGEMENT_USERS:
            return jsonify(error=True, message="Access denied.")

    except KeyError as e:
        return jsonify(error=True, message=f"Missing parameter: {e}")

    # Security check: prevent path traversal and protect critical directories
    if '..' in file_path or file_path.startswith('/'):
        return jsonify(error=True, message="Invalid file path.")

    # Allow deletion only from uploads and logs (for cleanup after sync)
    if not (file_path.startswith('uploads/') or file_path.startswith('logs/')):
        return jsonify(error=True, message="Can only delete from uploads or logs directories.")

    full_path = os.path.join(DATA_HOME, file_path)

    if not os.path.exists(full_path):
        return jsonify(error=True, message="File not found.")

    if not os.path.isfile(full_path):
        return jsonify(error=True, message="Path is not a file.")

    # Delete file
    os.remove(full_path)

    log_sync_operation(user_id, 'SYNC_DELETE', f'File: {file_path}')

    return jsonify(
        error=False,
        message="File deleted successfully."
    )


@app.route('/api/v1/file_metadata', methods=['POST'])
def file_metadata():
    """Get metadata for files (for sync comparison)"""
    try:
        token_str = request.form['token']

        auth_result = verify_token(token_str)
        if not auth_result:
            return jsonify(error=True, message="Invalid or expired token.")

        user_id, user_folder = auth_result

        # Only sync clients can use this endpoint
        if user_id not in MANAGEMENT_USERS:
            return jsonify(error=True, message="Access denied.")

    except KeyError as e:
        return jsonify(error=True, message=f"Missing parameter: {e}")

    metadata = {}

    # Get metadata for downloads directory (excluding uploads and logs)
    downloads_dir = os.path.join(DATA_HOME, 'downloads')
    if os.path.exists(downloads_dir):
        for root, dirs, files in os.walk(downloads_dir):
            for file in files:
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, DATA_HOME).replace('\\', '/')

                try:
                    stat = os.stat(file_path)
                    with open(file_path, 'rb') as f:
                        content = f.read()
                        file_hash = hashlib.sha256(content).hexdigest()

                    metadata[rel_path] = {
                        'size': stat.st_size,
                        'mtime': stat.st_mtime,
                        'hash': file_hash
                    }
                except Exception as e:
                    log_sync_operation(user_id, 'METADATA_ERROR', f'File: {rel_path}, Error: {str(e)}')

    log_sync_operation(user_id, 'METADATA_REQUEST', f'Files: {len(metadata)}')

    return jsonify(
        error=False,
        message="Metadata retrieved.",
        metadata=metadata
    )


@app.route('/api/v1/folders', methods=['GET'])
def list_folders():
    """List available user folders and current mappings"""
    # This endpoint doesn't require authentication for simplicity
    # In production, you might want to restrict this

    # Get existing folders
    existing_folders = []

    downloads_users_dir = os.path.join(DATA_HOME, 'downloads', 'users')
    if os.path.exists(downloads_users_dir):
        existing_folders.extend([d for d in os.listdir(downloads_users_dir)
                                 if os.path.isdir(os.path.join(downloads_users_dir, d))])

    uploads_dir = os.path.join(DATA_HOME, 'uploads')
    if os.path.exists(uploads_dir):
        existing_folders.extend([d for d in os.listdir(uploads_dir)
                                 if os.path.isdir(os.path.join(uploads_dir, d))])

    # Remove duplicates and sort
    existing_folders = sorted(set(existing_folders))

    return jsonify(
        error=False,
        message="Available folders and info",
        existing_folders=existing_folders,
        management_users=MANAGEMENT_USERS,
        restricted_mode=RESTRICTED,
        available_logins=list(jwt_users.keys())
    )


@app.route('/api/v1/create_folder', methods=['POST'])
def create_folder():
    """Create a new user folder structure"""
    try:
        token_str = request.form['token']
        folder_name = request.form['folder']

        auth_result = verify_token(token_str)
        if not auth_result:
            return jsonify(error=True, message="Invalid or expired token.")

        user_id, user_folder = auth_result

        # Only management users can create folders
        if user_id not in MANAGEMENT_USERS:
            return jsonify(error=True, message="Access denied.")

    except KeyError as e:
        return jsonify(error=True, message=f"Missing parameter: {e}")

    # Validate folder name (basic security)
    if not folder_name or not folder_name.replace('_', '').replace('-', '').isalnum():
        return jsonify(error=True, message="Invalid folder name. Use only letters, numbers, _ and -")

    # Create the folder structure
    ensure_user_directories(folder_name)

    log_sync_operation(user_id, 'CREATE_FOLDER', f'Created folder: {folder_name}')

    return jsonify(
        error=False,
        message=f"Folder '{folder_name}' created successfully.",
        folder=folder_name
    )


@app.route('/api/v1/status', methods=['GET'])
def status():
    """API status check"""
    return jsonify(
        error=False,
        message="Sync API is running",
        version="2.0",
        timestamp=datetime.datetime.now().isoformat()
    )


if __name__ == '__main__':
    setup_directories()

    print("Starting Flask Sync API")
    print(f"Data directory: {os.path.abspath(DATA_HOME)}")
    print(f"Users configured: {list(jwt_users.keys())}")
    print(f"Management users: {MANAGEMENT_USERS}")
    print(f"Restricted mode: {RESTRICTED}")

    app.run(host='0.0.0.0', port=5000, debug=True)
