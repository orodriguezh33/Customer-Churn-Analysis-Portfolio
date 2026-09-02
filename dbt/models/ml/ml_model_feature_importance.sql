-- Coeficientes estandarizados del modelo desplegado (Logistic Regression) -- no
-- "feature importance" de árbol. `importance` es la magnitud (|coeficiente|), usable para
-- rankear; `signed_coefficient` conserva el signo para mostrar dirección (sube/baja el
-- riesgo). Ver notebooks/09_business_insights.ipynb.
{{ config(materialized='view') }}

select
    feature,
    importance,
    signed_coefficient,
    rank
from {{ source('bronze', 'model_feature_importance') }}
