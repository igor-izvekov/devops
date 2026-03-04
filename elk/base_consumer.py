from prometheus_client import start_http_server, Counter, Histogram, Gauge
import threading

# Метрики
messages_processed = Counter('enricher_messages_processed_total', 'Messages processed', ['enricher'])
messages_enriched = Counter('enricher_messages_enriched_total', "Messages enriched", ['enricher'])
errors_total = Counter('enricher_errors_total', 'Processing time', ['enricher'])
lag_gauge = Gauge('enricher_consumer_lag', 'Consumer lag', ['enricher'])

class BaseEnricher:
    def __init__(self, input_topic, output_topic, bootstrap_servers='localhost:9092', group_id=None):
        self.enricher_name = self.__class__.__name__
        threading.Thread(target=self._start_metrics_server, daemon=True).start()

    def _start_metrics_server(self):
        start_http_server(8000)
        logger.info(f"Prometheus metrics server started on port 8000")
    
    def run(self):
        for message in self.consumer:
            try:
                lag = self.consumer.highwater(message.topic, message.partition) - message.offset

                lag_gauge.labels(enricher=self.enricher_name).set(lag)

                with processing_time.labels(enricher=self.enricher_name).time():
                    record = message.value
                    messages_processed.labels(enricher=self.enricher_name).inc()

                    enriched_record = sef.enrich(record)

                    if enriched_record:
                        self.producer.send(self.output_topic, enriched_record)
                        messages_enriched.labels(enricher=self.enricher_name).inc()
                    
                except Exception as e:
                    errors_total.labels(enricher=self.enricher_name).inc()
                    logger.error(f"Error {e}")
