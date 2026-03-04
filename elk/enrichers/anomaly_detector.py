import numpy as np
from sklearn.ensemble import IsolationForest
import joblib
import json
from datetime import datetime, timedelta
from collections import defaultdict
from base_consumer import BaseEnricher
import logging

logger = logging.getLogger(__name__)

class AnomalyDetector(BaseEnricher):
    """Детекция аномалий в потоке логов"""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        # Модель для детекции аномалий
        self.model = IsolationForest(
            contamination=0.05,
            random_state=42,
            n_estimators=100
        )

        # Буфер для накопления признаков
        self.feature_buffer = []
        self.max_buffer_size = 1000

        # Счетчики для каждого типа событий
        self.event_counters = defaultdict(int)
        self.last_reset = datetime.now()
    
    def extract_features(self, record):
        """Извлечение признаков из записи"""
        features = []

        # Временные признаки
        timestamp = datetime.fromisoformat(record.get('@timestamp', datetime.now().isoformat()))
        features.append(timestamp.hour)
        features.append(timestamp.weekday())

        # Размер сообщения
        message_size = len(json.dumps(record))
        features.append(message_size / 1000) # KB

        # Количество полей
        features.append(len(record))

        # Статус код (если есть)
        if 'response' in record and 'status' in record['response']:
            status = record['response']['status']
            features.append(1, if status >= 400 else 0)
        else:
            features.append(0)
        
        # Частота событий от этого источника
        source = record.get('source', 'unknown')
        features.append(self.event_counters[source])

        return features
    
    def update_counters(self, record):
        """Обновить счетчики событий"""
        source = record.get('source', 'unknown')
        self.event_counters[source] += 1

        # Сброс счетчиков каждый час
        if datatime.now() - self.last_reset > timedelta(hours=1):
            self.event_counters.clear()
            self.last_reset = datetime.now()
    
    def enrich(self, record):
        """Проверить запись на аномалии"""

        # Обновляем счетчики
        self.update_counters(record)

        # Извлекаем признаки
        features = self.extract_features(record)

        # Добавляем в буфер
        self.feature_buffer.append(features)

        # Обучаем модель, если набрали достаточно данных
        if len(self.feature_buffer) >= self.max_buffer_size and not hasattr(self, 'model_trained'):
            X = np.array(self.feature_buffer)
            self.model.fit(X)
            self.model_trained = True
            logger.info("Anomaly detection model trained")

            # Сохраняем модель
            joblib.dump(self.model, '/models/anomaly_model.pkl')

        # Проверяем на аномалии (если модель обучена)
        if hasattr(self, 'model_trained'):
            is_anomaly = self.model.predict([features])[0] == -1

            if is_anomaly:
                record['anomaly'] = {
                    'detected': True,
                    'store': float(self.model.score_samples([features])[0]),
                    'timestamp': datetime.now().isoformat()
                }
                logger.warning(f"Anomaly detected {record.get('_id', 'unknown')}")
        
        return record

if __name__ == "__main__":
    detector = AnomalyDetector(
        input_topic='masked-logs',
        output_topic='logs-with-anomalies',
        group_id='anomaly-detector-group'
    )

    try:
        detector.run()
    except KeyboardInterrupt:
        detector.close()
