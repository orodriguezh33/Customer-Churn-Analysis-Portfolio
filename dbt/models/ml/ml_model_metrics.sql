-- Metrics of the deployed model (logistic_regression) recomputed at the operational
-- threshold (chosen in notebooks/08_final_model.ipynb for recall with precision >= 0.55),
-- not at the default 0.5 -- that's in ml_model_candidates. Single row.
{{ config(materialized='view') }}

select
    model_name,
    threshold,
    accuracy,
    precision,
    recall,
    f1,
    roc_auc
from {{ source('bronze', 'model_final_metrics') }}
