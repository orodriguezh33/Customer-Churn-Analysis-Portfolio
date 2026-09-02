# Integración de dbt con Databricks Free Edition

Guía paso a paso de cómo quedó armado dbt en este repo, para poder
reproducirlo o entenderlo. Todo lo de abajo ya se ejecutó una vez sobre el
workspace — este documento es la referencia para el día a día (correr
modelos nuevos) y para reconstruirlo desde cero si hace falta.

Requisito previo: haber hecho los pasos 1–2 de `databricks-setup.md`
(cuenta creada, CLI autenticado con perfil OAuth — en este repo el perfil
se llama `churn-analysis`).

---

## 0. Por qué dbt y cómo encaja

- El **Bronze** (`churn_portfolio.bronze.customer_data`) se sigue cargando
  como en `databricks-setup.md` — un CSV crudo, sin dbt de por medio.
- **dbt es dueño de Silver y Gold**: escribes modelos `.sql` en este repo
  (carpeta `dbt/models/`), y `dbt run`/`dbt build` los compila y ejecuta
  contra el SQL Warehouse remoto, creando tablas reales en Unity Catalog.
- No hay servidor ni proceso corriendo: dbt es un CLI que se conecta,
  manda el SQL compilado, y termina.

---

## 1. Entorno local — por qué un venv aparte con Python 3.12

`dbt-databricks` (a la fecha de este setup) no soporta todavía Python
3.14, que es la versión que trae `python3` por defecto en esta máquina.
Por eso el venv del proyecto se creó explícitamente con Python 3.12:

```bash
/Users/oscar/.local/bin/python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install dbt-databricks
```

Verifica la instalación:

```bash
dbt --version
```

Debe mostrar `dbt-core` y el plugin `databricks` instalados (en este setup
quedó dbt-core 1.12.0 / dbt-databricks 1.12.4).

> Si más adelante `python3` por defecto baja de versión o el sistema
> actualiza dbt-databricks con soporte para 3.14, no hace falta cambiar
> nada — el venv ya quedó fijo en 3.12 independientemente del Python del
> sistema.

---

## 2. Estructura del proyecto dbt en este repo

```
dbt/
  dbt_project.yml
  macros/
    generate_schema_name.sql
  models/
    staging/
      _sources.yml          # declara el Bronze como "source" de dbt
    silver/
      silver_customers.sql
      silver_customers.yml  # tests de esa tabla
    gold/
      gold_customer_data.sql
```

Vive en `dbt/` (no en la raíz del repo) para no chocar con la carpeta
`tests/` de Python que ya define `CLAUDE.md` — dbt también usa una carpeta
`tests/` propia para tests singulares, y así quedan separadas.

---

## 3. Perfil de conexión (`~/.dbt/profiles.yml`)

Se agregó esta entrada (el archivo ya tenía perfiles de otros proyectos —
no se tocó nada existente, solo se añadió esto al final):

```yaml
churn_portfolio:
  outputs:
    dev:
      type: databricks
      catalog: churn_portfolio
      schema: silver
      host: <tu-workspace>.cloud.databricks.com
      http_path: /sql/1.0/warehouses/<warehouse_id>
      auth_type: oauth
      threads: 4
  target: dev
```

Puntos importantes:

- **`auth_type: oauth`** (no `databricks-oauth` — ese nombre da error de
  "Database Error: auth_type oauth is required"). Con esto dbt reutiliza
  el mismo flujo de login por navegador que el CLI, **sin guardar ningún
  token en texto plano**.
- `host` y `http_path` salen de tu SQL Warehouse: menú lateral **SQL
  Warehouses** → seleccionar el warehouse → pestaña **Connection
  details** (o `databricks warehouses list --profile churn-analysis` si
  prefieres el CLI).
- Este archivo vive en `~/.dbt/`, fuera del repo — nunca se commitea.

Primera vez que corras algo (`dbt debug`, `dbt run`, etc.) se abre el
navegador pidiendo login — solo pasa una vez, después queda cacheado.

---

## 4. `dbt_project.yml` — cómo se organizan los schemas

```yaml
name: 'churn_portfolio'
version: '1.0.0'
config-version: 2
profile: 'churn_portfolio'

model-paths: ["models"]
macro-paths: ["macros"]
test-paths: ["tests"]

models:
  churn_portfolio:
    silver:
      +schema: silver
      +materialized: table
    gold:
      +schema: gold
      +materialized: table
```

Cada carpeta (`models/silver/`, `models/gold/`) mapea a su schema real en
Unity Catalog vía `+schema`. Para que dbt no le agregue un prefijo raro al
nombre del schema (su comportamiento por defecto es
`<schema_del_target>_<custom_schema>`), hay un macro que lo desactiva:

```sql
-- dbt/macros/generate_schema_name.sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

Así, un modelo en `models/gold/` termina exactamente en
`churn_portfolio.gold.<nombre_del_archivo>` — no en
`churn_portfolio.silver_gold.<nombre>`.

---

## 5. El Bronze como "source" de dbt

`dbt/models/staging/_sources.yml` le dice a dbt dónde está la tabla cruda
que no administra:

```yaml
version: 2
sources:
  - name: bronze
    catalog: churn_portfolio
    schema: bronze
    tables:
      - name: customer_data
```

Cualquier modelo puede leerla con `{{ source('bronze', 'customer_data') }}`
en vez de escribir el nombre completo a mano — si el día de mañana el
Bronze se mueve de catálogo, solo cambias este archivo.

---

## 6. Modelos de ejemplo ya creados

- **`models/silver/silver_customers.sql`** — renombra columnas del CSV
  crudo a snake_case y las deja tipadas, sin más lógica. Agrega
  `has_negative_monthly_charge` (boolean): flag de calidad de dato para
  las 107 filas con `Monthly_Charge` negativo en el CSV origen (ver
  `CLAUDE.md` § Dataset) — el valor crudo de `monthly_charge` no se toca.
- **`models/silver/silver_customers.yml`** — tests: `customer_id` único y
  no nulo, `customer_status` dentro de `Joined/Stayed/Churned`,
  `churn_category` dentro de los 5 valores válidos (solo cuando el cliente
  está `Churned`).
- **`tests/assert_monthly_charge_non_negative.sql`** — test singular en
  `warn` (no bloquea `dbt build`) que cuenta filas con `monthly_charge <
  0`; mantiene visible la anomalía de datos documentada en `CLAUDE.md`.
- **`models/gold/gold_customer_data.sql`** — única tabla gold, consumida
  directamente por Power BI: `silver_customers` completo (los 3 valores de
  `customer_status`), sin filtrar. Agrega `churn_flag` (1 = Churned, 0 en
  cualquier otro estado) y `monthly_charge_range` (`<20` / `20-50` /
  `50-100` / `>100`). Las medidas DAX (`Total Customers`, `Total Churn`,
  `Churn Rate`, `New Joiners`) filtran `customer_status` con `CALCULATE`
  sobre esta misma tabla, así cualquier slicer del reporte (estado,
  contrato, género, etc.) afecta a las cuatro por igual — ver
  `.claude/skills/powerbi-modeling/`.
  Antes existían `gold_churn_data.sql` (solo `Stayed`/`Churned`, pensada
  como dataset etiquetado para el objetivo 3 de `project-goals.md`),
  `gold_join_data.sql` (solo `Joined`, para scoring) y
  `gold_customer_status_summary.sql` (conteo agregado por estado); se
  eliminaron porque partir la tabla por `customer_status` rompía el
  cross-filtering entre tarjetas en Power BI y su contenido ya lo cubre
  `gold_customer_data` filtrando con DAX. Si más adelante se retoma el
  modelo de predicción de churn, ese dataset de entrenamiento debería
  vivir fuera de `gold/` (p. ej. una carpeta `ml/`) para no mezclar el
  propósito de BI con el de ML.

---

## 7. Comandos del día a día

Siempre desde `dbt/`, con el venv activado:

```bash
cd dbt
source ../.venv/bin/activate
```

| Qué quieres hacer                          | Comando                                              |
|---------------------------------------------|-------------------------------------------------------|
| Verificar que la conexión funciona          | `dbt debug`                                            |
| Correr todo (modelos + tests)               | `dbt build`                                            |
| Correr solo un modelo mientras lo editas    | `dbt run --select silver_customers`                     |
| Correr un modelo y sus dependientes         | `dbt run --select silver_customers+`                    |
| Solo tests                                  | `dbt test`                                              |
| Reconstruir todo desde cero (con cuidado)   | `dbt build --full-refresh`                              |
| Ver documentación/lineage generado          | `dbt docs generate && dbt docs serve`                   |

Regla de oro (ya en el skill `dbt-local-setup` de este repo): mientras
iteras, usa `--select` sobre el modelo puntual, no `dbt run` a secas —
y corre `dbt test` (o `dbt build`) antes de dar un cambio por terminado.

---

## 8. Cómo agregar un modelo nuevo

1. Crea el archivo `.sql` en `models/silver/` o `models/gold/` según la
   capa.
2. Si es Silver: selecciona desde `{{ source('bronze', 'customer_data') }}`
   o desde otro modelo Silver.
   Si es Gold: selecciona desde `{{ ref('silver_customers') }}` (o el
   modelo Silver que corresponda) — nunca desde el source directo.
3. Si el modelo necesita tests o descripción, crea/edita el `.yml` junto
   al `.sql` (mismo patrón que `silver_customers.yml`).
4. Corre `dbt run --select <nombre_del_modelo>` para probarlo solo, y
   `dbt test --select <nombre_del_modelo>` para validar.
5. Cuando esté listo, `dbt build` completo para confirmar que no rompiste
   nada aguas abajo.

---

## 9. Qué se creó en Databricks para que esto funcionara

La guía `databricks-setup.md` ya documentaba estos pasos, pero no se
habían ejecutado antes de integrar dbt — quedaron creados ahora:

- Catálogo `churn_portfolio` (con storage por defecto de Free Edition).
- Schemas `bronze`, `silver`, `gold`.
- Volumen `churn_portfolio.bronze.raw_files` con `Customer_Data.csv`
  subido.
- Tabla `churn_portfolio.bronze.customer_data` (6,418 filas, igual que el
  CSV local).

Si necesitas recrear esto en otro workspace y la UI no está a mano, se
puede hacer todo por CLI vía la Statement Execution API en vez de
`databricks catalogs create` (ese comando falla en Free Edition si no le
pasas una ubicación de storage explícita):

```bash
databricks api post /api/2.0/sql/statements --profile churn-analysis --json '{
  "warehouse_id": "<warehouse_id>",
  "statement": "CREATE CATALOG IF NOT EXISTS churn_portfolio",
  "wait_timeout": "30s"
}'
```

(mismo patrón para `CREATE SCHEMA`, `CREATE VOLUME`, etc. — cambia el
`statement`).

---

## 10. Checklist final

- [ ] `dbt debug` desde `dbt/` termina en `All checks passed!`.
- [ ] `dbt build` corre los 2 modelos y pasa los 4 tests.
- [ ] `churn_portfolio.silver.silver_customers` y
      `churn_portfolio.gold.gold_customer_data` existen en
      Unity Catalog (Catalog Explorer o `SELECT * FROM ... LIMIT 10`).
- [ ] `~/.dbt/profiles.yml` no tiene ningún `token:` en texto plano para
      el perfil `churn_portfolio` (usa `auth_type: oauth`).
- [ ] `dbt/target/` y `dbt/dbt_packages/` están en `.gitignore` (ya
      agregado).
