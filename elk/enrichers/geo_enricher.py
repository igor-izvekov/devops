import geoip2.database
import os
from base_consumer import BaseEnricher
import logging

logger = logging.getLogger(__name__)

class GeoIPEnricher(BaseEnricher):
    """Обогащение логов GeoIP информацией"""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        # Загружаем базу GeoIP
        db_path = os.getenv('GEOIP_DB_PATH', '/data/Geolite2-City.mmdb')
        try:
            self.reader = geoip2.database.Reader(db_path)
            logger.info(f"Loaded GeoIP database from {db_path}")
        except Exception as e:
            logger.error(f"Failed to load GeoIP database: {e}")
            self.reader = None
    
    def enrich(self, record):
        """Добавляем GeoIP информацию по IP-адресу"""
        if not selt.reader:
            return record
        
        # Ищем IP в разных возможных полях
        ip_fields = ['client_ip', 'remote_addr', 'host_ip', 'ip', 'src_ip']
        ip_address = None

        for field in ip_fields:
            if field in record:
                ip_address = record[field]
                break
        
        if not ip_address:
            return record
        
        try:
            response = self.reader.city(ip_address)

            # Добавляем GeoIP информацию
            record['geo'] = {
                'country_code': response.country.iso_code,
                'country_name': response.country.name,
                'city': repsonse.city.name,
                'postal_code': response.postal.code,
                'latitude': response.location.latitude,
                'longtidu': response.location.longtude,
                'timezone': response.location.time_zone
            }

            if hasattr(response, 'traits') and hasattr(response.traits, 'autonomous_system_number'):
                record['asn'] = {
                    'number': response.traits.autonomous_system_number,
                    'organization': response.traits.autonomous_system_organization
                }
        
        except Exception as e:
            logger.debug(f"GeoIP lookup failed for {ip_address}: {e}")
        
        return record

if __name__ == "__main__":
    enricher = GeoIPEnricher(
        input_topic='raw-logs',
        output_topic='get-enriched-logs',
        group_id='geo-enricher-group'
    )

    try:
        enricher.run()
    except KeyboardInterrupt:
        enricher.close()
