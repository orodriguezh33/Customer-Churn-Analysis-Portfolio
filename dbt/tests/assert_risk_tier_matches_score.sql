{{ config(severity = 'error') }}

-- Regression guard for the original bug: risk tiers were hardcoded
-- (0.80/0.60) with no relation to the model's operational threshold, so a customer could be
-- predicted_churn = 1 while also falling into risk_tier = 'Low'. This test fails if risk_tier
-- or predicted_churn stop corresponding to churn_risk_score against the cutoffs defined in
-- notebooks/09_business_insights.ipynb (< 0.255 Low, < 0.60 Medium, else High;
-- predicted_churn = 1 exactly when churn_risk_score >= 0.255). Unlike the monthly_charge
-- test (dubious source data, allowed to pass with warn), here the data is derived by
-- the pipeline itself -- a discrepancy is always a bug, so the severity is error.
select *
from {{ ref('ml_customers_at_risk') }}
where
    (churn_risk_score >= 0.60 and risk_tier != 'High')
    or (churn_risk_score >= 0.255 and churn_risk_score < 0.60 and risk_tier != 'Medium')
    or (churn_risk_score < 0.255 and risk_tier != 'Low')
    or (predicted_churn != case when churn_risk_score >= 0.255 then 1 else 0 end)
