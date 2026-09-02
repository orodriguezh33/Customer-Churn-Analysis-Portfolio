-- Ingesta de las salidas del pipeline de ML (notebooks 07-09) al catálogo de
-- Unity Catalog. Mismo patrón que 001-create-catalog.sql: los CSV crudos
-- entran a `bronze` (cargados tal cual, sin transformar) y es dbt quien los
-- convierte en la capa `ml` de negocio (ver dbt/models/ml/). El schema `ml`
-- se crea acá porque dbt no lo hace (dbt solo materializa modelos dentro de
-- schemas ya existentes).
CREATE SCHEMA IF NOT EXISTS churn_portfolio.ml;

-- Paso manual (fuera de SQL, igual que en 001): subir los 6 CSV al Volume
-- antes de poder leerlos acá. Reutiliza el Volume `raw_files` ya existente,
-- en un subdirectorio `ml/` para no mezclarlos con Customer_Data.csv.
--
-- databricks fs cp data/processed/joined_scored.csv \
--   dbfs:/Volumes/churn_portfolio/bronze/raw_files/ml/joined_scored.csv \
--   --overwrite --profile churn-analysis
-- (repetir para model_candidates.csv, model_final_metrics.csv,
--  model_confusion_matrix.csv, model_feature_importance.csv, model_roc_curve.csv)
--
-- Estos 6 CSV son regenerables (data/processed/ está gitignoreado): correr
-- notebooks 04-09 en orden y volver a subir antes de correr lo de abajo, o
-- el dashboard queda mostrando scores de una corrida vieja.

-- churn_risk_score, risk_tier y predicted_churn por cliente `Joined`
-- (sin desenlace conocido). Ver notebooks/09_business_insights.ipynb.
CREATE OR REPLACE TABLE churn_portfolio.bronze.customer_scores AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/ml/joined_scored.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- Comparación de los 4 modelos candidatos (umbral 0.5). Ver
-- notebooks/07_model_evaluation.ipynb.
CREATE OR REPLACE TABLE churn_portfolio.bronze.model_candidates AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/ml/model_candidates.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- Métricas del modelo final al umbral operativo (0.255, no 0.5 -- ver
-- notebooks/08_final_model.ipynb, sección "Threshold tuning"). Una sola fila.
CREATE OR REPLACE TABLE churn_portfolio.bronze.model_final_metrics AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/ml/model_final_metrics.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- Matriz de confusión del modelo final en formato largo (actual, predicted,
-- customers), calculada al mismo umbral operativo. Ver
-- notebooks/08_final_model.ipynb.
CREATE OR REPLACE TABLE churn_portfolio.bronze.model_confusion_matrix AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/ml/model_confusion_matrix.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- Coeficientes estandarizados del modelo final (Logistic Regression),
-- con signo -- no "feature importance" de árbol. Ver
-- notebooks/09_business_insights.ipynb.
CREATE OR REPLACE TABLE churn_portfolio.bronze.model_feature_importance AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/ml/model_feature_importance.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- Puntos (fpr, tpr) de la curva ROC del modelo final, submuestreada a ~200
-- puntos. Ver notebooks/08_final_model.ipynb.
CREATE OR REPLACE TABLE churn_portfolio.bronze.model_roc_curve AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/ml/model_roc_curve.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);
