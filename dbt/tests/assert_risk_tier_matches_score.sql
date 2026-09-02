{{ config(severity = 'error') }}

-- Guarda de regresión del bug original: los tiers de riesgo estaban hardcodeados
-- (0.80/0.60) sin relación con el umbral operativo del modelo, así que un cliente podía ser
-- predicted_churn = 1 y a la vez caer en risk_tier = 'Low'. Este test falla si risk_tier o
-- predicted_churn dejan de corresponder a churn_risk_score contra los cortes definidos en
-- notebooks/09_business_insights.ipynb (< 0.255 Low, < 0.60 Medium, resto High;
-- predicted_churn = 1 exactamente cuando churn_risk_score >= 0.255). A diferencia del test
-- de monthly_charge (dato de origen dudoso, se deja pasar con warn), acá el dato lo deriva
-- el propio pipeline -- una discrepancia es siempre un bug, así que el severity es error.
select *
from {{ ref('ml_customers_at_risk') }}
where
    (churn_risk_score >= 0.60 and risk_tier != 'High')
    or (churn_risk_score >= 0.255 and churn_risk_score < 0.60 and risk_tier != 'Medium')
    or (churn_risk_score < 0.255 and risk_tier != 'Low')
    or (predicted_churn != case when churn_risk_score >= 0.255 then 1 else 0 end)
