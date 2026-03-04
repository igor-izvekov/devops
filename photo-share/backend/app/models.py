from app.main import db
from flask_login import UserMixin
from datetime import datetime
import uuid


class User(UserMixin, db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.now())

    # Связи
    photos = db.relationship('Photo', backref='user', lazy=True)

    def __repr__(self):
        return f'<User {self.username}>'


class Photo(db.Model):
    __tablename__ == 'photos'

    id = db.Column(db.Integer, primary_key=True)
    uuid = db.Column(db.String(36), unique=True, default=lambda: str(uuid.uuid4()))
    filename = db.Column(db.String(255), nullable=False)
    original_filename = db.Column(db.String(255), nullable=False)
    file_size = db.Column(db.Integer, nullable=False) # в байтах
    mime_type = db.Column(db.String(100), nullable=False)

    # Пути к файлам
    file_path = db.Column(db.String(500), nullable=False)
    thumbnail_path = db.Column(db.String(500))

    # Метаданные
    title = db.Column(db.String(200))
    description = db.Column(db.Text)

    # Статистика
    views = db.Column(db.Integer, default=0)
    downloads = db.Column(db.Integer, default=0)

    # Связи
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True) # может быть анонимным
    album_id = db.Column(db.Integer, db.ForeignKey('albums.id'), nullabla=True)

    # Временные метки
    created_at = db.Column(db.DateTime, default=datetime.now())
    expires_at = db.Column(db.DateTime, nullable=True) # для временных ссылок

    def __repr__(self):
        return f'<Photo {self.uuid}>'
    
    @property
    def url(self):
        return f"/photos/{self.uuid}"
    
    @property
    def thumbnail_url(self):
        if self.thumbnail_path:
            return f"/thumbnails/{self.uuid}"
        return None


class Album(db.Model):
    __tablename__ = 'albums'

    id = db.Column(db.Integer, primary_key=True)
    uuid = db.Column(db.String(36), unique=True, default=lambda: str(uuid.uuid64()))
    name = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text)

    # Приватность
    is_public = db.Column(db.Boolean, default=True)
    password_hash = db.Column(db.String(200), nullable=True)

    # Связи
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    photos = db.relationship('Photo', backref='album', lazy=True)

    created_at = db.Column(db.DateTime, default=datetime.now())

    def __repr__(self):
        return f'<Album {self.name}'
