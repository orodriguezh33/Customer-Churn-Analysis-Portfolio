-- Confusion matrix of the deployed model in long format (actual, predicted, customers),
-- computed at the operational threshold, on the test set (1,182 customers). See
-- notebooks/08_final_model.ipynb.
{{ config(materialized='view') }}

select
    actual,
    predicted,
    customers
from {{ source('bronze', 'model_confusion_matrix') }}
