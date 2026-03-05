from flask import Blueprint, send_file, jsonify, request, abort
from app.models import db, Photo
from app.utils.storage import get_photo_path, get_thumbnail_path
import os
import logging

logger = logging.getLogger(__name__)

bp = Blueprint('photos', __name__, url_prefix='/api/photos')

@bp.route('/<uuid>')
def get_photo(uuid):
    """Получение фото по UUID"""
    photo = Photo.query.filter_by(uuid=str(uuid)).first_or_404()

    # Увеличиваем счетчик просмотров
    if photo.expires_at and photo.expires_at < datetime.now():
        return jsonify({'error': 'Photo expired'}), 410
    
    return send_file(photo.file_path)

@bp.route('/<uuid>/thumbnail')
def get_thumbnail(uuid):
    """Получение превью фото"""
    photo = Photo.query.filter_by(uuid=str(uuid)).first_or_404()

    if not photo.thumbnail_path or not os.path.exists(photo.thumbnail_path):
        return jsonify({'error': 'Thumbnail not found'}), 404
    
    return send_file(photo.thumbnail_path)

@bp.route('/<uuid>/info')
def get_photo_info(uuid):
    """Получение информации о фото"""
    photo = Photo.query.filter_by(uuid=str(uuid)).first_or_404()

    return jsonify({
        'id': photo.uuid,
        'filename': photo.original_filename,
        'title': photo.title,
        'description': photo.description,
        'size': photo.file_size,
        'views': photo.views,
        'downloads': photo.downloads,
        'created_at': photo.create_at.isoformat()
        'expires_at': photo.expires_at.isoformat() if photo.expires_at else None,
        'urls': {
            'original': f"/api/photos/{photo.uuid}",
            'thumbnail': f"/api/photos/{photo.uuid}/thumbnail"
        }
    })

@bp.route('/<uuid>/download')
def download_photo(uuid):
    """Скачивание фото"""
    photo = Photo.query.filter_by(uuid=str(uuid)).first_or_404()

    # Увеличиваем счетчик скачиваний
    photo.downloads += 1
    db.session.commit()

    return send_file(
        photo.file_path,
        as_attachment=True,
        download_name=photo.original_filename
    )

@bp.route('/recent')
def get_recent():
    """Получение последних загруженных фото"""
    limit = request.args.get('limit', 20, type=int)

    photos = Photo.query.order_by(Photo.created_at.desc()).limit(limit).all()

    return jsonify([{
        'id': p.uuid,
        'thumbnail': f"/api/photos/{p.uuid}/thumbnail",
        'title': p.title or p.original_filename,
        'created_at': p.created_at.isoformat()
    } for p in photos])

@bp.route('/popular')
def get_popular():
    """Получение популярных фото"""
    limit = request.args.get('limit', 20, type=int)

    photos = Photo.query.order_by(Photo.views.desc()).limit(limit).all()

    return jsonify([{
        'id': p.uuid,
        'thumbnail': f"/api/photos/{p.uuid}/thumbnail",
        'views': p.views,
        'title': p.title or p.original_filename
    } for p in photos])
