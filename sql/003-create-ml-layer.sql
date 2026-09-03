-- Ingestion of the ML pipeline outputs (notebooks 07-09) into the Unity
-- Catalog catalog. Same pattern as 001-create-catalog.sql: the raw CSVs
-- land in `bronze` (loaded as-is, untransformed) and it's dbt that
-- converts them into the business `ml` layer (see dbt/models/ml/). The `ml` schema
-- is created here because dbt doesn't do it (dbt only materializes models within
-- already-existing schemas).
CREATE SCHEMA IF NOT EXISTS churn_portfolio.ml;

-- Manual step (outside SQL, same as in 001): upload the 6 CSVs to the Volume
-- before they can be read here. Reuses the already-existing `raw_files`
-- Volume, in an `ml/` subdirectory to avoid mixing them with Customer_Data.csv.
--
-- databricks fs cp data/processed/joined_scored.csv \
--   dbfs:/Volumes/churn_portfolio/bronze/raw_files/ml/joined_scored.csv \
--   --overwrite --profile churn-analysis
-- (repeat for model_candidates.csv, model_final_metrics.csv,
--  model_confusion_matrix.csv, model_feature_importance.csv, model_roc_curve.csv)
--
-- These 6 CSVs are regenerable (data/processed/ is gitignored): run
-- notebooks 04-09 in order and re-upload before running what's below, or
-- the dashboard will keep showing scores from an old run.

-- churn_risk_score, risk_tier, and predicted_churn per `Joined` customer
-- (no known outcome). See notebooks/09_business_insights.ipynb.
CREATE OR REPLACE TABLE churn_portfolio.bronze.customer_scores AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/ml/joined_scored.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- Comparison of the 4 candidate models (threshold 0.5). See
-- notebooks/07_model_evaluation.ipynb.
CREATE OR REPLACE TABLE churn_portfolio.bronze.model_candidates AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/ml/model_candidates.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- Final model metrics at the operational threshold (0.255, not 0.5 -- see
-- notebooks/08_final_model.ipynb, "Threshold tuning" section). Single row.
CREATE OR REPLACE TABLE churn_portfolio.bronze.model_final_metrics AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/ml/model_final_metrics.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- Confusion matrix of the final model in long format (actual, predicted,
-- customers), computed at the same operational threshold. See
-- notebooks/08_final_model.ipynb.
CREATE OR REPLACE TABLE churn_portfolio.bronze.model_confusion_matrix AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/ml/model_confusion_matrix.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- Standardized coefficients of the final model (Logistic Regression),
-- with sign -- not tree "feature importance". See
-- notebooks/09_business_insights.ipynb.
CREATE OR REPLACE TABLE churn_portfolio.bronze.model_feature_importance AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/ml/model_feature_importance.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);

-- ROC curve points (fpr, tpr) of the final model, downsampled to ~200
-- points. See notebooks/08_final_model.ipynb.
CREATE OR REPLACE TABLE churn_portfolio.bronze.model_roc_curve AS
SELECT *
FROM read_files(
  '/Volumes/churn_portfolio/bronze/raw_files/ml/model_roc_curve.csv',
  format => 'csv',
  header => true,
  inferSchema => true
);
