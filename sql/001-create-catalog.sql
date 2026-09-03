-- Bootstrap of the Unity Catalog catalog and the 3 layers of the medallion
-- architecture (bronze/silver/gold). Everything is idempotent (IF NOT EXISTS), so
-- this script can be re-run without risk of failing on an already-existing catalog.
CREATE CATALOG IF NOT EXISTS churn_portfolio;
CREATE SCHEMA IF NOT EXISTS churn_portfolio.bronze;
CREATE SCHEMA IF NOT EXISTS churn_portfolio.silver;
CREATE SCHEMA IF NOT EXISTS churn_portfolio.gold;


-- Manual step (outside SQL): creates the Volume where the raw CSV is uploaded before
-- it can be read with read_files() below. Left as reference/documentation
-- because CREATE VOLUME can't be invoked directly via the statements endpoint
-- in this flow; replace <warehouse_id> with the real SQL warehouse ID.
/*
databricks api post /api/2.0/sql/statements --profile churn-analysis --json '{
  "warehouse_id": "<warehouse_id>",
  "statement": "CREATE VOLUME IF NOT EXISTS churn_portfolio.bronze.raw_files",
  "wait_timeout": "30s"
}'
*/

-- Bronze ingestion: reads the raw CSV from the Volume and materializes it as-is
-- (untransformed) as a Delta table. CREATE OR REPLACE reloads the full
-- table on every run, so it works for reprocessing, but it is not
-- incremental and doesn't keep a history of previous CSV versions.
--
-- Note: inferSchema => true infers column types from the file itself,
-- so the resulting schema can vary if the CSV changes between runs
-- (e.g. a column that looks like INT today could be inferred as
-- DOUBLE if decimals appear). For a stable schema in production, it's
-- better to declare the schema explicitly instead of inferring it.
CREATE OR REPLACE TABLE churn_portfolio.bronze.customer_data AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/Customer_Data.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);