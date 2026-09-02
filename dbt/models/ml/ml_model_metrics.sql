-- Métricas del modelo desplegado (logistic_regression) recalculadas al umbral operativo
-- (threshold, elegido en notebooks/08_final_model.ipynb por recall con precision >= 0.55),
-- no al 0.5 por defecto -- ese está en ml_model_candidates. Una sola fila.
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
