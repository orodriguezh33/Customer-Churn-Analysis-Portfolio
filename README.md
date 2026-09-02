# Customer Churn Analysis Portfolio

Portafolio de analitica de churn de clientes con un flujo completo desde
ingesta de datos hasta dashboard ejecutivo:

- Dataset fuente: `data/Customer_Data.csv` con 6,418 clientes.
- Pipeline analitico: notebooks `01` a `09` para carga, EDA, preparacion,
  modelado, evaluacion y resultados de negocio.
- Arquitectura de datos: Databricks + dbt con capas Bronze, Silver, Gold y
  ML.
- Modelo predictivo: Logistic Regression como modelo ganador, con umbral
  operativo ajustado para priorizar recall.
- Consumo final: especificacion de dashboard Power BI con metricas de churn,
  perfil de clientes en riesgo, rendimiento del modelo y oportunidades de
  retencion.

## Resultados Principales

- Filas fuente: 6,418 clientes.
- Clientes nuevos puntuados: 405 `Joined`.
- Modelo final: `logistic_regression`.
- Umbral operativo: `0.2545`.
- Metricas del modelo final: accuracy `0.7555`, precision `0.5510`, recall
  `0.8240`, F1 `0.6604`, ROC AUC `0.8662`.
- Variables mas influyentes: `Monthly_Charge`, contrato mes a mes, contrato
  de dos anos, ofertas de valor y edad.

## Arquitectura

```text
CSV fuente
  -> Databricks Bronze
  -> dbt Silver
  -> dbt Gold
  -> notebooks de ML
  -> dbt ML
  -> Power BI
```

Documentacion clave:

- [Objetivos del proyecto](docs/project-goals.md)
- [Setup Databricks](docs/databricks-setup.md)
- [Setup dbt](docs/dbt-setup.md)
- [Modelos dbt](docs/dbt-models.md)
- [Medidas DAX](docs/powerbi-dax-measures.md)
- [Dashboard Power BI](docs/powerbi-dashboard-spec.md)
- [Guia de implementacion del portafolio](docs/portfolio-implementation-guide.md)

## Estructura del Repositorio

```text
data/          datos fuente y exportaciones procesadas
notebooks/     analisis y modelado paso a paso
dbt/           modelos SQL, tests y documentacion de la capa medallion
sql/           scripts de setup para Databricks
models/        modelos entrenados serializados
docs/          documentacion tecnica y guia del portafolio
reports/       diagramas y artefactos visuales
src/           codigo Python reusable
```

## Como Reproducir

```bash
uv sync
uv run jupyter lab
cd dbt
dbt build
```

Para reconstruir la infraestructura remota, sigue primero
`docs/databricks-setup.md` y despues `docs/dbt-setup.md`.
