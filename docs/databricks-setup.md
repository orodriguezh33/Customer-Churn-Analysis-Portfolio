# Enlazar el proyecto con Databricks Free Edition

Guía paso a paso para mover `data/Customer_Data.csv` a Databricks Free
Edition y dejar el workspace conectado con este repo. Cada sección dice
exactamente qué clic dar o qué comando correr, en orden.

Este documento cubre solo **infraestructura**: cuenta, CLI, catálogo/
schemas, y la carga del Bronze. Las transformaciones Silver/Gold se
construyen con dbt — ver **`dbt-setup.md`** una vez que termines esta
guía. Ambos documentos comparten el mismo catálogo (`churn_portfolio`) y
el mismo SQL Warehouse (`<warehouse_id>`, ver paso 7).

**Entorno Python: este proyecto usa `uv`**, no `python -m venv` / `pip`
manual. Ya existen `pyproject.toml`, `.python-version` (fija `3.12`) y
`uv.lock` en la raíz del repo — cualquier dependencia Python (incluidas
las de este documento) se agrega con `uv add <paquete>` y se corre con
`uv run <comando>`. `uv` crea y administra `.venv` solo; no lo actives ni
lo edites a mano.

## 0. Qué es Databricks Free Edition (léelo antes de empezar)

- Edición gratuita para aprendizaje/portfolio. El cómputo es **serverless**:
  no creas ni configuras clusters, Databricks lo gestiona por ti.
- Trae **Unity Catalog** activado desde el primer momento (así se organizan
  los datos: `catalog.schema.tabla`).
- Tiene límites de uso (horas de cómputo, storage) que Databricks puede
  ajustar. Se revisan dentro del workspace, no aquí — paso 1.5 más abajo.
- No es lo mismo que "Community Edition" (producto viejo, sin Unity
  Catalog). Asegúrate de entrar por el link de Free Edition.

---

## 1. Crear la cuenta y el workspace

1. Ve a https://www.databricks.com/learn/free-edition.
2. Clic en **Get started for free** (o **Sign up**).
3. Regístrate con el email del proyecto (`<tu-email>`) y
   confirma el correo de verificación que te llega a la bandeja.
4. Al confirmar, Databricks crea automáticamente un workspace y te redirige
   a él. La URL de ese workspace es la que vas a usar en todos los pasos
   siguientes — tiene esta forma:

   ```
   https://<algo>.cloud.databricks.com          (AWS)
   https://<algo>.azuredatabricks.net            (Azure)
   ```

   **Cópiala y guárdala** (por ejemplo en un archivo de notas local, no en
   el repo) — la vas a necesitar para el CLI en el paso 2.
5. Dentro del workspace, revisa los límites vigentes: clic en tu ícono de
   usuario (esquina superior derecha) → **Settings** → busca la sección
   **Free Edition** (o **Usage**) → ahí ves el cupo de cómputo/almacenamiento
   restante. Para este proyecto (CSV de ~1 MB, 6,418 filas) el cupo gratuito
   sobra de sobra.

---

## 2. Instalar y autenticar el CLI en tu máquina

Esto te permite subir archivos y correr comandos desde tu terminal local en
vez de solo la UI web.

1. Instala el CLI (macOS, con Homebrew):

   ```bash
   brew tap databricks/tap
   brew install databricks
   ```
2. Verifica que quedó instalado:

   ```bash
   databricks --version
   ```
3. Autentícate contra tu workspace (usa la URL que copiaste en el paso 1.4):

   ```bash
   databricks auth login --host https://<tu-workspace>.cloud.databricks.com
   ```

   Esto abre el navegador, te pide iniciar sesión con la cuenta del paso 1,
   y al aceptar guarda un perfil OAuth en `~/.databrickscfg` en tu máquina
   (fuera del repo — nunca se commitea).
4. Cuando el CLI te pregunte el nombre del perfil, ponle algo descriptivo,
   por ejemplo `churn-analysis`. **El CLI no siempre usa `DEFAULT`** — el
   nombre que quede guardado es el que tú escribas ahí, así que confirma
   cuál fue mirando el archivo:

   ```bash
   cat ~/.databrickscfg
   ```

   Busca la sección con `auth_type = databricks-cli` (esa es la que se
   autenticó con OAuth de verdad) y usa ese nombre — en `[nombre-elegido]`
   — en el resto de esta guía. Este documento asume `churn-analysis`;
   reemplázalo si el tuyo se llama distinto.
5. Confirma que el perfil quedó activo y apunta al workspace correcto:

   ```bash
   databricks current-user me --profile churn-analysis
   ```

   (El comando viejo `databricks auth env` está deprecado y además solo
   busca la sección `[DEFAULT]`, así que falla si tu perfil se llama
   distinto — usa `current-user me` en su lugar.)

   Debe devolver tu usuario (`<tu-email>`) sin error. Si
   quieres no tener que pasar `--profile` cada vez, marca ese perfil como
   default en la sección `[__settings__]` del archivo:

   ```ini
   [__settings__]
   default_profile = churn-analysis
   ```

> No uses `databricks configure` con un Personal Access Token para este
> setup — deja el token en texto plano dentro de `~/.databrickscfg`. Usa
> siempre `databricks auth login` (OAuth), como en el paso 3. Y nunca
> pegues un token en archivos del repo: el hook `protect-files.sh` de este
> proyecto bloquea escrituras a `.env` y similares, pero un token pegado
> dentro de un `.md` o notebook no lo detecta — revísalo tú mismo antes de
> hacer commit. Si alguna vez un token queda expuesto (por ejemplo, se
> imprime en una terminal compartida o un log), revócalo de inmediato en
> **Settings → Developer → Access tokens**.

---

## 3. Crear el catálogo y los schemas (Unity Catalog)

Convención de este proyecto: un catálogo `churn_portfolio` con tres
schemas siguiendo el patrón medallion (Bronze → cruda, Silver → limpia,
Gold → agregada para BI).

**Opción A — por la UI (más simple para la primera vez):**

1. En el menú lateral izquierdo del workspace, clic en **Catalog**.
2. Arriba a la derecha, clic en **Create Catalog**.
3. Nombre: `churn_portfolio`. Tipo de storage: deja el que Free Edition
   proponga por defecto (managed storage). Clic en **Create**.
4. Dentro del catálogo recién creado, clic en **Create Schema** tres veces,
   una por cada nombre: `bronze`, `silver`, `gold`.

**Opción B — por SQL (más rápido si ya te sientes cómodo):**

1. En el menú lateral, clic en **SQL Editor** (o abre un notebook nuevo).
2. Pega y ejecuta:

   ```sql
   CREATE CATALOG IF NOT EXISTS churn_portfolio;
   CREATE SCHEMA IF NOT EXISTS churn_portfolio.bronze;
   CREATE SCHEMA IF NOT EXISTS churn_portfolio.silver;
   CREATE SCHEMA IF NOT EXISTS churn_portfolio.gold;
   ```
3. Corre cada línea con **Run** (o `Cmd+Enter` sobre la celda si es
   notebook).

**Opción C — por CLI, sin abrir el navegador (la que se usó en este
proyecto):**

El subcomando `databricks catalogs create` falla en Free Edition con
`Metastore storage root URL does not exist` porque pide una ubicación de
storage explícita. La forma que sí funciona es mandar el mismo `CREATE CATALOG` como una consulta SQL vía la Statement Execution API — usa el
storage por defecto de Free Edition automáticamente:

```bash
databricks api post /api/2.0/sql/statements --profile churn-analysis --json '{
  "warehouse_id": "<warehouse_id>",
  "statement": "CREATE CATALOG IF NOT EXISTS churn_portfolio",
  "wait_timeout": "30s"
}'
```

(`warehouse_id` sale del paso 7 más abajo — necesitas el SQL Warehouse
creado primero si vas por este camino). Repite cambiando `"statement"`
para cada `CREATE SCHEMA`:

```bash
databricks api post /api/2.0/sql/statements --profile churn-analysis --json '{
  "warehouse_id": "<warehouse_id>",
  "statement": "CREATE SCHEMA IF NOT EXISTS churn_portfolio.bronze",
  "wait_timeout": "30s"
}'
```

Revisa `"state": "SUCCEEDED"` en la respuesta. Si la respuesta trae
comillas simples rotas por el shell, escribe el JSON en un archivo y
pásalo con `--json @archivo.json` en vez de inline.

**Qué va en cada schema:**

| Schema     | Contenido                                                          |
| ---------- | ------------------------------------------------------------------ |
| `bronze` | `Customer_Data.csv` cargado tal cual, sin transformar            |
| `silver` | Datos limpios/tipados, columnas derivadas ya validadas             |
| `gold`   | Tablas agregadas listas para que Power BI las consuma directamente |

A partir de aquí, escribe siempre el nombre completo `churn_portfolio.<schema>.<tabla>` en tus queries — nunca solo `<tabla>`. Con varios catálogos en el mismo workspace, un nombre sin calificar puede resolver al catálogo equivocado sin avisarte.

---

## 4. Subir `data/Customer_Data.csv` a un Volume

Un Volume es donde vive el archivo crudo antes de convertirlo en tabla.

1. En **Catalog** (menú lateral), navega a `churn_portfolio` → `bronze`.
2. Clic en **Create** → **Volume**.
3. Nombre del volume: `raw_files`. Tipo: **Managed**. Clic en **Create**.

   O por CLI, igual que la Opción C del paso 3:

   ```bash
   databricks api post /api/2.0/sql/statements --profile churn-analysis --json '{
     "warehouse_id": "<warehouse_id>",
     "statement": "CREATE VOLUME IF NOT EXISTS churn_portfolio.bronze.raw_files",
     "wait_timeout": "30s"
   }'
   ```
4. Sube el archivo — dos formas, elige una:

   **Por la UI:**

   - Entra al volume `raw_files` recién creado.
   - Clic en **Upload to this volume**.
   - Arrastra `data/Customer_Data.csv` desde tu carpeta local, o clic en
     **Browse** y selecciónalo.
   - Espera a que la barra de progreso termine.

   **Por el CLI (desde la raíz del repo):**

   ```bash
   databricks fs cp data/Customer_Data.csv \
     dbfs:/Volumes/churn_portfolio/bronze/raw_files/Customer_Data.csv \
     --profile churn-analysis --overwrite
   ```
5. Verifica que llegó:

   ```bash
   databricks fs ls dbfs:/Volumes/churn_portfolio/bronze/raw_files/ --profile churn-analysis
   ```

   Debe listar `Customer_Data.csv`.

---

## 5. Convertir el CSV en tabla Delta Bronze

1. Abre **SQL Editor** (o un notebook nuevo, lenguaje SQL).
2. Pega y ejecuta:

   ```sql
   CREATE OR REPLACE TABLE churn_portfolio.bronze.customer_data AS
   SELECT *
   FROM read_files(
     '/Volumes/churn_portfolio/bronze/raw_files/Customer_Data.csv',
     format => 'csv',
     header => true,
     inferSchema => true
   );
   ```

   O por CLI (mismo patrón de las Opciones C anteriores — si usas comillas
   simples dentro del `statement`, escribe el JSON en un archivo y pásalo
   con `--json @archivo.json`, porque inline se rompe con el shell):

   ```bash
   databricks api post /api/2.0/sql/statements --profile churn-analysis --json @create_bronze.json
   ```
3. Valida el resultado con una query de conteo — debe dar **6418**
   (ya verificado en este proyecto: coincide exacto con el CSV local):

   ```sql
   SELECT COUNT(*) FROM churn_portfolio.bronze.customer_data;
   ```
4. Revisa rápidamente que las columnas quedaron como se esperaba:

   ```sql
   DESCRIBE churn_portfolio.bronze.customer_data;
   ```

   Compara contra el header del CSV (`Customer_ID, Gender, Age, ...`,
   ver `data/Customer_Data.csv`).

No cargues el CSV directo a una tabla sin pasar por el Volume — así el
archivo original queda intacto en Bronze, que es la regla de esa capa
(ingesta cruda, sin transformar).

---

## 5.1 Ingesta de las salidas del pipeline de ML

El objetivo 3 de `project-goals.md` ("Identificar un método para
predecir futuros churners") se resuelve en Python
(`notebooks/04`-`09`, fuera de este documento), pero sus salidas —
scores de riesgo y métricas del modelo — necesitan llegar a
`churn_portfolio.bronze` con el mismo patrón Volume → `read_files` →
tabla Delta que el paso 4-5, para que dbt las convierta en la capa `ml`
(ver `dbt-models.md` § 4). Mismo motivo que Bronze en general: los CSV
entran tal cual, sin transformar; dbt es quien construye los modelos de
negocio encima.

`data/processed/` está gitignoreado (regenerable corriendo los notebooks
`04`-`09` en orden, `random_state=42` los hace determinísticos), así que
estos 6 CSV **no** están en el repo — hay que generarlos localmente antes
de subirlos.

1. Corre los notebooks `04` a `09` en orden. Confirma que
   `data/processed/` tiene: `joined_scored.csv`, `model_candidates.csv`,
   `model_final_metrics.csv`, `model_confusion_matrix.csv`,
   `model_feature_importance.csv`, `model_roc_curve.csv`.
2. Sube los 6 archivos al mismo volume `raw_files`, en un subdirectorio
   `ml/` para no mezclarlos con `Customer_Data.csv`:

   ```bash
   databricks fs cp data/processed/joined_scored.csv \
     dbfs:/Volumes/churn_portfolio/bronze/raw_files/ml/joined_scored.csv \
     --overwrite --profile churn-analysis
   ```

   (repetir para los otros 5 — `--overwrite` porque se re-suben en cada
   reentrenamiento).
3. Corre `sql/003-create-ml-layer.sql` (mismo patrón que el paso 5: crea
   el schema `churn_portfolio.ml` y 6 tablas bronze vía `read_files`)
   contra el SQL Warehouse, vía **SQL Editor** o
   `databricks api post /api/2.0/sql/statements`.
4. Valida antes de correr dbt:

   ```sql
   SELECT COUNT(*) FROM churn_portfolio.bronze.customer_scores;  -- 405
   ```

   Si da otro número, revisa que el notebook `09` haya corrido completo
   y que el CSV subido sea el más reciente.
5. `cd dbt && dbt build --select ml+` — construye `ml_customers_at_risk`
   y las 5 vistas de métricas, y corre el test de regresión
   `assert_risk_tier_matches_score` (ver `dbt-models.md` § 4).

**Reentrenar desincroniza el dashboard si te saltas este orden.** Si
vuelves a correr los notebooks, el `final_model.joblib` y los CSV
cambian, pero Databricks sigue mostrando los datos de la corrida
anterior hasta que repitas los pasos 1-5 acá arriba — el dashboard de
Power BI (DirectQuery) reflejaría scores viejos sin ningún aviso de que
están desactualizados.

---

## 6. (Opcional) Conectar tu IDE local al workspace con Databricks Connect

Esto es para exploración puntual en Python (`notebooks/`, `src/`) contra
las tablas remotas — **no** es el camino para construir Silver/Gold de
forma repetible; para eso usa dbt (`dbt-setup.md`), que versiona las
transformaciones como archivos `.sql` en el repo en vez de código Python
suelto.

1. Agrega la librería con `uv` (esto actualiza `pyproject.toml` y
   `uv.lock`, y reconstruye `.venv` si hace falta — no actives nada a
   mano):

   ```bash
   uv add databricks-connect
   ```
2. En tu script o notebook local:

   ```python
   from databricks.connect import DatabricksSession

   spark = DatabricksSession.builder.profile("churn-analysis").getOrCreate()
   df = spark.table("churn_portfolio.bronze.customer_data")
   df.count()   # debería dar 6418
   ```
3. Usa el mismo nombre de perfil que confirmaste en el paso 2.4 dentro de
   `.profile("...")`.
4. Ejecuta el script con `uv run` (no hace falta activar nada):

   ```bash
   uv run python src/tu_script.py
   ```

   Para un notebook, `uv run jupyter lab` levanta Jupyter ya usando el
   kernel del `.venv` del proyecto.

---

## 7. Conectar Power BI a la capa Gold

Las tablas agregadas en `churn_portfolio.gold` las construye dbt (ver
`dbt-setup.md`, secciones 6 y 9 — ahí ya está `gold_customer_data`
corriendo, la única tabla gold que consume el dashboard). Una vez que
tengas ahí la tabla que necesitas para el dashboard, conecta Power BI
así:

1. Primero necesitas un SQL Warehouse activo: menú lateral → **SQL
   Warehouses** → si no hay ninguno, clic en **Create SQL Warehouse**,
   déjalo en tamaño **2X-Small/Serverless** (el más chico, suficiente para
   este volumen de datos) y confirma que **Auto Stop** esté en un valor
   corto (10-15 min). En este proyecto quedó `<warehouse_id>`
   ("Serverless Starter Warehouse", auto-stop 10 min) — es el mismo que
   usa dbt en `~/.dbt/profiles.yml` y los comandos CLI de este documento.
2. Clic en el warehouse → pestaña **Connection details**. Copia:
   - **Server hostname**
   - **HTTP path**
3. Genera un token de acceso: ícono de usuario (arriba a la derecha) →
   **Settings** → **Developer** → **Access tokens** → **Manage** →
   **Generate new token**. Ponle una fecha de expiración corta y
   **cópialo una sola vez** (no se vuelve a mostrar).
4. En Power BI Desktop: **Get Data** → busca **Azure Databricks** (o
   **Databricks**) → pega **Server hostname** y **HTTP path** del paso 2.
5. Método de autenticación: **Personal Access Token** → pega el token del
   paso 3. Guárdalo solo en el gestor de credenciales de Power BI —
   **nunca** en un archivo del repo.
6. En el navegador de tablas que aparece, expande
   `churn_portfolio` → `gold` y selecciona la(s) tabla(s) agregada(s) que
   quieras usar en el dashboard.

---

## 8. Checklist final

- [ ] `databricks current-user me --profile churn-analysis` devuelve tu
  usuario sin error.
- [ ] `~/.databrickscfg` solo tiene el perfil OAuth (sin tokens en texto
  plano sueltos).
- [ ] `churn_portfolio` existe con schemas `bronze`, `silver`, `gold`.
- [ ] `Customer_Data.csv` está en
  `dbfs:/Volumes/churn_portfolio/bronze/raw_files/`.
- [ ] `churn_portfolio.bronze.customer_data` tiene 6,418 filas (paso 5.3).
- [ ] (Si ya corriste los notebooks de ML) los 6 CSV de
  `data/processed/` están subidos a
  `dbfs:/Volumes/churn_portfolio/bronze/raw_files/ml/` y
  `churn_portfolio.bronze.customer_scores` tiene 405 filas (paso 5.1).
- [ ] El SQL Warehouse tiene Auto Stop corto configurado.
- [ ] Ningún token ni credential quedó pegado en un archivo del repo
  (`git status` / revisión visual antes de cualquier commit).

Una vez tildado todo esto, sigue con el checklist de `dbt-setup.md`
(instalar dbt, correr `dbt debug`/`dbt build`) para que Silver y Gold
queden poblados — ese es el siguiente documento en la cadena.
