import numpy as np
import pandas as pd
import pytest

import churn_analysis_portfolio.missing  # noqa: F401


@pytest.fixture
def sample_df() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "a": [1.0, np.nan, 3.0, np.nan],
            "b": [np.nan, 2.0, 3.0, 4.0],
            "c": ["x", "y", None, "z"],
        }
    )


def test_counts_missing_and_complete_values(sample_df: pd.DataFrame) -> None:
    assert sample_df.missing.number_missing() == 4
    assert sample_df.missing.number_complete() == 8


def test_missing_variable_table_uses_stable_column_names(sample_df: pd.DataFrame) -> None:
    result = sample_df.missing.missing_variable_table()

    assert result.to_dict("records") == [
        {
            "n_missing_in_variable": 2,
            "n_variables": 1,
            "pct_variables": pytest.approx(100 / 3),
        },
        {
            "n_missing_in_variable": 1,
            "n_variables": 2,
            "pct_variables": pytest.approx(200 / 3),
        },
    ]


def test_missing_case_table_uses_stable_column_names(sample_df: pd.DataFrame) -> None:
    result = sample_df.missing.missing_case_table()

    assert result.to_dict("records") == [
        {
            "n_missing_in_case": 1,
            "n_cases": 4,
            "pct_cases": 100.0,
        }
    ]


def test_span_and_run_summaries_are_generic(sample_df: pd.DataFrame) -> None:
    span = sample_df.missing.missing_variable_span("a", span_every=2)
    run = sample_df.missing.missing_variable_run("a")

    assert span[["span_counter", "n_in_span", "n_missing"]].to_dict("records") == [
        {"span_counter": 0, "n_in_span": 2, "n_missing": 1},
        {"span_counter": 1, "n_in_span": 2, "n_missing": 1},
    ]
    assert run.to_dict("records") == [
        {"run_length": 1, "is_na": "complete"},
        {"run_length": 1, "is_na": "missing"},
        {"run_length": 1, "is_na": "complete"},
        {"run_length": 1, "is_na": "missing"},
    ]


def test_scan_count_accepts_scalar_and_iterable(sample_df: pd.DataFrame) -> None:
    scalar = sample_df.missing.missing_scan_count("x")
    iterable = sample_df.missing.missing_scan_count(["x", None])

    assert scalar.loc[scalar["variable"].eq("c"), "n"].item() == 1
    assert iterable.loc[iterable["variable"].eq("c"), "n"].item() == 2


def test_imputation_plot_validates_columns(sample_df: pd.DataFrame) -> None:
    with pytest.raises(KeyError, match="Column not found"):
        sample_df.missing.scatterplot_imputation_plot("missing_col", "a")


def test_missing_variable_run_handles_empty_dataframe() -> None:
    df = pd.DataFrame({"a": []})

    result = df.missing.missing_variable_run("a")

    assert list(result.columns) == ["run_length", "is_na"]
    assert result.empty


def test_missing_upsetplot_returns_axes_mapping(sample_df: pd.DataFrame) -> None:
    import matplotlib
    import matplotlib.pyplot as plt

    matplotlib.use("Agg")

    result = sample_df.missing.missing_upsetplot(
        variables=["a", "b", "c"],
        element_size=30,
        show_counts=True,
    )

    assert {"matrix", "intersections", "totals"}.issubset(result)
    plt.gcf().canvas.draw()
    plt.close("all")
