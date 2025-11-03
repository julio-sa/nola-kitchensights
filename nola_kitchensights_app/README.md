# Nola KitchenSights

> Analytics sob medida para restaurantes — simples, acionável e focado no que a Maria precisa decidir hoje.

**Stack:** FastAPI (Python) + PostgreSQL • Flutter Web (Riverpod)  
**Deploy sugerido:** API (Render/Fly) • Frontend (Vercel) • DB (Neon/Supabase)

---

## ✨ O que resolve

- **Faturamento** por período, ticket médio e canais (com comparação ao período anterior)  
- **Top produtos** por canal/dia/horário  
- **Mapa de calor de entregas** (bairro/cidade) com Tempo médio e **P90 (90% das entregas até esse tempo)**  
- **Clientes em risco** com **regra de cupom** escalonada (10% → 60%)  
- **Comparativo de lojas** (sempre 2) com destaque por métrica  
- **Exportar CSV** e **tela de gráficos** com os mesmos insights

---

## 🧭 Fluxo (em < 5 min)

1. Abra o app e escolha a **loja** (picker no header).  
2. Veja o **overview de faturamento** (queda/crescimento vs período anterior).  
3. Em **Top Produtos**, filtre **iFood · quinta · 19–23h**.  
4. No **Heatmap**, veja onde o **tempo de entrega** piorou (badge/insight).  
5. Em **Clientes em Risco**, identifique quem aciona **cupom**.  
6. **Exporte CSV** para compartilhar.  
7. Se quiser, **mude para a tela de gráficos**.

---

## 🏗 Arquitetura (Clean/Hexagonal Light)

```
[Flutter Web (Riverpod)]
       ↓ HTTP/REST
[FastAPI Routes  ➜  Services  ➜  Repositories  ➜  SQL]
       ↓
    [PostgreSQL]
```

- **Separação de responsabilidades**: rotas só orquestram; regra nos services; acesso a dados nos repositórios.  
- **Testabilidade**: services e repos são isoláveis; endpoints com overrides.  
- **Desacoplamento**: trocar DB ou UI não afeta a lógica de negócio.  
- **Domínio primeiro**: widgets falam a língua do restaurante.

---

## 🚀 Como rodar

### 1) Backend (FastAPI)

```bash
cd backend
python -m venv .venv && source .venv/bin/activate  # (Windows: .venv\Scripts\activate)
pip install -r requirements.txt

# .env (exemplo)
# DATABASE_URL=postgresql+asyncpg://user:pass@host:5432/dbname
# CORS_ORIGINS=*

uvicorn app.main:app --reload --port 8000
```

Acesse a documentação: `http://localhost:8000/docs`

### 2) Frontend (Flutter Web)

```bash
cd frontend
flutter pub get
flutter run -d chrome    # ou: flutter build web
```

Configurar a URL da API no `lib/services/api_service.dart` (ex.: `const kBaseUrl = 'http://localhost:8000';`).

---

## 🗄 Dados e índices (500k+ vendas)

**Índices sugeridos (PostgreSQL):**
- `CREATE INDEX ON sales (order_date);`
- `CREATE INDEX ON sales (store_id, order_date);`
- `CREATE INDEX ON sales (channel, order_date);`
- `CREATE INDEX ON order_items (order_id);`
- `CREATE INDEX ON order_items (product_id, store_id);`
- `CREATE INDEX ON deliveries (store_id, city);`  *(se heatmap for pesado)*

**Opcional (apertar <1s):**
- Materialized views diárias por `store_id, channel, date`  
- Cache com ETag/TTL curto na API (30–120s)

---

## 🔌 Endpoints principais (GET)

- `/widgets/revenue-overview?storeId&startDate&endDate`  
- `/widgets/top-products?storeId&channel&dayOfWeek&hourStart&hourEnd`  
- `/widgets/delivery-heatmap?storeId&startDate&endDate`  
- `/widgets/at-risk-customers?storeId`  
- `/widgets/store-comparison?storeA&storeB&startDate&endDate`  
- `/export/csv?storeIds=1,2&startDate&endDate`

**P90 (entregas)**: 90% das entregas finalizaram **até** esse tempo.

**Cupom (retenção)**: após **60 dias sem compra**, inicia em **10%**, **+10% a cada 10 dias**, teto **60%**.

---

## 🧪 Testes

### Backend

```bash
cd backend
pytest -q
```

### Frontend

```bash
cd frontend
flutter test
```

Arquivos de teste sugeridos estão em `tests/` (backend) e `test/` (frontend).

---

## 📝 Decisões (ADR curto)

- **FastAPI**: velocidade para entregar + tipagem/Pydantic + OpenAPI out-of-the-box.  
- **SQL direto/SQLAlchemy Core**: previsível, mais performático para agregações.  
- **Flutter Web**: entrega rápida de UI responsiva + um único código para web/mobile.  
- **Clean Light**: menos cerimônia, mais foco nas regras do domínio.  
- **Cache + índices**: garantem resposta <1s em 500k registros.  
- **MVP sem multi-tenant completo**: escopo por `store_id` cobre o desafio; prontidão para `user_id` depois.

---

## 📦 Roadmap curto

- Alertas proativos (queda >X%, P90 acima de Y)  
- Saved views / dashboards personalizados  
- Multi-tenant completo (org_id + RBAC)  
- Auto-insights e explicações (IA)  

---

## 📄 Licença

MIT
