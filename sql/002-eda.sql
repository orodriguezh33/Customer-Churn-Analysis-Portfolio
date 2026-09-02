-- ============================================================================
-- EDA exploratorio sobre la tabla bronze (customer_data), previo a diseñar las
-- transformaciones de la capa silver/gold. Son consultas ad-hoc pensadas para
-- correrse celda por celda en un notebook/SQL editor de Databricks, no un
-- script transaccional (por eso la mayoría no llevan ";" entre sí).
-- ============================================================================

-- Vistazo rápido de la forma cruda de los datos tal como llegan del CSV.
SELECT * FROM churn_portfolio.bronze.customer_data LIMIT 10



-- Distribución de clientes por género y su % sobre el total.
-- Nota: count(Gender) ignora filas con Gender NULL, pero el denominador
-- (subquery con count(*)) sí las cuenta -> si hay nulos, los porcentajes
-- no van a sumar exactamente 100%.

SELECT
 Gender,
 count(Gender) AS TotalCount,
 count(Gender) * 100/ (SELECT count(*) FROM churn_portfolio.bronze.customer_data) AS percentage
FROM churn_portfolio.bronze.customer_data
GROUP BY Gender

/*

Gender	TotalCount	percentage
Male	2370	36.92739171081334
Female	4048	63.07260828918666

*/





-- Distribución de clientes por tipo de contrato (mes a mes, 1 año, 2 años) y
-- su % sobre el total. Misma advertencia de NULLs que la consulta anterior.
SELECT
 Contract,
 count(Contract) AS TotalCount,
 count(Contract) * 100/ (SELECT count(*) FROM churn_portfolio.bronze.customer_data) AS percentage
FROM churn_portfolio.bronze.customer_data
GROUP BY Contract

/*

Contract	TotalCount	percentage
Month-to-Month	3286	51.19975070115301
Two Year	1719	26.78404487379246
One Year	1413	22.016204425054536

*/


-- Conteo de clientes y revenue total por Customer_Status (Joined/Stayed/Churned),
-- con el % de revenue que representa cada estado sobre el revenue total.
-- Útil para dimensionar cuánto ingreso está en riesgo por churn.
SELECT
 Customer_Status,
 count(Customer_Status) AS TotalCount,
 sum(Total_Revenue) as TotalRevenue,
 sum(Total_Revenue) / (SELECT sum(Total_Revenue) FROM churn_portfolio.bronze.customer_data) * 100 AS RevenuePercentage
FROM churn_portfolio.bronze.customer_data
GROUP BY Customer_Status

/*

Customer_Status	TotalCount	TotalRevenue	RevenuePercentage
Joined	411	49281.55999999999	0.253097282537616
Stayed	4275	16010148.269999998	82.22396004025266
Churned	1732	3411960.580000004	17.522942677209674

*/

-- Distribución geográfica de clientes por State, ordenada de mayor a menor
-- concentración, para identificar los mercados con más peso.
SELECT
State,
count(State) as TotalCount,
count(State)* 100 / (SELECT count(*) FROM churn_portfolio.bronze.customer_data) as percentage
FROM churn_portfolio.bronze.customer_data
GROUP BY State
ORDER BY percentage DESC


/*

State	TotalCount	percentage
Uttar Pradesh	629	9.800560922405733
Tamil Nadu	600	9.348706762231224
Maharashtra	504	7.852913680274229
Karnataka	470	7.32315363041446
Haryana	398	6.201308818946712
Andhra Pradesh	395	6.154565285135556
West Bengal	368	5.733873480835151
Punjab	342	5.328762854471798
Bihar	336	5.235275786849486
Gujarat	335	5.219694608912434
Jammu & Kashmir	320	4.985976939856653
Madhya Pradesh	288	4.487379245870988
Telangana	281	4.378311000311624
Rajasthan	259	4.035525085696479
Kerala	200	3.1162355874104084
Odisha	152	2.36833904643191
Assam	139	2.1657837332502337
Delhi	127	1.9788095980056093
Jharkhand	113	1.7606731068868806
Uttarakhand	62	0.9660330320972266
Chhattisgarh	59	0.9192894982860704
Puducherry	41	0.6388282954191337

*/



-- Valores únicos de Internet_Type, para conocer el dominio de la columna
-- antes de usarla en filtros o en el modelo (ej. DSL, Fiber Optic, Cable, NULL).
select distinct Internet_Type from churn_portfolio.bronze.customer_data


/*

Internet_Type
Cable
Fiber Optic
DSL
null

*/


-- Auditoría de calidad de datos: cuenta nulos columna por columna en un solo
-- pase sobre la tabla bronze. Sirve como checklist antes de definir reglas de
-- limpieza/valores por defecto en la capa silver (qué columnas requieren
-- manejo de nulos y cuáles no).
SELECT
    SUM(CASE WHEN Customer_ID IS NULL THEN 1 ELSE 0 END) AS Customer_ID_Null_Count,
    SUM(CASE WHEN Gender IS NULL THEN 1 ELSE 0 END) AS Gender_Null_Count,
    SUM(CASE WHEN Age IS NULL THEN 1 ELSE 0 END) AS Age_Null_Count,
    SUM(CASE WHEN Married IS NULL THEN 1 ELSE 0 END) AS Married_Null_Count,
    SUM(CASE WHEN State IS NULL THEN 1 ELSE 0 END) AS State_Null_Count,
    SUM(CASE WHEN Number_of_Referrals IS NULL THEN 1 ELSE 0 END) AS Number_of_Referrals_Null_Count,
    SUM(CASE WHEN Tenure_in_Months IS NULL THEN 1 ELSE 0 END) AS Tenure_in_Months_Null_Count,
    SUM(CASE WHEN Value_Deal IS NULL THEN 1 ELSE 0 END) AS Value_Deal_Null_Count,
    SUM(CASE WHEN Phone_Service IS NULL THEN 1 ELSE 0 END) AS Phone_Service_Null_Count,
    SUM(CASE WHEN Multiple_Lines IS NULL THEN 1 ELSE 0 END) AS Multiple_Lines_Null_Count,
    SUM(CASE WHEN Internet_Service IS NULL THEN 1 ELSE 0 END) AS Internet_Service_Null_Count,
    SUM(CASE WHEN Internet_Type IS NULL THEN 1 ELSE 0 END) AS Internet_Type_Null_Count,
    SUM(CASE WHEN Online_Security IS NULL THEN 1 ELSE 0 END) AS Online_Security_Null_Count,
    SUM(CASE WHEN Online_Backup IS NULL THEN 1 ELSE 0 END) AS Online_Backup_Null_Count,
    SUM(CASE WHEN Device_Protection_Plan IS NULL THEN 1 ELSE 0 END) AS Device_Protection_Plan_Null_Count,
    SUM(CASE WHEN Premium_Support IS NULL THEN 1 ELSE 0 END) AS Premium_Support_Null_Count,
    SUM(CASE WHEN Streaming_TV IS NULL THEN 1 ELSE 0 END) AS Streaming_TV_Null_Count,
    SUM(CASE WHEN Streaming_Movies IS NULL THEN 1 ELSE 0 END) AS Streaming_Movies_Null_Count,
    SUM(CASE WHEN Streaming_Music IS NULL THEN 1 ELSE 0 END) AS Streaming_Music_Null_Count,
    SUM(CASE WHEN Unlimited_Data IS NULL THEN 1 ELSE 0 END) AS Unlimited_Data_Null_Count,
    SUM(CASE WHEN Contract IS NULL THEN 1 ELSE 0 END) AS Contract_Null_Count,
    SUM(CASE WHEN Paperless_Billing IS NULL THEN 1 ELSE 0 END) AS Paperless_Billing_Null_Count,
    SUM(CASE WHEN Payment_Method IS NULL THEN 1 ELSE 0 END) AS Payment_Method_Null_Count,
    SUM(CASE WHEN Monthly_Charge IS NULL THEN 1 ELSE 0 END) AS Monthly_Charge_Null_Count,
    SUM(CASE WHEN Total_Charges IS NULL THEN 1 ELSE 0 END) AS Total_Charges_Null_Count,
    SUM(CASE WHEN Total_Refunds IS NULL THEN 1 ELSE 0 END) AS Total_Refunds_Null_Count,
    SUM(CASE WHEN Total_Extra_Data_Charges IS NULL THEN 1 ELSE 0 END) AS Total_Extra_Data_Charges_Null_Count,
    SUM(CASE WHEN Total_Long_Distance_Charges IS NULL THEN 1 ELSE 0 END) AS Total_Long_Distance_Charges_Null_Count,
    SUM(CASE WHEN Total_Revenue IS NULL THEN 1 ELSE 0 END) AS Total_Revenue_Null_Count,
    SUM(CASE WHEN Customer_Status IS NULL THEN 1 ELSE 0 END) AS Customer_Status_Null_Count,
    SUM(CASE WHEN Churn_Category IS NULL THEN 1 ELSE 0 END) AS Churn_Category_Null_Count,
    SUM(CASE WHEN Churn_Reason IS NULL THEN 1 ELSE 0 END) AS Churn_Reason_Null_Count
FROM churn_portfolio.bronze.customer_data;


/*

Value_Deal_Null_Count = 3548
Multiple_Lines_Null_Count = 622
Internet_Type_Null_Count = 1390
Online_Security_Null_Count = 1390
Online_Backup_Null_Count = 1390
Device_Protection_Plan_Null_Count = 1390
Premium_Support_Null_Count = 1390
Streaming_TV_Null_Count = 1390
Streaming_Movies_Null_Count = 1390
Streaming_Music_Null_Count = 1390
Unlimited_Data_Null_Count = 1390
Churn_Category_Null_Count = 4686
Churn_Reason_Null_Count = 4686

*/


-- Cuantifica la anomalía de datos conocida en Monthly_Charge: cuántas filas tienen un valor negativo
-- Este es el número que justifica el flag has_negative_monthly_charge de la proyección silver más abajo.


select
 count(Monthly_Charge) as negative_monthly_charge
from churn_portfolio.bronze.customer_data
where monthly_charge < 0


/*

negative_monthly_charge = 107

*/




-- Prototipo de la proyección silver: renombra columnas de bronze a
-- snake_case y agrega el flag has_negative_monthly_charge para marcar
-- explícitamente los ~107 registros con Monthly_Charge negativo. El valor crudo de
-- monthly_charge se deja intacto -- este flag es lo que se debe usar para
-- excluir esos registros si monthly_charge se usa como feature numérico en
-- un modelo de churn, sin alterar los totales/conteos de BI aguas abajo.


select
    Customer_ID as customer_id,
    Gender as gender,
    Age as age,
    Married as is_married,
    State as state,
    Number_of_Referrals as number_of_referrals,
    Tenure_in_Months as tenure_in_months,
    Value_Deal as value_deal,
    Contract as contract,
    Payment_Method as payment_method,
    Monthly_Charge as monthly_charge,
    Monthly_Charge < 0 as has_negative_monthly_charge,
    Total_Charges as total_charges,
    Total_Refunds as total_refunds,
    Total_Extra_Data_Charges as total_extra_data_charges,
    Total_Long_Distance_Charges as total_long_distance_charges,
    Total_Revenue as total_revenue,
    Customer_Status as customer_status,
    Churn_Category as churn_category,
    Churn_Reason as churn_reason
FROM churn_portfolio.bronze.customer_data;
