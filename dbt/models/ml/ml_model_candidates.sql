-- Comparación de los 4 modelos candidatos al umbral por defecto (0.5), de
-- notebooks/07_model_evaluation.ipynb. Contexto histórico de selección de modelo -- no es
-- el desempeño del modelo desplegado (eso es ml_model_metrics, al umbral operativo).
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
