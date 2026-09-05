# ToggleMaster Local Stack - Conteinerizacao e Validacao

Este documento descreve, de ponta a ponta, tudo o que foi realizado no projeto ao final existe um tutorial de testes e validações:

- analise tecnica dos 5 microsservicos
- criacao de Dockerfile para cada servico
- criacao de um unico docker-compose.yml na raiz
- subida do ecossistema completo local
- validacao funcional end-to-end

## 1. Pedido Original

O pedido inicial foi:

1. Garantir entendimento e execucao local do ecossistema.
2. Criar Dockerfile otimizado para cada um dos 5 microsservicos.
3. Criar um docker-compose.yml unico na raiz para subir:
   - 5 microsservicos
   - 4 bancos locais (2 PostgreSQL, 1 Redis, 1 DynamoDB Local)

## 2. Escopo Encontrado no Projeto

Foram identificados os seguintes servicos:

- auth-service (Go)
- flag-service (Python/Flask + PostgreSQL)
- targeting-service (Python/Flask + PostgreSQL)
- evaluation-service (Go + Redis + integracao com flag/targeting + SQS opcional)
- analytics-service (Python/Flask + worker SQS + DynamoDB)

Dependencias de dados solicitadas no ambiente local:

- PostgreSQL #1: auth_db
- PostgreSQL #2: flags_db (compartilhado para flags e targeting)
- Redis
- DynamoDB Local

## 3. Arquitetura Local Implementada

### Containers de infraestrutura

- postgres-auth (PostgreSQL 16)
- postgres-flags (PostgreSQL 16)
- redis (Redis 7)
- dynamodb-local (Amazon DynamoDB Local)

### Containers de aplicacao

- auth-service (porta 8001)
- flag-service (porta 8002)
- targeting-service (porta 8003)
- evaluation-service (porta 8004)
- analytics-service (porta 8005)

## 4. Dockerfiles Criados

Foram criados Dockerfiles para todos os microsservicos:

- analytics-service/Dockerfile
- auth-service/Dockerfile
- evaluation-service/Dockerfile
- flag-service/Dockerfile
- targeting-service/Dockerfile

### Estrategia de imagem

- Servicos Go: build multi-stage (builder + runtime alpine)
- Servicos Python: instalacao de dependencias em estagio builder e copia para runtime slim
- Execucao com usuario nao-root nos containers
- Exposicao de portas de cada servico

## 5. docker-compose.yml Criado na Raiz

Arquivo criado:

- docker-compose.yml

Principais configuracoes aplicadas:

- build de cada servico a partir de seu contexto local
- mapeamento de portas para host
- variaveis de ambiente para conexoes entre servicos
- healthchecks para bancos/redis
- depends_on para ordem de inicializacao
- montagem dos scripts SQL de init em postgres-auth e postgres-flags
- volumes nomeados para persistencia dos PostgreSQL

## 6. Ajustes Necessarios para Build e Runtime Local

Durante a execucao real dos containers, surgiram incompatibilidades e problemas de build preexistentes no projeto original. Foram realizados os ajustes minimos para viabilizar o ambiente local funcional.

### 6.1 Ajustes em Python (Flask)

Problema encontrado:

- Flask 2.2.2 com versao recente de Werkzeug quebrava import em runtime.

Correcao aplicada:

- Pin de Werkzeug==2.2.2 em:
  - analytics-service/requirements.txt
  - flag-service/requirements.txt
  - targeting-service/requirements.txt

### 6.2 Ajustes em auth-service (Go)

Problemas encontrados:

- Dependencia invalida no go.mod (subpacote com versao semantica indevida)
- imports nao utilizados impedindo compilacao no build do container

Correcao aplicada:

- limpeza/ajuste de dependencias em auth-service/go.mod
- ajuste de import do driver pgx em auth-service/main.go
- remocao de imports nao usados em:
  - auth-service/handlers.go
  - auth-service/key.go

### 6.3 Ajustes em evaluation-service (Go)

Problemas encontrados:

- arquivo go.sum invalido (conteudo inconsistente)
- import nao utilizado impedindo compilacao

Correcao aplicada:

- remocao de evaluation-service/go.sum invalido
- ajuste do Dockerfile para gerar modulos de forma robusta no build
- remocao de import nao utilizado em evaluation-service/evaluator.go

### 6.4 Ajustes para execucao local com AWS opcional

Para suportar ambiente local sem dependencia obrigatoria de AWS real:

- analytics-service/app.py:
  - suporte a AWS_ENDPOINT_URL opcional
  - SQS opcional (worker desabilitado quando AWS_SQS_URL nao definida)
  - DynamoDB pode apontar para DynamoDB Local

- evaluation-service/main.go:
  - suporte a AWS_ENDPOINT_URL opcional para cliente SQS

### 6.5 Seed de chave de servico local

Para facilitar autenticacao entre microsservicos no compose:

- inserida seed de API key hash em auth-service/db/init.sql
- chave em texto plano utilizada no compose para chamadas internas:
  - tm_key_local_service_123

## 7. Arquivos Modificados e Criados

### Criados

- docker-compose.yml
- README.md (este arquivo)
- analytics-service/Dockerfile
- auth-service/Dockerfile
- evaluation-service/Dockerfile
- flag-service/Dockerfile
- targeting-service/Dockerfile

### Modificados

- analytics-service/app.py
- analytics-service/requirements.txt
- auth-service/db/init.sql
- auth-service/go.mod
- auth-service/main.go
- auth-service/handlers.go
- auth-service/key.go
- evaluation-service/main.go
- evaluation-service/evaluator.go
- evaluation-service/Dockerfile
- flag-service/requirements.txt
- targeting-service/requirements.txt

### Removido

- evaluation-service/go.sum

## 8. Como Subir o Ambiente

Na raiz do projeto (mesmo nivel do docker-compose.yml):

```bash
docker compose up -d --build
```

Para visualizar status:

```bash
docker compose ps
```

Para derrubar:

```bash
docker compose down
```

Para derrubar removendo volumes de banco:

```bash
docker compose down -v
```

## 9. Validacao de Saude

Health checks esperados:

```bash
curl -s http://localhost:8001/health
curl -s http://localhost:8002/health
curl -s http://localhost:8003/health
curl -s http://localhost:8004/health
curl -s http://localhost:8005/health
```

Resposta esperada em todos os servicos:

```json
{"status":"ok"}
```

## 10. Smoke Test End-to-End Executado

Foi executado um teste funcional completo entre os servicos:

1. Criacao de API key no auth-service
2. Validacao da key
3. Criacao de flag no flag-service
4. Criacao de regra no targeting-service
5. Avaliacao no evaluation-service para usuarios distintos
6. Repeticao da avaliacao para validar cache HIT

Resultado:

- fluxo funcional validado com sucesso
- cache MISS/HIT confirmado em logs do evaluation-service
- envio de evento marcado como SQS_DISABLED no modo local atual (esperado)

## 11. Observacoes Importantes

- O compose atende ao requisito de subir os 5 microsservicos + 4 datastores locais.
- O ambiente foi validado com build e runtime reais, nao apenas por analise estaticas de arquivos.
- Alguns ajustes em codigo foram necessarios para corrigir inconsistencias do estado original e permitir execucao conteinerizada completa.

## 12. Estado Final

O projeto ficou pronto para:

- subir localmente com um unico comando
- validar o ecossistema completo de forma reproduzivel
- servir de base para evolucoes (testes automatizados, CI, observabilidade, hardening de seguranca e performance)

---

## 📋 Resumo dos Microsserviços

### **1. auth-service** (Go)
**Porta:** 8001  
**Propósito:** Gerenciamento de autenticação e validação de chaves de API  
**Banco de Dados:** PostgreSQL (`api_keys` table)  
**Principais Endpoints:**
- `GET /health` - Health check
- `GET /validate` - Valida chave de API via header `Authorization: Bearer <key>`
- `POST /admin/keys` - Cria nova chave de API (requer MASTER_KEY)

**Funcionalidades:**
- Geração de chaves de API seguras com hash
- Validação de chaves para proteção dos demais serviços
- Gerenciamento de ativação/desativação de chaves

---

### **2. flag-service** (Python/Flask)
**Porta:** 8002  
**Propósito:** CRUD de definições de feature flags  
**Banco de Dados:** PostgreSQL (`flags` table)  
**Principais Endpoints:**
- `GET /health` - Health check
- `POST /flags` - Cria nova feature flag
- Operações CRUD completas (requer autenticação)

**Funcionalidades:**
- Gerenciar estados de flags (enabled/disabled)
- Definir descrições e metadados
- Requer autenticação via chave de API

---

### **3. targeting-service** (Python/Flask)
**Porta:** 8003  
**Propósito:** Gerenciamento de regras de segmentação complexas para flags  
**Banco de Dados:** PostgreSQL (`targeting_rules` table com JSON)  
**Principais Endpoints:**
- `GET /health` - Health check
- `POST /rules` - Cria regra de segmentação
- Operações CRUD completas (requer autenticação)

**Funcionalidades:**
- Criar regras complexas (ex: "50% dos usuários", "usuários do país X")
- Armazenar regras como JSON estruturado
- Requer autenticação via chave de API

---

### **4. evaluation-service** (Go)
**Porta:** 8004  
**Propósito:** Avaliação rápida de feature flags (hot path - caminho crítico)  
**Tecnologias:** Cache Redis, Mensageria AWS SQS  
**Principais Endpoints:**
- `GET /health` - Health check
- `GET /evaluate?user_id=...&flag_name=...` - Avalia se uma flag está ativa para um usuário

**Fluxo:**
1. Verifica cache Redis
2. Se miss, busca definição no flag-service e regra no targeting-service
3. Executa lógica de avaliação
4. Retorna `true` ou `false`
5. Envia evento assincronamente para SQS

---

### **5. analytics-service** (Python)
**Porta:** 8005  
**Propósito:** Worker backend que processa e armazena eventos de avaliação  
**Tecnologias:** Mensageria AWS SQS, Armazenamento AWS DynamoDB  
**Principais Endpoints:**
- `GET /health` - Health check

**Funcionalidades:**
- Loop contínuo que ouve a fila SQS
- Processa mensagens de eventos de avaliação
- Persiste dados em tabela DynamoDB
- Não possui API pública (worker assincronado)

---

### **📊 Diagrama de Fluxo**

```
Cliente
   ↓
[evaluation-service] ← autenticação/definições ← [flag-service]
   ↓                                    ↑
   ├→ [auth-service] (validação)        └→ [targeting-service]
   ↓
[Redis cache]
   ↓
Evento → [AWS SQS]
            ↓
    [analytics-service] → [AWS DynamoDB]
```

---

## 🧪 Guia de Testes após Docker Compose

Depois que rodar `docker compose up --build`, siga estes passos para testar os serviços:

### **1️⃣ Verificar Status dos Containers**

```bash
docker compose ps
```

Todos os 5 serviços devem estar `Up`.

---

### **2️⃣ Testar auth-service (porta 8001)**

**Health Check:**
```bash
curl http://localhost:8001/health
```
✅ Saída esperada: `{"status":"ok"}`

**Criar uma chave de API (com MASTER_KEY):**
```bash
curl -X POST http://localhost:8001/admin/keys \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer admin-secreto-123" \
  -d '{"name": "minha-primeira-chave"}'
```
✅ Saída esperada:
```json
{
  "name": "minha-primeira-chave",
  "key": "tm_key_xxxxxxx",
  "message": "Guarde esta chave com segurança!"
}
```
💾 **Copie a chave retornada para usar nos próximos testes**

**Validar a chave (substitua pela chave obtida):**
```bash
curl http://localhost:8001/validate \
  -H "Authorization: Bearer tm_key_xxxxxxx"
```
✅ Saída esperada: `{"valid":true}`

---

### **3️⃣ Testar flag-service (porta 8002)**

**Health Check:**
```bash
curl http://localhost:8002/health
```

**Criar uma feature flag (use a chave do passo anterior):**
```bash
curl -X POST http://localhost:8002/flags \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer tm_key_xxxxxxx" \
  -d '{
    "name": "enable-new-dashboard",
    "description": "Ativa o novo dashboard",
    "enabled": true
  }'
```

**Listar todas as flags:**
```bash
curl http://localhost:8002/flags \
  -H "Authorization: Bearer tm_key_xxxxxxx"
```

---

### **4️⃣ Testar targeting-service (porta 8003)**

**Health Check:**
```bash
curl http://localhost:8003/health
```

**Criar uma regra de segmentação:**
```bash
curl -X POST http://localhost:8003/rules \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer tm_key_xxxxxxx" \
  -d '{
    "flag_name": "enable-new-dashboard",
    "rule_type": "PERCENTAGE",
    "rule_data": {
      "percentage": 50
    }
  }'
```

**Listar regras:**
```bash
curl http://localhost:8003/rules \
  -H "Authorization: Bearer tm_key_xxxxxxx"
```

---

### **5️⃣ Testar evaluation-service (porta 8004)**

**Health Check:**
```bash
curl http://localhost:8004/health
```

**Avaliar uma flag para um usuário:**
```bash
curl "http://localhost:8004/evaluate?user_id=user123&flag_name=enable-new-dashboard"
```
✅ Retorna: `{"enabled":true}` ou `{"enabled":false}` baseado nas regras

---

### **6️⃣ Testar analytics-service (porta 8005)**

**Health Check:**
```bash
curl http://localhost:8005/health
```

---

### **📝 Fluxo Completo de Teste (em ordem)**

```bash
# 1. Criar chave de API
API_KEY=$(curl -s -X POST http://localhost:8001/admin/keys \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer admin-secreto-123" \
  -d '{"name": "test-key"}' | grep -o '"key":"[^"]*"' | cut -d'"' -f4)

echo "Chave criada: $API_KEY"

# 2. Criar uma flag
curl -X POST http://localhost:8002/flags \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"name":"nova-feature","description":"Teste","enabled":true}'

# 3. Criar regra (50% dos usuários)
curl -X POST http://localhost:8003/rules \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"flag_name":"nova-feature","rule_type":"PERCENTAGE","rule_data":{"percentage":50}}'

# 4. Avaliar flag (vai gerar evento para analytics)
curl "http://localhost:8004/evaluate?user_id=user1&flag_name=nova-feature"
curl "http://localhost:8004/evaluate?user_id=user2&flag_name=nova-feature"
```

---

### **🔍 Verificar Logs em Tempo Real**

```bash
# Todos os serviços
docker compose logs -f

# Serviço específico
docker compose logs -f flag-service
```

---