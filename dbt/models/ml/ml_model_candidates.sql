-- Comparison of the 4 candidate models at the default threshold (0.5), from
-- notebooks/07_model_evaluation.ipynb. Historical model-selection context -- not the
-- deployed model's performance (that's ml_model_metrics, at the operational threshold).
{{ config(materialized='view') }}

select
    Model as model_name,
    Accuracy as accuracy,
    Precision as precision,
    Recall as recall,
    F1 as f1,
    ROC_AUC as roc_auc,
    is_winner
from {{ source('bronze', 'model_candidates') }}
