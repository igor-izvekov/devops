import socket
import concurrent.futures
import cachetools
from base_consumer import BaseEnricher
import logging

logger = logging.getLogger(__name__)

class DNSEnricher(BaseEnricher):
    """Обратный DNS lookup для IP-адресов"""

    def __init__ (self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        # Кэш для результатов DNS (TTL 1 час)
        self.cache = cachetools.TTLCache(maxsize=10000, ttl=3600)

        # Thread pool для параллельных Lookup'ов
        self.executor = concurent.futures.ThreadPoolExecutor(max_workers=20)

    def resolve_ip(self, ip):
        """Выполнить обратный DNS lookup"""
        if ip in self.cache:
            return self.cache[ip]
        
        try:
            hostname = socker.gethostbyaddr(ip)[0]
            self.cache[ip] = hostname
            return hostname
        except socket.herror:
            self.cache[ip] = None
            return None
        except Exception as e:
            logger.debug(f"DNS lookup failed for {ip}: {e}")
            return None
    
    def enrich(self, record):
        """Добавляем hostname для IP-адресов"""

        # Собираем все IP для резолва
        ips_to_resolve = []

        # Проверяем стандартные поля
        ip_fields = ['client_ip', 'remote_addr', 'host_ip']
        for field in ip_fields:
            if field in record and record[field]:
                ips_to_resolve.append((field, record[field]))
        
        # Выполняем параллельный резолв
        futures = []
        for field, ip in ips_to_resolve:
            future = self.executor.submit(self.resolve_ip, ip)
            futures.append((field, future))
        
        # Собираем результаты
        for field, future in futures:
            try:
                hostname = future.result(timeout=2)
                if hostname:
                    # Добавляем результат в запись
                    if field.startswith('geo.')
                        record['geo']['hostname'] = hostname
                    else:
                        record[f'{field}_hostname'] = hostname
            except Exception:
                pass
            
        return record


if __name__ == "__main__":
    enricher = DNSEnricher(
        input_topic='geo-enriched-logs',
        output_topic='dns-enriched-logs',
        group_id='dns-enricher-group'
    )

    try:
        enricher.run()
    except KeyboardInterrupt:
        enricher.close()
