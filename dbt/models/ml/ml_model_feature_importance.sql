-- Standardized coefficients of the deployed model (Logistic Regression) -- not
-- tree "feature importance". `importance` is the magnitude (|coefficient|), usable for
-- ranking; `signed_coefficient` keeps the sign to show direction (raises/lowers the
-- risk). See notebooks/09_business_insights.ipynb.
{{ config(materialized='view') }}

select
    feature,
    importance,
    signed_coefficient,
    rank
from {{ source('bronze', 'model_feature_importance') }}
