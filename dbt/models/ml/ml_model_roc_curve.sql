-- Curva ROC del modelo desplegado sobre el test set, submuestreada a ~200 puntos. Ver
-- notebooks/08_final_model.ipynb.
{{ config(materialized='view') }}

select
    fpr,
    tpr
from {{ source('bronze', 'model_roc_curve') }}
