from __future__ import annotations

from collections.abc import Iterable
from types import MethodType
from typing import Any

import numpy as np
import pandas as pd


try:
    del pd.DataFrame.missing
except AttributeError:
    pass


@pd.api.extensions.register_dataframe_accessor("missing")
class MissingMethods:
    """Pandas DataFrame accessor for missing-data diagnostics."""

    def __init__(self, pandas_obj: pd.DataFrame) -> None:
        self._obj = pandas_obj

    def number_missing(self) -> int:
        return int(self._obj.isna().sum().sum())

    def number_complete(self) -> int:
        return int(self._obj.size - self.number_missing())

    def missing_variable_summary(self) -> pd.DataFrame:
        n_cases = len(self._obj)
        return (
            self._obj.isna()
            .sum()
            .rename("n_missing")
            .reset_index()
            .rename(columns={"index": "variable"})
            .assign(
                n_cases=n_cases,
                pct_missing=lambda df: np.where(
                    df["n_cases"].eq(0),
                    0.0,
                    df["n_missing"] / df["n_cases"] * 100,
                ),
            )
        )

    def missing_case_summary(self) -> pd.DataFrame:
        n_variables = self._obj.shape[1]
        n_missing = self._obj.isna().sum(axis="columns")
        pct_missing = np.where(n_variables == 0, 0.0, n_missing / n_variables * 100)

        return pd.DataFrame(
            {
                "case": self._obj.index,
                "n_missing": n_missing.to_numpy(),
                "pct_missing": pct_missing,
            },
            index=self._obj.index,
        ).reset_index(drop=True)

    def missing_variable_table(self) -> pd.DataFrame:
        return (
            self.missing_variable_summary()
            .groupby("n_missing", as_index=False)
            .size()
            .rename(
                columns={
                    "n_missing": "n_missing_in_variable",
                    "size": "n_variables",
                }
            )
            .assign(
                pct_variables=lambda df: np.where(
                    df["n_variables"].sum() == 0,
                    0.0,
                    df["n_variables"] / df["n_variables"].sum() * 100,
                )
            )
            .sort_values(
                ["n_missing_in_variable", "pct_variables"],
                ascending=[False, False],
            )
            .reset_index(drop=True)
        )

    def missing_case_table(self) -> pd.DataFrame:
        return (
            self.missing_case_summary()
            .groupby("n_missing", as_index=False)
            .size()
            .rename(
                columns={
                    "n_missing": "n_missing_in_case",
                    "size": "n_cases",
                }
            )
            .assign(
                pct_cases=lambda df: np.where(
                    df["n_cases"].sum() == 0,
                    0.0,
                    df["n_cases"] / df["n_cases"].sum() * 100,
                )
            )
            .sort_values(["n_missing_in_case", "pct_cases"], ascending=[False, False])
            .reset_index(drop=True)
        )

    def missing_variable_span(self, variable: str, span_every: int) -> pd.DataFrame:
        self._validate_variable(variable)
        if span_every <= 0:
            raise ValueError("span_every must be a positive integer")

        span_counter = np.arange(self._obj.shape[0]) // span_every
        return (
            self._obj.assign(span_counter=span_counter)
            .groupby("span_counter", as_index=False)
            .agg(
                n_in_span=(variable, "size"),
                n_missing=(variable, lambda s: s.isna().sum()),
            )
            .assign(
                n_complete=lambda df: df["n_in_span"] - df["n_missing"],
                pct_missing=lambda df: df["n_missing"] / df["n_in_span"] * 100,
                pct_complete=lambda df: 100 - df["pct_missing"],
            )
        )

    def missing_variable_run(self, variable: str) -> pd.DataFrame:
        self._validate_variable(variable)
        is_missing = self._obj[variable].isna()
        if is_missing.empty:
            return pd.DataFrame(columns=["run_length", "is_na"])

        group_id = is_missing.ne(is_missing.shift(fill_value=is_missing.iloc[0])).cumsum()

        return (
            pd.DataFrame({"is_na": is_missing, "group_id": group_id})
            .groupby(["group_id", "is_na"], as_index=False)
            .size()
            .rename(columns={"size": "run_length"})
            .assign(is_na=lambda df: df["is_na"].map({False: "complete", True: "missing"}))
            [["run_length", "is_na"]]
        )

    def sort_variables_by_missingness(self, ascending: bool = False) -> pd.DataFrame:
        ordered_columns = self._obj.isna().sum().sort_values(ascending=ascending).index
        return self._obj.loc[:, ordered_columns]

    def create_shadow_matrix(
        self,
        true_string: str = "Missing",
        false_string: str = "Not Missing",
        only_missing: bool = False,
    ) -> pd.DataFrame:
        shadow = self._obj.isna()
        if only_missing:
            shadow = shadow.loc[:, shadow.any(axis="rows")]

        return shadow.replace({False: false_string, True: true_string}).add_suffix("_NA")

    def bind_shadow_matrix(
        self,
        true_string: str = "Missing",
        false_string: str = "Not Missing",
        only_missing: bool = False,
    ) -> pd.DataFrame:
        return pd.concat(
            [
                self._obj,
                self.create_shadow_matrix(
                    true_string=true_string,
                    false_string=false_string,
                    only_missing=only_missing,
                ),
            ],
            axis="columns",
        )

    def missing_scan_count(self, search: Any | Iterable[Any]) -> pd.DataFrame:
        search_values = self._coerce_search_values(search)
        return (
            self._obj.apply(lambda column: column.isin(search_values), axis="rows")
            .sum()
            .rename("n")
            .reset_index()
            .rename(columns={"index": "variable"})
            .assign(original_type=lambda df: df["variable"].map(self._obj.dtypes))
        )

    def missing_variable_plot(self, ax: Any = None, **kwargs: Any) -> Any:
        import matplotlib.pyplot as plt

        df = self.missing_variable_summary().sort_values("n_missing")
        ax = ax or plt.gca()
        plot_range = range(1, len(df.index) + 1)

        ax.hlines(
            y=plot_range,
            xmin=0,
            xmax=df["n_missing"],
            color=kwargs.pop("color", "black"),
            **kwargs,
        )
        ax.plot(df["n_missing"], plot_range, "o", color="black")
        ax.set_yticks(list(plot_range), df["variable"])
        ax.grid(axis="y")
        ax.set_xlabel("Number missing")
        ax.set_ylabel("Variable")
        return ax

    def missing_case_plot(self, **kwargs: Any) -> Any:
        import matplotlib.pyplot as plt
        import seaborn as sns

        ax = sns.histplot(
            data=self.missing_case_summary(),
            x="n_missing",
            binwidth=1,
            color=kwargs.pop("color", "black"),
            **kwargs,
        )
        ax.grid(axis="x")
        ax.set_xlabel("Number of missing values in case")
        ax.set_ylabel("Number of cases")
        plt.tight_layout()
        return ax

    def missing_variable_span_plot(
        self,
        variable: str,
        span_every: int,
        rot: int = 0,
        figsize: tuple[float, float] | None = None,
        ax: Any = None,
    ) -> Any:
        import matplotlib.pyplot as plt

        ax = self.missing_variable_span(variable=variable, span_every=span_every).plot.bar(
            x="span_counter",
            y=["pct_missing", "pct_complete"],
            stacked=True,
            width=1,
            color=["black", "lightgray"],
            rot=rot,
            figsize=figsize,
            ax=ax,
        )
        ax.set_xlabel("Span number")
        ax.set_ylabel("Percentage")
        ax.legend(["Missing", "Complete"])
        ax.set_title(
            f"Missingness over repeating spans of {span_every} rows",
            loc="left",
        )
        ax.grid(False)
        plt.margins(0)
        plt.tight_layout(pad=0)
        return ax

    def missing_upsetplot(self, variables: list[str] | None = None, **kwargs: Any) -> Any:
        import upsetplot

        variables = variables or self._obj.columns.tolist()
        for variable in variables:
            self._validate_variable(variable)

        missing_counts = self._obj[variables].isna().value_counts()
        fig = kwargs.pop("fig", None)
        upset = upsetplot.UpSet(missing_counts, **kwargs)
        self._patch_upsetplot_matrix(upset)
        self._patch_upsetplot_label_sizes(upset)
        return upset.plot(fig=fig)

    def scatterplot_imputation_plot(
        self,
        x_col: str,
        y_col: str,
        impute_strategy: str = "mean",
        **kwargs: Any,
    ) -> Any:
        self._validate_variable(x_col)
        self._validate_variable(y_col)
        if impute_strategy not in {"mean", "median"}:
            raise ValueError("impute_strategy must be 'mean' or 'median'")

        import seaborn as sns

        plot_df = self._obj[[x_col, y_col]].copy()
        was_imputed = plot_df[[x_col, y_col]].isna().any(axis="columns")
        for column in [x_col, y_col]:
            fill_value = getattr(plot_df[column], impute_strategy)()
            plot_df[column] = plot_df[column].fillna(fill_value)

        plot_df = plot_df.assign(imputed=was_imputed)
        return sns.scatterplot(data=plot_df, x=x_col, y=y_col, hue="imputed", **kwargs)

    def _validate_variable(self, variable: str) -> None:
        if variable not in self._obj.columns:
            raise KeyError(f"Column not found: {variable}")

    @staticmethod
    def _coerce_search_values(search: Any | Iterable[Any]) -> list[Any]:
        if isinstance(search, str) or not isinstance(search, Iterable):
            return [search]
        return list(search)

    @staticmethod
    def _patch_upsetplot_matrix(upset: Any) -> None:
        """Patch upsetplot's matrix for pandas versions where inplace fillna is inert."""

        def plot_matrix(self: Any, ax: Any) -> None:
            ax = self._reorient(ax)
            data = self.intersections
            n_cats = data.index.nlevels
            inclusion = data.index.to_frame().values

            styles = [
                [
                    self.subset_styles[i]
                    if inclusion[i, j]
                    else {"facecolor": self._other_dots_color, "linewidth": 0}
                    for j in range(n_cats)
                ]
                for i in range(len(data))
            ]
            styles = sum(styles, [])
            style_columns = {
                "facecolor": "facecolors",
                "edgecolor": "edgecolors",
                "linewidth": "linewidths",
                "linestyle": "linestyles",
                "hatch": "hatch",
            }
            styles = (
                pd.DataFrame(styles)
                .reindex(columns=style_columns.keys())
                .astype(
                    {
                        "facecolor": "O",
                        "edgecolor": "O",
                        "linewidth": float,
                        "linestyle": "O",
                        "hatch": "O",
                    }
                )
            )
            styles["linewidth"] = styles["linewidth"].fillna(1)
            styles["facecolor"] = styles["facecolor"].fillna(self._facecolor)
            styles["edgecolor"] = styles["edgecolor"].fillna(styles["facecolor"])
            styles["linestyle"] = styles["linestyle"].fillna("solid")
            del styles["hatch"]

            x = np.repeat(np.arange(len(data)), n_cats)
            y = np.tile(np.arange(n_cats), len(data))
            s = (self._element_size * 0.35) ** 2 if self._element_size is not None else 200
            ax.scatter(
                *self._swapaxes(x, y),
                s=s,
                zorder=10,
                **styles.rename(columns=style_columns),
            )

            if self._with_lines:
                idx = np.flatnonzero(inclusion)
                line_data = (
                    pd.Series(y[idx], index=x[idx])
                    .groupby(level=0)
                    .aggregate(["min", "max"])
                )
                colors = pd.Series(
                    [
                        style.get("edgecolor", style.get("facecolor", self._facecolor))
                        for style in self.subset_styles
                    ],
                    name="color",
                )
                line_data = line_data.join(colors)
                ax.vlines(
                    line_data.index.values,
                    line_data["min"],
                    line_data["max"],
                    lw=2,
                    colors=line_data["color"],
                    zorder=5,
                )

            tick_axis = ax.yaxis
            tick_axis.set_ticks(np.arange(n_cats))
            tick_axis.set_ticklabels(
                data.index.names, rotation=0 if self._horizontal else -90
            )
            ax.xaxis.set_visible(False)
            ax.tick_params(axis="both", which="both", length=0)
            if not self._horizontal:
                ax.yaxis.set_ticks_position("top")
            ax.set_frame_on(False)
            ax.set_xlim(-0.5, x[-1] + 0.5, auto=False)
            ax.grid(False)

        upset.plot_matrix = MethodType(plot_matrix, upset)

    @staticmethod
    def _patch_upsetplot_label_sizes(upset: Any) -> None:
        """Patch upsetplot count labels for Matplotlib versions requiring scalar text positions."""

        def label_sizes(self: Any, ax: Any, rects: Any, where: str) -> None:
            if not self._show_counts and not self._show_percentages:
                return

            if self._show_counts is True:
                count_fmt = "{:.0f}"
            else:
                count_fmt = self._show_counts
                if "{" not in count_fmt:
                    from upsetplot import util

                    count_fmt = util.to_new_pos_format(count_fmt)

            pct_fmt = "{:.1%}" if self._show_percentages is True else self._show_percentages

            if count_fmt and pct_fmt:
                fmt = f"{count_fmt}\n({pct_fmt})" if where == "top" else f"{count_fmt} ({pct_fmt})"

                def make_args(val: float) -> tuple[float, float]:
                    return val, val / self.total

            elif count_fmt:
                fmt = count_fmt

                def make_args(val: float) -> tuple[float]:
                    return (val,)

            else:
                fmt = pct_fmt

                def make_args(val: float) -> tuple[float]:
                    return (val / self.total,)

            if where in {"right", "left"}:
                margin = float(0.01 * abs(np.diff(ax.get_xlim())).item())
                ha = "left" if where == "right" else "right"
                for rect in rects:
                    width = float(rect.get_width() + rect.get_x())
                    ax.text(
                        width + margin,
                        float(rect.get_y() + rect.get_height() * 0.5),
                        fmt.format(*make_args(width)),
                        ha=ha,
                        va="center",
                    )
            elif where == "top":
                margin = float(0.01 * abs(np.diff(ax.get_ylim())).item())
                for rect in rects:
                    height = float(rect.get_height() + rect.get_y())
                    ax.text(
                        float(rect.get_x() + rect.get_width() * 0.5),
                        height + margin,
                        fmt.format(*make_args(height)),
                        ha="center",
                        va="bottom",
                    )
            else:
                raise NotImplementedError(f"unhandled where: {where!r}")

        upset._label_sizes = MethodType(label_sizes, upset)
