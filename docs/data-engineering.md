# Data Engineering

This document summarizes the engineering side of the project: ingestion,
transformations, medallion architecture, dbt models, and quality controls.

## Objective

Build a reproducible analytics foundation from `data/Customer_Data.csv` to
answer questions about historical churn, customer profile, and prediction for
new customers.

## Data Source

| Element             |                    Value |
| ------------------- | -----------------------: |
| Source file         | `data/Customer_Data.csv` |
| Rows                |                    6,418 |
| Columns             |                       32 |
| `Stayed` customers  |                    4,275 |
| `Churned` customers |                    1,732 |
| `Joined` customers  |                      411 |

The target column is `Customer_Status`, with three states:

- `Stayed`: customer with a known outcome who remains.
- `Churned`: customer with a known outcome who churned.
- `Joined`: new customer, with no known outcome yet; used for scoring.

## Medallion Architecture

```text
data/Customer_Data.csv
  -> churn_portfolio.bronze.customer_data
  -> churn_portfolio.silver.silver_customers
  -> churn_portfolio.gold.gold_customer_data
  -> churn_portfolio.gold.gold_customer_services
  -> churn_portfolio.ml.*
```

### Bronze

The Bronze layer is created with `sql/001-create-catalog.sql`.

Responsibility:

- Create the `churn_portfolio` catalog.
- Create the `bronze`, `silver`, and `gold` schemas.
- Load the raw CSV as a Delta table into
  `churn_portfolio.bronze.customer_data`.

The Bronze table keeps the data as close to the source as possible.

### Silver

Main model: `dbt/models/silver/silver_customers.sql`.

Responsibility:

- Rename columns to `snake_case`.
- Keep one row per customer.
- Preserve demographic, geographic, service, contract, charge, and customer
  status attributes.
- Flag the `has_negative_monthly_charge` anomaly.

Relevant tests:

- `customer_id` unique and not null.
- `customer_status` limited to `Joined`, `Stayed`, `Churned`.
- `churn_category` validated for `Churned` customers.

### Gold

Main models:

- `dbt/models/gold/gold_customer_data.sql`
- `dbt/models/gold/gold_customer_services.sql`

Responsibility of `gold_customer_data`:

- Create `churn_flag`.
- Create monthly charge ranges.
- Deliver a central table for BI metrics and segmentation.

Responsibility of `gold_customer_services`:

- Unpivot service attributes.
- Create a view with customer-service grain.
- Enable service-adoption analysis in Power BI.

### ML

The notebooks generate outputs in `data/processed/`. Then
`sql/003-create-ml-layer.sql` loads them into Bronze and dbt publishes them in
the `ml` schema.

dbt models in the ML layer:

| Model                         | Use                                 |
| ----------------------------- | ----------------------------------- |
| `ml_customers_at_risk`        | Churn scores for `Joined` customers |
| `ml_model_candidates`         | Comparison of candidate models      |
| `ml_model_metrics`            | Final metrics of the deployed model |
| `ml_model_confusion_matrix`   | Confusion matrix of the final model |
| `ml_model_feature_importance` | Most influential variables          |
| `ml_model_roc_curve`          | ROC curve points                    |

## Data Quality

Controls and decisions visible in the project:

- `Customer_ID` is validated as unique and not null in dbt.
- `Customer_Status` is validated against accepted values.
- `Monthly_Charge < 0` is flagged as an anomaly. The dataset contains 107 rows
  in that condition.
- Customers with negative monthly charges are excluded from model training and
  scoring.
- The ML layer validates that `risk_tier` and `predicted_churn` are consistent
  with `churn_risk_score`.

## Reproducibility

Main commands:

```bash
uv sync
uv run jupyter lab
cd dbt
dbt build
```

Expected flow order:

1. Load `Customer_Data.csv` into Bronze.
2. Run `dbt build` for Silver and Gold.
3. Run notebooks `01` through `09`.
4. Load outputs from `data/processed/` into ML Bronze.
5. Run `dbt build` to publish ML models.
6. Consume Gold and ML tables from Power BI.

## Visual Evidence

### Databricks

![Databricks SQL EDA](../img/04-Databricks-sql-eda.png)

![Databricks SQL EDA](../img/04.1-Databricks-sql-eda.png)

### Dbt Build

![dbt Build](../img/06-dbt-build.png)
