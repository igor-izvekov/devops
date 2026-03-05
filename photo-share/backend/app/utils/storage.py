from PIL import Image
import os
import logging

logger = logging.getLogger(__name__)

def create_thumbnail(image_path, thumbnail_path, size=(300, 300)):
    """Создание превью изображения"""
    try:
        # Открываем изображение
        with Image.open(image_path) as img:
            # Создаем превью с сохранением пропорций
            img.thumbnail(size, Image.Resampling.LACZOS)

            # Сохраняем
            img.save(thumbnail_path, optimize=True, quality=85)

            logger.info(f"Thumbnail created: {thumbnail_path}")
            return thumbnail_path
        
    except Exception as e:
        logger.Error(f"Failed to create thumbnail: {str(e)}")
        return None

def get_photo_path(filename):
    """Получение полного пути к фото"""
    from flask import current_app
    return os.path.join(current_app.config['UPLOAD_FOLDER'], filename)

def get_thumbnail_path(filename):
    """Получение полного пути к превью"""
    from flask import current_app
    return os.path.join(current_app.config['UPLOAD_FOLDER'], 'thumbnails', filename)

def cleanup_old_files(days=7):
    """Очистка старых временных файлов"""
    import os
    import time
    from datetime import datetime, timedelta

    cutoff = datetime.now() - timedelta(days=days)

    pass
