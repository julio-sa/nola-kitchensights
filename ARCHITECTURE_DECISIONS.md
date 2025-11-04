# Nola KitchenSights — Decisões Arquiteturais

Este documento registra as decisões arquiteturais (ADRs) tomadas ao longo do desenvolvimento do Nola KitchenSights, com foco em simplicidade (KISS), performance prática e DX (Developer eXperience).

---

## 1) Stack e princípios

- **Backend:** Python + FastAPI (assíncrono)  
  - Decisão: FastAPI pela velocidade de iteração, tipagem e ótima DX.
  - Assíncrono para não bloquear I/O de banco e manter o serviço leve.

- **DB:** PostgreSQL (com `asyncpg`)  
  - Decisão: SQL relacional facilita agregações (SUM/AVG/COUNT), janelas e CTEs.
  - Dados de vendas e entregas combinam melhor com relacionais por consistência e joins.

- **ORM/Driver:** SQLAlchemy (async)  
  - Decisão: usamos **Repository Pattern** para manter SQL explícito em um lugar, com controle fino de performance (CTEs, agregações), sem espalhar queries pelo código.

- **Frontend:** Flutter (Riverpod)  
  - Decisão: foco em mobile-first e performance de UI; Riverpod para controle previsível de estado e providers encapsulando chamadas HTTP.

- **Infra Dev:** Docker para Postgres + script `generate_data.py` (seed)  
  - Decisão: padronizar ambiente local e acelerar testes.

- **Princípios:** KISS, coerência sem “over-engineering”, fallback defensivo no front e no back (melhor UX com dados incompletos).

---

## 2) Organização do backend

app/
api/v1/routes/widgets.py # endpoints públicos (widgets e reports inline)
repositories/sales_repository.py
services/widget_service.py
services/report_services.py
main.py


- **Repository Layer (`SalesRepository`)**
  - Centraliza SQL **declarativo** (via `text()`), favorecendo CTEs, agregações e performance.
  - Métodos principais:
    - `get_revenue_overview(...)`
    - `get_top_products_flexible(...)`
    - `get_delivery_heatmap_by_store(...)`
    - `get_at_risk_customers(...)`
    - `list_channels_for_store(...)` / `list_available_stores(...)`
    - `get_channel_performance(...)`
    - `get_store_comparison(...)`
    - `get_store_performance_for_period(...)` *(para relatórios)*

- **Service Layer**
  - `WidgetService`: aplica regras de fallback (ex.: se filtro retorna vazio, relaxa canal/dia/hora).
  - `ReportService`: orquestra consultas e formata saída (CSV de performance por loja).

- **API Layer**
  - `widgets.py`: endpoints REST padronizados e simples.
  - **Rotas** (principais):
    - `GET /api/v1/widgets/revenue-overview`
    - `GET /api/v1/widgets/top-products`
    - `GET /api/v1/widgets/top-products-flex`
    - `GET /api/v1/widgets/delivery-heatmap`
    - `GET /api/v1/widgets/at-risk-customers`
    - `GET /api/v1/widgets/channel-performance`
    - `GET /api/v1/widgets/store-comparison`
    - `GET /api/v1/widgets/available-stores`
    - **Relatório (CSV):** `GET /api/v1/reports/store-performance`

---

## 3) Decisões de domínio

- **Períodos de comparação (WoW)**
  - Para métricas de *Top Produtos*, calculamos o período anterior com o mesmo tamanho do período atual para contraste justo (CTEs `current_period` e `previous_period`).

- **Filtro de canal “Todos”**
  - API aceita `ALL`/`*`/`TODOS` como **sem filtro** (normalizado para `None`).
  - Front envia sempre o parâmetro; back decide quando ignorá-lo.

- **Última data de venda (end_date automático)**
  - Para cenários *sem dados no dia corrente*, adotamos usar a **última data com vendas** como `end_date` “realista” (evita gráfico “zerado hoje”).  
  - Implementação sugerida/convencionada: `SELECT MAX(created_at::date) FROM sales WHERE store_id = :id` (ou global caso multi-store).  
    - Mantido como decisão arquitetural; pode ser encapsulado em service/repo conforme necessidade.

- **“Melhor canal do item” na visão ALL**
  - Exibimos um **snippet** mostrando o canal campeão para cada produto *apenas se houver vencedor claro*.
  - Critério de clareza: vencedor tem pelo menos **5%** de vantagem relativa sobre o segundo (evita “falso positivo” em empates).
  - Normalização de nomes no front para *case-insensitive* e *trim* (evita miss de chaves).

- **Fallbacks**
  - Se o `Top Products` retorna vazio para um filtro restrito, o `WidgetService` relaxa na ordem:
    1) Tenta sem canal.
    2) Tenta só período (sem dia/hora).
  - Providers no front também tentam **loja alternativa** com dados, ou **mês anterior cheio** (para `revenue-overview`).

---

## 4) Frontend (Flutter)

- **Providers (`widget_provider.dart`)**
  - Cada widget consome providers que:
    - Montam a query-string.
    - Fazem GET.
    - Convertem JSON em models fortemente tipados.
    - Aplicam **fallbacks** (ex.: `_getFirstAvailableStoreId()`).
  - **`bestChannelByProductProvider`**: mapa `nome_do_produto → melhor_canal`, para exibir o snippet ao lado do item na visão `ALL`.

- **Widget `TopProductsWidget`**
  - Filtros (loja, canal, dia, hora) em **bottom sheet**.
  - Badge de **oportunidade** ou **alerta** com base em variação WoW.
  - Quando `canal == ALL`: mostra **Chip “melhor canal”** por produto **se** houver vencedor claro (critério `_hasClearWinner`).

---

## 5) Performance e dados

- **CTEs** para sumarizações: reduzem round-trips e mantêm a leitura clara.
- **Índices recomendados**:
  - `sales(store_id, created_at)`  
  - `sales(channel_id, created_at)`  
  - `product_sales(sale_id)`, `product_sales(product_id)`  
  - `delivery_addresses(sale_id)`
- **Paginação**: rotas de lista estão prontas para receber `LIMIT/OFFSET` caso necessário.
- **CORS**: variável `CORS_ORIGINS` no `.env` habilita hosts do Flutter no dev.

---

## 6) Segurança (escopo desafio)

- Escopo atual não exige autenticação.  
  - Decisão: deixar *hook* para `Depends(get_current_user)` no futuro.
- Sanitização/Bind: todo SQL usa **bind params** (`:param`) para evitar injeção.

---

## 7) Operação local

- **DB via Docker**  
  - `docker compose up -d db`
- **Seed**  
  - `python scripts/generate_data.py` *(aponta para o DSN do Postgres do docker)*
- **API**  
  - `uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`

---

## 8) Roadmap curto

- Autenticação JWT (multi-tenant de verdade).
- Paginação e export JSON/CSV por widget.
- Cache leve para queries mais pedidas (ex.: Redis).
- Métricas por horário (histogramas) por canal/produto.
