import re
import hashlib
from base_consumer import BaseEnricher
import logging

logger = logging.getLogger(__name__)

class PIIMasker(BaseEnricher):
    """Маскирование персональных данных"""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        # Регулярные выражения для поиска PII
        self.patterns = {
            'email': re.compile(r'[a-zA-Z0-9_%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
            'phone': re.compile(r'\+?[\d\s-]{10,15}'),
            'credit_card': re.compile(r'\d{4}[- ]?\d{4}[- ]?\d{4}'),
            'ip_address': re.compile(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'),
            'ssn': re.compile(r'\d{3}-\d{2}-\d{4}'),
        }

        # Поля, которые всегда нужно маскировать
        self.sensitive_fields = [
            'password', 'credit_card', 'ssn', 'token', 'secret',
            'authorization', 'api_key', 'access_token'
        ]

    def mask_value(self, value, pattern_type):
        """Маскировать значение"""
        if pattern_type == 'email':
            local, domain = value.split('@')
            return f'{local[0]}****@{domain}'
        elif pattern_type == 'credit_card':
            return f"****-****-****-{value[-4:]}"
        elif pattern_type == 'phone':
            return f"+****{value[-4:]}"
        else:
            # Для всего остального - хеширование
            return hashlib.sha256(value.encode()).hexdigest()[:16]
    
    def mask_text(self, text):
        """Маскировать PII в тексте"""
        if not isinstance(text, str):
            return text
        
        masked = text
        for pii_type, pattern in self.patterns.items():
            matches = pattern.findall(masked)
            for match in matches:
                masked = masked.replace(match, self.mask_value(match, pii_type))

        return masked
    
    def mask_dict(self, data, path=""):
        """Рекурсивно маскировать словарь"""
        if isinstance(data, dict):
            result = {}
            for key, value in data.items():
                # Проверяем, нужно ли маскровать это поле
                if any(sensitive in key.lower() for sensitive in self.sensitive_fields):
                    result[key] = "***MASKED***"
                else:
                    result[key] = self.mask_dict(value, "f{path}.{key}" if path else key)
            return result
        
        elif isinstance(data, list):
            return [self.mask_dict(item, f"{path}[]") for item in data]
        
        elif isinstance(data, str):
            return self.mask_text(data)
        
        else:
            return data
        
    def enrich(self, record):
        """Маскировать PII в записи"""
        return self.mask_dict(record)


if __name__ == "__main__":
    enricher = PIIMasker(
        input_topic='dns-enriched-logs',
        output_topic='masked-logs',
        group_id='pii-masker-group'
    )

    try:
        enricher.run()
    except KeyboardInterrupt:
        enricher.close()
