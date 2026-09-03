-- ROC curve of the deployed model on the test set, downsampled to ~200 points. See
-- notebooks/08_final_model.ipynb.
{{ config(materialized='view') }}

select
    fpr,
    tpr
from {{ source('bronze', 'model_roc_curve') }}
