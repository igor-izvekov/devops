import json
import logging
from kafka import KafkaConsumer, KafkaProducer
from abc import ABC, abstractmethod

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class BaseEnricher(ABC):
    """Базовый класс для всех обогатителей"""

    def __init__(self, input_topic, output_topic, bootstrap_servers="localhost:9092", group_id=None):
        self.input_topic = input_topic
        self.output_topic = output_topic
        self.bootstrap_servers = bootstrap_servers

        self.consumer = KafkaConsumer(
            input_topic,
            bootstrap_servers=bootstrap_servers,
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            auto_offset_reset='latest',
            enable_auto_commit=True,
            group_id=group_id or f"{self.__class__.__name__}-group",
            max_poll_records=100
        )

        self.producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            value_serialized=lambda v: json.dumps(v).encode('utf-8'),
            compression_type='gzip'
        )

        logger.info(f"Initialized {self.__class__.__name__}")
    
    @abstractmethod
    def enrich(self, record):
        """Метод обогащения - переопределить в наследниках"""
        pass

    def run(self):
        """Основной цикл обработки"""
        logger.info(f"Starting {self.__class__.__name__} consumption from {self.input_topic}")

        for message in self.consumer:
            try:
                record = message.value

                # Обогащаем запись
                enriched_record = self.enrich(record)

                if enriched_record:
                    # Отправляем в выходной топик
                    self.producer.send(self.output_topic, enriched_record)

                    # Логируем метрики (для Prometheus)
                    logger.debug(f"Enriched record: {record.get('_id', 'unknown')}")
                
        except Exception as e:
            logger.error(f"Error precessing record: {e}")
            # Отправляем в DLQ (Dead Letter Queue)
            self.producer.send('errors', {
                'original': record,
                'error': str(e),
                'enricher': self.__class__.__name__
            })
    
    def close(self):
        self.consumer.close()
        self.producer.close()
