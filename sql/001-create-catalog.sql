-- Bootstrap del catálogo de Unity Catalog y las 3 capas de la arquitectura
-- medallion (bronze/silver/gold). Todo es idempotente (IF NOT EXISTS), por lo
-- que este script se puede re-ejecutar sin riesgo de fallar en un catálogo ya existente.
CREATE CATALOG IF NOT EXISTS churn_portfolio;
CREATE SCHEMA IF NOT EXISTS churn_portfolio.bronze;
CREATE SCHEMA IF NOT EXISTS churn_portfolio.silver;
CREATE SCHEMA IF NOT EXISTS churn_portfolio.gold;


-- Paso manual (fuera de SQL): crea el Volume donde se sube el CSV crudo antes
-- de poder leerlo con read_files() más abajo. Se deja como referencia/documentación
-- porque CREATE VOLUME no se puede invocar vía el endpoint de statements de forma
-- directa en este flujo; reemplazar <warehouse_id> por el ID real del SQL warehouse.
/*
databricks api post /api/2.0/sql/statements --profile churn-analysis --json '{
  "warehouse_id": "<warehouse_id>",
  "statement": "CREATE VOLUME IF NOT EXISTS churn_portfolio.bronze.raw_files",
  "wait_timeout": "30s"
}'
*/

-- Ingesta bronze: lee el CSV crudo desde el Volume y lo materializa tal cual
-- (sin transformar) como tabla Delta. CREATE OR REPLACE recarga la tabla
-- completa en cada corrida, así que sirve para reprocesos, pero no es
-- incremental ni conserva historial de versiones anteriores del CSV.
--
-- Nota: inferSchema => true infiere los tipos de columna a partir del propio
-- archivo, por lo que el esquema resultante puede variar si el CSV cambia
-- entre corridas (p. ej. una columna que hoy parece INT podría inferirse como
-- DOUBLE si aparecen decimales). Para un esquema estable en producción,
-- conviene declarar el esquema explícitamente en vez de inferirlo.
CREATE OR REPLACE TABLE churn_portfolio.bronze.customer_data AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/Customer_Data.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);