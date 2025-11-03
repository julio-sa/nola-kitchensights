# nola-kitchensights

Nola KitchenSights é uma plataforma de analytics desenhada para donos de restaurantes que precisam responder perguntas complexas em poucos minutos. A solução combina um backend FastAPI com consultas SQL otimizadas em PostgreSQL e um frontend Flutter responsivo, permitindo exploração livre dos dados, comparação entre lojas e exportação de relatórios executivos.

## Principais funcionalidades

- **Overview financeiro com contexto**: faturamento, pedidos, ticket médio e variação vs. período anterior, além dos canais que mais contribuem para a receita.
- **Exploração guiada**: seleção interativa de canal, dia da semana e faixa horária para descobrir os produtos que lideram as vendas em cada cenário.
- **Operação e retenção**: mapa de calor das entregas (média e p90) e clientes fiéis que estão inativos há 30+ dias.
- **Comparação de lojas**: comparação lado a lado de faturamento, pedidos, ticket médio e canal líder entre duas unidades.
- **Exportação rápida**: geração de CSV pronto para apresentação e compartilhamento (conteúdo copiado automaticamente para a área de transferência no app demo).

## Arquitetura

- **Backend**: FastAPI + SQLAlchemy assíncrono. Consultas SQL customizadas garantem performance (<1 s) em cima de ~500k vendas.
- **Banco de dados**: PostgreSQL acessado via `postgresql+asyncpg`. O banco do desafio está configurado em `postgresql://challenge:challenge@localhost:5432/challenge_db`.
- **Frontend**: Flutter com Riverpod para gerenciamento de estado. Focado em permitir filtros rápidos, visualizações compactas e ações acionáveis.
- **Relatórios**: geração de CSV server-side via `ReportService`, retornado como `StreamingResponse`.

## Executando localmente

### Backend

#### 1) entrar na pasta do backend (se seu backend está na raiz, ignore)
cd backend   # ou cd .

#### 2) criar/ativar venv
python -m venv .venv
.venv\Scripts\Activate.ps1

#### 3) instalar dependências
pip install --upgrade pip
pip install -r requirements.txt

#### 4) configurar variáveis (exemplo .env)
#### DB_DSN=postgresql+asyncpg://user:pass@localhost:5432/nola
#### CORS_ORIGINS=http://localhost:5173,http://localhost:3000,http://localhost:8080,http://localhost:8000

#### 5) rodar API
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

#### 6) testar endpoint
#### GET http://localhost:8000/api/v1/widgets/revenue-overview?store_id=1&start_date=2025-10-01&end_date=2025-10-31

```powershell
python -m venv .venv
.venv/Scripts/Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
```
ou
```cmd
python -m venv .venv
.venv/Scripts/activate.bat
pip install -r requirements.txt
uvicorn app.main:app --reload
```
ou
```Linux/macOS
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Defina `DATABASE_URL` se necessário (aceita forma síncrona ou assíncrona, a aplicação converte para `postgresql+asyncpg`).

### Frontend (Flutter)

```bash
cd nola_kitchensights_app
flutter pub get
flutter run -d chrome
```
# se der erro de PATH do Flutter/Dart, veja flutter doctor

O app se comunica com `http://localhost:8000/api/v1`. Ajuste `lib/core/constants.dart` caso rode o backend em outra porta/host.

## Testes

```bash
pytest
```

Os testes cobrem a camada de serviço e o repositório de vendas com `pytest-asyncio`.

## Decisões de engenharia

- **SQL dedicado por insight**: consultas otimizadas e com CTEs evitam ORM pesado e deixam claro o racional de cada insight.
- **Mixins Pydantic com acesso tipo dict**: simplifica uso nas respostas da API e mantém compatibilidade com os testes existentes.
- **Relatórios CSV server-side**: evita lógica complexa no app Flutter e entrega arquivo pronto para ser aberto em planilhas.
- **Riverpod + widgets especializados**: cada card representa uma pergunta de negócio, mantendo o layout modular para novos widgets.
