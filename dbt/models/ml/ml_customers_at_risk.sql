-- Puntuación de riesgo de churn para los 405 clientes `Joined` (sin desenlace conocido
-- todavía), calculada por notebooks/09_business_insights.ipynb. A propósito NO se
-- relaciona con gold_customer_data en Power BI: son poblaciones disjuntas
-- (gold_customer_data mide churn ya ocurrido; esta tabla mide churn esperado sobre quienes
-- todavía no tuvieron desenlace), así que una relación de modelo no aportaría nada y solo
-- sumaría una segunda relación bidireccional (ver docs/powerbi-relationships-notes.md §4).
-- Cada página de predicción usa sus propios slicers sobre esta tabla.
with scores as (
    select
        Customer_ID as customer_id,
        churn_risk_score,
        risk_tier,
        predicted_churn
    from {{ source('bronze', 'customer_scores') }}
),

profile as (
    select
        customer_id,
        gender,
        age,
        state,
        tenure_in_months,
        contract,
        payment_method,
        internet_type,
        value_deal,
        number_of_referrals,
        monthly_charge,
        total_revenue,
        total_refunds,
        has_negative_monthly_charge
    from {{ ref('gold_customer_data') }}
)

select
    scores.customer_id,
    scores.churn_risk_score,
    scores.risk_tier,
    scores.predicted_churn,
    case
        when scores.churn_risk_score < 0.1 then '0.0-0.1'
        when scores.churn_risk_score < 0.2 then '0.1-0.2'
        when scores.churn_risk_score < 0.3 then '0.2-0.3'
        when scores.churn_risk_score < 0.4 then '0.3-0.4'
        when scores.churn_risk_score < 0.5 then '0.4-0.5'
        when scores.churn_risk_score < 0.6 then '0.5-0.6'
        when scores.churn_risk_score < 0.7 then '0.6-0.7'
        when scores.churn_risk_score < 0.8 then '0.7-0.8'
        when scores.churn_risk_score < 0.9 then '0.8-0.9'
        else '0.9-1.0'
    end as score_band,
    profile.gender,
    profile.age,
    case
        when profile.age < 20 then '<20'
        when profile.age < 35 then '20-35'
        when profile.age < 50 then '35-50'
        else '>50'
    end as age_group,
    profile.state,
    profile.tenure_in_months,
    case
        when profile.tenure_in_months < 6 then '<6 Months'
        when profile.tenure_in_months < 12 then '6-12 Months'
        when profile.tenure_in_months < 18 then '12-18 Months'
        when profile.tenure_in_months < 24 then '18-24 Months'
        else '>=24 Months'
    end as tenure_group,
    profile.contract,
    profile.payment_method,
    profile.internet_type,
    profile.value_deal,
    profile.number_of_referrals,
    profile.monthly_charge,
    profile.total_revenue,
    profile.total_refunds,
    profile.has_negative_monthly_charge
from scores
inner join profile on scores.customer_id = profile.customer_id
