# Guia de Configuração do Keycloak

Este guia descreve como configurar o Keycloak para autenticação JWT na API de Campanhas.

## Iniciar os Serviços

```bash
docker-compose up -d
```

Isso iniciará:
- PostgreSQL (porta 5432)
- RabbitMQ (porta 5672, management: 15672)
- Keycloak (porta 8080)

## Configuração Inicial do Keycloak

### 1. Acessar o Console Admin

Acesse http://localhost:8080 e faça login com:
- **Usuário**: admin
- **Senha**: admin

### 2. Criar um Realm

1. No menu superior esquerdo, clique em **Master** e depois em **Create Realm**
2. Nome sugerido: `rewards-api`
3. Clique em **Create**

### 3. Criar um Client

1. No menu lateral, clique em **Clients**
2. Clique em **Create client**
3. Configure:
   - **Client ID**: `campaigns-api`
   - **Client Protocol**: `openid-connect`
   - Clique em **Next**
4. Na próxima tela:
   - **Client authentication**: ON (para service accounts)
   - **Authorization**: ON (opcional)
   - **Authentication flow**: Marque apenas **Service accounts roles**
   - Clique em **Next**
5. Clique em **Save**

### 4. Obter o Client Secret

1. Vá para a aba **Credentials**
2. Copie o **Client Secret** (você precisará dele para autenticação)

### 5. Configurar Mapper para Tenant

Para adicionar o tenant como um claim personalizado no JWT:

1. Vá para **Clients** > `campaigns-api` > **Client scopes**
2. Clique em `campaigns-api-dedicated`
3. Clique na aba **Mappers**
4. Clique em **Add mapper** > **By configuration** > **Hardcoded claim**
5. Configure:
   - **Name**: `tenant-mapper`
   - **Token Claim Name**: `tenant`
   - **Claim value**: `default-tenant` (ou o valor do seu tenant)
   - **Claim JSON Type**: `String`
   - **Add to ID token**: ON
   - **Add to access token**: ON
   - **Add to userinfo**: ON
6. Clique em **Save**

### 6. Obter Token de Acesso

Para obter um token JWT para testes:

```bash
curl -X POST http://localhost:8080/realms/rewards-api/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=campaigns-api" \
  -d "client_secret=cwK6Ap8XcctoHc6ZIbjTJM6smrXDWrZc" \
  -d "grant_type=client_credentials"
```

Resposta exemplo:
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI...",
  "expires_in": 300,
  "token_type": "Bearer"
}
```

## Configuração da API de Campanhas

### Variáveis de Ambiente

Para **desenvolvimento** (usando `dev.exs`):
```bash
# Opcional: Se você quiser usar JWKS em vez de secret
export KEYCLOAK_JWKS_URL=http://localhost:8080/realms/rewards-api/protocol/openid-connect/certs
```

Para **produção** (usando `runtime.exs`):
```bash
export KEYCLOAK_JWKS_URL=http://keycloak:8080/realms/rewards-api/protocol/openid-connect/certs
```

### Iniciar a API

```bash
cd campaigns_api
mix deps.get
mix ecto.setup
mix phx.server
```

## Testando a Integração

### 1. Obter um Token

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/realms/rewards-api/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=campaigns-api" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  -d "grant_type=client_credentials" | jq -r '.access_token')
```

### 2. Fazer uma Requisição Autenticada

```bash
curl -X GET http://localhost:4000/api/campaigns \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJzTU1HQTlHZ3Z5eGdZa1NydjRjX1FZZ21rMktFMzRzQVE3dXJzaWhUQnFZIn0.eyJleHAiOjE3Njg2NTkxMjcsImlhdCI6MTc2ODY1ODgyNywianRpIjoiNjE4NDVmOGYtN2JiZi00MmZlLTk1YzMtYmYzNWQ5ZGZiZmFhIiwiaXNzIjoiaHR0cDovL2xvY2FsaG9zdDo4MDgwL3JlYWxtcy9yZXdhcmRzLWFwaSIsImF1ZCI6ImFjY291bnQiLCJzdWIiOiJlZDMzODI0OS0yZDNlLTRlODAtODk5Zi0yYWQ2ZmY4ZjIxMzkiLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJjYW1wYWlnbnMtYXBpIiwiYWNyIjoiMSIsImFsbG93ZWQtb3JpZ2lucyI6WyIvKiJdLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsiZGVmYXVsdC1yb2xlcy1yZXdhcmRzLWFwaSIsIm9mZmxpbmVfYWNjZXNzIiwidW1hX2F1dGhvcml6YXRpb24iXX0sInJlc291cmNlX2FjY2VzcyI6eyJhY2NvdW50Ijp7InJvbGVzIjpbIm1hbmFnZS1hY2NvdW50IiwibWFuYWdlLWFjY291bnQtbGlua3MiLCJ2aWV3LXByb2ZpbGUiXX19LCJzY29wZSI6ImVtYWlsIHByb2ZpbGUiLCJlbWFpbF92ZXJpZmllZCI6ZmFsc2UsImNsaWVudEhvc3QiOiIxNzIuMTguMC4xIiwicHJlZmVycmVkX3VzZXJuYW1lIjoic2VydmljZS1hY2NvdW50LWNhbXBhaWducy1hcGkiLCJjbGllbnRBZGRyZXNzIjoiMTcyLjE4LjAuMSIsImNsaWVudF9pZCI6ImNhbXBhaWducy1hcGkiLCJ0ZW5hbnQiOiJtZXJjYWRvX2xpdnJlIn0.dryu0sdG0JfrZr7RBBd4CvMdjI6SPCVNBuxWs7ZjhCDu5em_ml67ZZNcNiFa5CyWkRThpIkrTaqtQDx96-lmWK6pIfRsDay3UnB0MvE4gsbER2kXWzZ-xyDW_R18naXq7U5ej5Li-0xeipV-jkbq7uRo0YnFBhVCFqu70-Mmp1zZa7ToRio0E7UbPPs0QxF2qde6tNj41HNfw9-KPVI54emkv8VgRKU2qupcQUB2-kNCxaQow2pUVdaMQBnUH7mDpjhJmAF5I9cKmlgoE0XW4Im0MdMV6KptizbmPHguj3BJzxXyoOjIT1PF1UTYz_P8L30Avn9qTFu9Qom8HGIDxA" \
  -H "Content-Type: application/json"
```

## Configurações Avançadas

### Múltiplos Tenants

Para suportar múltiplos tenants, você pode:

1. **Opção 1: Client Attributes**
   - Vá para **Clients** > `campaigns-api` > **Attributes**
   - Adicione um atributo `tenant` com o valor desejado
   - Crie um mapper do tipo **User Attribute** para incluir no token

2. **Opção 2: Roles**
   - Crie roles diferentes para cada tenant (ex: `tenant-acme`, `tenant-xyz`)
   - Use um mapper para extrair o role como tenant

3. **Opção 3: Por Usuário**
   - Se usar autenticação de usuários, adicione um atributo `tenant` no perfil do usuário
   - Crie um mapper do tipo **User Attribute** para incluir no token

### Validação de Token

A API valida automaticamente:
- Assinatura do token (usando JWKS ou secret)
- Expiração (`exp` claim)
- Emissão (`iat` claim)
- Presença do claim `tenant`

## Estrutura do Token JWT

Exemplo de payload do token decodificado:

```json
{
  "exp": 1705432800,
  "iat": 1705432500,
  "jti": "uuid-here",
  "iss": "http://localhost:8080/realms/rewards-api",
  "sub": "service-account-campaigns-api",
  "typ": "Bearer",
  "azp": "campaigns-api",
  "tenant": "default-tenant",
  "resource_access": {
    "campaigns-api": {
      "roles": ["uma_protection"]
    }
  }
}
```

## Troubleshooting

### Token Inválido ou Expirado

- Tokens expiram em 5 minutos por padrão
- Obtenha um novo token usando o endpoint de token

### Tenant Não Encontrado

- Verifique se o mapper foi configurado corretamente
- Confirme que o claim `tenant` está presente no token (decodifique em jwt.io)

### Erro ao Buscar JWKS

- Verifique se o Keycloak está acessível
- Confirme que a URL do JWKS está correta
- Em desenvolvimento, você pode usar `jwt_secret` em vez de JWKS

## Referências

- [Documentação do Keycloak](https://www.keycloak.org/documentation)
- [Joken - JWT para Elixir](https://hexdocs.pm/joken)
- [JokenJwks](https://hexdocs.pm/joken_jwks)
