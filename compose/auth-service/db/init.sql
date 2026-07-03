CREATE TABLE IF NOT EXISTS api_keys (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    
    -- key_hash armazena o hash SHA-256 da chave, que tem 64 caracteres hexadecimais
    key_hash VARCHAR(64) NOT NULL UNIQUE, 
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Seed de chave de serviço local para comunicação entre microsserviços no Docker Compose.
-- Chave em texto plano correspondente: tm_key_local_service_123
INSERT INTO api_keys (name, key_hash, is_active)
VALUES (
    'local-service-key',
    'e6711c6fada94859a10e18b5cb8b9450c5afd97935282ae99b931b0b429e79d4',
    true
)
ON CONFLICT (key_hash) DO NOTHING;