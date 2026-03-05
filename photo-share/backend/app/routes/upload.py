from flask import Blueprint, request, jsonify, current_app, url_for
from werkzeug.utils import secure_filename
from app.models import db, Photo, User
from app.utils.storage import save_photo, create_thumbnail
from app.utils.auth import login_required, get_current_user
import os
from datetime import datetime, timedelta
import uuid
import logging

logger = logging.getLogger(__name__)

bp = Blueprint('upload', __name__, url_prefix='/api/upload')

@bp.route('/', methods=['POST'])
def upload_file():
    """Загрузка одного файла"""
    try:
        # Проверяем, есть ли файл в запросе
        if 'file' not in request.files:
            return jsonify({'error': 'No file part'}), 400
        
        file = request.files['file']

        if file.filename == '':
            return jsonify({'error': 'No selected file'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'error': 'File type not allowed'}), 400
        
        # Получаем опциональные параметры
        title = request.form.get('title', '')
        description = request.form.get('description', '')
        is_public = request.form.get('is_public', 'true').lower() == 'true'

        # Сохраняем файл
        filename = secure_filename(file.filename)

        # Генерируем уникальное имя для сохранения
        ext = filename.rsplit('.', 1)[1].lower()
        unique_filename = f"{uuid.uuid4()}.{ext}"

        # Полный путь для сохранения
        file_path = os.path.join(current_app.config['UPLOAD_FOLDER'], unique_filename)

        # Сохраняем файл
        file.save(file_path)
        file_size = os.path.getsize(file_path)

        # Создаем превью
        thumbnail_path = create_thumbnail(file_path,
            os.path.join(current_app.config['UPLOAD_FOLDER'], 'thumbnails', unique_filename)
        )

        photo = Photo(
            filename=unique_filename,
            original_filename=filename,
            file_size=file_size,
            mime_type=file.mimetype,
            file_path=file_path,
            thumbnail_path=thumbnail_path,
            title=title,
            description=description,
        )

        # Если пользоватеьль авторизован, привязываем к нему
        user = get_current_user()
        if user:
            photo.user_id = user.id
        
        db.session.add(photo)
        db.session.commit()

        logger.info(f"File uploaded: {filename} -> {unique_filename}")

        return jsonify({
            'success': True,
            'photo': {
                'id': photo.uuid,
                'url': url_for('photos.get_photo', uuid=photo.uuid, _external=True),
                'thumbnail_url': url_for('photos.get_thumbnail', uuid=photo.uuid, _external=True)
                if thumbnail_path else None,
                'filename': photo.original_filename,
                'size': photo.file_size,
                'created_at': photo.created_at.isoformat()
            }
        }), 201
    
    except Exception as e:
        logger.error(f"Upload failed: {str(e)}")
        return jsonify({'error': str(e)}), 500

@bp.route('/multiple', methods=['POST'])
def upload_multiple():
    """Загрузка нескольких файлов"""
    if 'files[]' not in request.files:
        return jsonify({'error': 'No files part'}), 400
    
    files = request.fiels.getlist('files[]')

    if not files or files[0].filename == '':
        return jsonify({'error': 'No files selected'}), 400
    
    results = []
    errors = []

    for file in files:
        if file and allowed_file(file.filename):
            try:
                results.append({'filename': file.filename, 'success': True})
            except Exception as e:
                errors.append({'filename': file.filename, 'error': 'File type not allowed'})
    
    return jsonify({
        'success': True,
        'uploaded': results,
        'errors': errors
    })

@bp.route('/presigned', methods=['POST'])
@login_required
def create_presigned():
    """Создание presigned URL для прямой загрузки (для больших файлов)"""
    filename = request.json.get('filename')
    file_size = request.json.get('size', 0)

    if not filename:
        return jsonify({'error': 'Filename required'}), 400
    
    photo_uuid = str(uuid.uuid4())

    return jsonify({
        'upload_url': f"/api/upload/direct/{photo_uuid}",
        'photo_id': photo_uuid,
        'expires_in': 3600
    })
