# Customer Churn Analysis Portfolio

End-to-end project to analyze customer churn, build a reproducible analytics
architecture, and prioritize customers at risk of churning.

The flow covers data ingestion, dbt transformations, exploratory analysis,
model training, operational threshold selection, and a final layer for
consumption in Power BI.

## Visual Demo

![Dashboard Summary](img/01-Summary.png)

![Churn Prediction](img/02-Churn-prediction.png)

## Key Results

| Area                                                |              Result |
| --------------------------------------------------- | ------------------: |
| Customers in source dataset                         |               6,418 |
| Customers with known outcome (`Stayed` + `Churned`) |               6,007 |
| Customers with historical churn                     |               1,732 |
| Historical churn rate                               |               28.8% |
| `Joined` customers scored by the model              |                 405 |
| Customers predicted as churn                        |                 280 |
| Final model                                         | Logistic Regression |
| Operational threshold                               |              0.2545 |
| Final recall                                        |              0.8240 |
| Final ROC AUC                                       |              0.8662 |

The model was optimized to prioritize recall, since in a retention use case it
is preferable to identify more at-risk customers even if false positives
increase.

## Medallion Architecture

![Medallion Architecture](img/03-Medallion-architecture.png)

```text
Source CSV
  -> Databricks Bronze
  -> dbt Silver
  -> dbt Gold
  -> Machine Learning notebooks
  -> dbt ML
  -> Power BI
```

The Bronze layer preserves the raw data. Silver normalizes names and types.
Gold aggregates analytical variables for BI. The ML layer publishes scores,
metrics, the confusion matrix, the ROC curve, and feature importance for the
dashboard.

## Final Model

![Model Performance](img/05.1-Model-performance.png)

## Optimized Model

![Model Performance](img/05.1-Optimized-model.png)

## Confusion Matrix

![Confusion Matrix](img/05.2-Confusion-matriz.png)

Most influential variables in the final model:

- `Monthly_Charge`
- `Contract_Month-to-Month`
- `Contract_Two Year`
- `Value_Deal_Deal 5`
- `Age`

## Repository Structure

| Path         | Contents                                                  |
| ------------ | --------------------------------------------------------- |
| `data/`      | Source dataset and processed outputs from the ML pipeline |
| `notebooks/` | Analytical flow from `01` to `09`                         |
| `sql/`       | Databricks scripts for catalogs, Bronze, and the ML layer |
| `dbt/`       | Silver, Gold, ML models, sources, and tests               |
| `models/`    | Serialized trained models                                 |
| `img/`       | Screenshots and charts used in the documentation          |
| `docs/`      | Official project documentation                            |

## How To Reproduce

Install dependencies:

```bash
uv sync
```

Run notebooks:

```bash
uv run jupyter lab
```

Run dbt:

```bash
cd dbt
dbt build
```

The notebook pipeline must be run in order, because the outputs from
`data/processed/` feed the ML layer and the dashboard.

## Documentation

- [Data engineering](docs/data-engineering.md)
- [Modeling and insights](docs/modeling-and-insights.md)
