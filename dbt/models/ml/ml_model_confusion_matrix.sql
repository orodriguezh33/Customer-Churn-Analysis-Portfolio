-- Matriz de confusión del modelo desplegado en formato largo (actual, predicted, customers),
-- calculada al umbral operativo, sobre el test set (1,182 clientes). Ver
-- notebooks/08_final_model.ipynb.
{{ config(materialized='view') }}

select
    actual,
    predicted,
    customers
from {{ source('bronze', 'model_confusion_matrix') }}
