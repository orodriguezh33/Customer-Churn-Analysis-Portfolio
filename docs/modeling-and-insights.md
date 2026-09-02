# Modelado e Insights

Este documento resume la parte analitica y de Machine Learning del proyecto:
EDA, preparacion de datos, comparacion de modelos, seleccion de umbral y
resultados para negocio.

## Objetivo Analitico

El proyecto busca responder tres preguntas:

1. Como se comporta el churn historico por perfil de cliente.
2. Que variables ayudan a explicar mayor o menor riesgo de churn.
3. Que clientes nuevos (`Joined`) deberian priorizarse para acciones de
   retencion.

## Flujo de Notebooks

| Notebook                          | Rol                                                 |
| --------------------------------- | --------------------------------------------------- |
| `01_load_data.ipynb`            | Carga, estructura, nulos, objetivo y duplicados     |
| `02_eda.ipynb`                  | EDA, churn por segmento, anomalias y asociaciones   |
| `03_statistical_analysis.ipynb` | Pruebas estadisticas y fuerza de asociacion         |
| `04_train_test_split.ipynb`     | Limpieza, control de leakage y split                |
| `05_feature_engineering.ipynb`  | One-hot encoding ajustado solo con train            |
| `06_modeling.ipynb`             | Entrenamiento de modelos candidatos                 |
| `07_model_evaluation.ipynb`     | Comparacion de modelos                              |
| `08_final_model.ipynb`          | Tuning, threshold operativo y metricas finales      |
| `09_business_insights.ipynb`    | Scoring, tiers de riesgo e importancia de variables |

## Preparacion Para Modelado

La base modelable excluye clientes `Joined`, porque no tienen desenlace
conocido. Tambien excluye filas con `Monthly_Charge < 0`.

Decisiones principales:

- Variable objetivo: `Customer_Status`.
- Clase positiva: `Churned`.
- Clientes `Joined`: reservados para scoring posterior.
- Columnas de leakage y acumulados desde el alta: excluidas antes de entrenar.
- Encoding categorico: ajustado solo con `X_train`.

Estas decisiones evitan que el modelo aprenda informacion que no estaria
disponible al momento de predecir churn.

## Comparacion de Modelos

| Modelo              | Accuracy | Precision | Recall |    F1 | ROC AUC | Ganador |
| ------------------- | -------: | --------: | -----: | ----: | ------: | ------- |
| Logistic Regression |    0.831 |     0.709 |  0.701 | 0.705 |   0.867 | Si      |
| Decision Tree       |    0.739 |     0.547 |  0.545 | 0.546 |   0.681 | No      |
| Random Forest       |    0.815 |     0.703 |  0.619 | 0.658 |   0.853 | No      |
| XGBoost             |    0.805 |     0.673 |  0.633 | 0.653 |   0.847 | No      |

La Logistic Regression fue seleccionada por balance entre rendimiento,
interpretabilidad y ROC AUC.

## Modelo Final

El modelo final usa Logistic Regression con umbral operativo ajustado a
`0.2545`.

| Metrica final |  Valor |
| ------------- | -----: |
| Accuracy      | 0.7555 |
| Precision     | 0.5510 |
| Recall        | 0.8240 |
| F1            | 0.6604 |
| ROC AUC       | 0.8662 |

El umbral se bajo frente al corte default de `0.5` para aumentar recall. En un
caso de churn, esto ayuda a capturar mas clientes en riesgo para campanas de
retencion.

## Matriz de Confusion

| Actual | Predicho | Clientes |
| ------ | -------- | -------: |
| Stayed | Stayed   |      612 |
| Stayed | Churn    |      229 |
| Churn  | Stayed   |       60 |
| Churn  | Churn    |      281 |

Lectura principal: el modelo captura 281 de 341 churners reales en test, lo que
explica el recall final de `0.8240`.

![Confusion Matrix](../img/05.2-Confusion-matriz.png)

## Variables más Influyentes

![Top variables](../img/07.1-Top-10-variables.png)

![Top variables](../img/07-Top-10-features.png)

Top variables por coeficiente estandarizado absoluto:

| Rank | Variable                    | Lectura                                          |
| ---: | --------------------------- | ------------------------------------------------ |
|    1 | `Monthly_Charge`          | Mayor cargo mensual empuja el riesgo hacia churn |
|    2 | `Contract_Month-to-Month` | Contrato mensual aumenta riesgo                  |
|    3 | `Contract_Two Year`       | Contrato de dos anos reduce riesgo               |
|    4 | `Value_Deal_Deal 5`       | Oferta asociada a mayor riesgo                   |
|    5 | `Age`                     | Mayor edad se asocia con mayor riesgo            |

La interpretacion usa el signo del coeficiente de Logistic Regression. No es
una prueba causal.

## Scoring de Clientes Nuevos

El scoring se aplica sobre clientes `Joined` validos para el pipeline.

| Segmento                     | Clientes |
| ---------------------------- | -------: |
| Clientes`Joined` puntuados |      405 |
| Predichos como churn         |      280 |
| Predichos como no churn      |      125 |
| Riesgo alto                  |      110 |
| Riesgo medio                 |      170 |
| Riesgo bajo                  |      125 |

Los tiers se definen con el score del modelo:

- `Low`: score menor al umbral operativo.
- `Medium`: score desde el umbral operativo hasta menor que `0.60`.
- `High`: score mayor o igual a `0.60`.

![Scoring de Clientes Nuevos](../img/08-Customer-churn.png)

## Insights de Negocio

Hallazgos principales para accion:

- Los clientes con contrato mes a mes concentran mayor riesgo.
- Cargos mensuales altos elevan la probabilidad de churn.
- Contratos de dos anos funcionan como senal protectora.
- Los clientes `Joined` con riesgo `High` y `Medium` son la primera poblacion
  para priorizar acciones de retencion.
- El dashboard separa churn historico y churn predicho para no mezclar
  poblaciones con denominadores distintos.

## Evidencia Visual

![Model Performance](../img/05.1-Optimized-model.png)

![Churn Prediction](../img/02-Churn-prediction.png)
