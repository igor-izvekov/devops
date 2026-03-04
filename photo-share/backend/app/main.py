import os
from flask import Flask, render_template, jsonify, request, send_file
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from flask_migrate import Migrate
from datetime import datetime
import uuid
from werkzeug.utils import secure_filename
import logging

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Инициализация расширений
db = SQLAlchemy()
login_manager = LoginManager()
migrate = Migrate()

def create_app():
    app = Flask(__name__)

    # Конфигурация
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-key-change-in-production')
    app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'sqlite:///photos.db')
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    # Настройки загрузки файлов
    app.config['UPLOAD_FOLDER'] = os.getenv('UPLOAD_FOLDER', '/app/uploads')
    app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024
    app.config['ALLOWED_EXTENSIONS'] = {'png', 'jpg', 'jpeg', 'gif', 'webp'}

    # Создаем папку для загрузок
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(os.path.join(app.config['UPLOAD_FOLDER'], 'thumbnails'), exist_ok=True)

    # Инициализация расширений
    db.init_app(app)
    login_manager.init_app(app)
    login_manager.login_view = 'auth.login'
    migrate.init_app(app, db)

    # Регистрация blueprints
    from app.routes import upload, photos, auth
    app.register_blueprint(upload.bp)
    app.register_blueprint(photos.bp)
    app.register_blueprint(auth.bp)

    # Главная страница
    @app.route('/')
    def index():
        return render_template('index.html')
    
    # API статус
    @app.route('/api/health')
    def health():
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'version': '1.0.0',
        })
    
    logger.info(f"App started in {os.getenv('FLASK_ENV', 'production')} mode")

    return app
