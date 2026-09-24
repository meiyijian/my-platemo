"""Build the IGD+ ablation tables from the two REMO-reference exports."""

from __future__ import annotations

import argparse
import re
from collections import Counter
from decimal import Decimal
from pathlib import Path

from openpyxl import load_workbook


ROOT = Path(__file__).resolve().parent
SOURCES = {
    10: ROOT / "sources" / "nobatchdict以RMEO为基准十目标IGDp.xlsx",
    20: ROOT / "sources" / "nobatchdict以RMEO为基准二十目标IGDp.xlsx",
}
OUTPUT = ROOT / "table_ablation_igdp.tex"
CELL = re.compile(r"^(\d+\.\d+e[+-]\d+) \((\d+\.\d+e[+-]\d+)\)(?: ([+=-]))?$")
FAMILIES = {"DTLZ": range(1, 8), "WFG": range(1, 10)}
SOURCE_COLUMNS = {"Full": 5, "w/o CDIS": 6, "w/o PAQC": 7, "REMO": 8}
TABLE_COLUMNS = ("REMO", "w/o CDIS", "w/o PAQC", "Full")


def parse_cell(value: str, *, reference: bool = False) -> tuple[str, str, str | None]:
    match = CELL.fullmatch(value)
    if match is None:
        raise ValueError(f"Invalid workbook cell: {value!r}")
    mean, sd, symbol = match.groups()
    if (symbol is None) != reference:
        raise ValueError(f"Wrong reference/symbol status: {value!r}")
    return mean, sd, symbol


def read_sources() -> dict[tuple[str, int], dict]:
    records = {}
    for m, path in SOURCES.items():
        sheet = load_workbook(path, read_only=True, data_only=True).active
        assert sheet.title == "IGDp", (path, sheet.title)
        rows = list(sheet.values)
        assert len(rows) == 18, (path, len(rows))
        assert rows[0] == (
            "Problem", "N", "M", "D", "FE", "full", "w/o CDIS",
            "w/o PAQC", f"REMO (k={15 if m == 10 else 30})",
        ), (path, rows[0])
        observed = {name: Counter() for name in SOURCE_COLUMNS if name != "REMO"}
        for row in rows[1:-1]:
            problem, n, row_m, d, fe = row[:5]
            assert (n, row_m, fe) == (100, m, 300), (path, row[:5])
            assert d == (31 if problem in {"WFG2", "WFG3"} else 30), row[:5]
            key = (problem, m)
            assert key not in records, key
            cells = {
                name: parse_cell(row[index], reference=name == "REMO")
                for name, index in SOURCE_COLUMNS.items()
            }
            reference_mean = Decimal(cells["REMO"][0])
            for name, (mean, _, symbol) in cells.items():
                if symbol == "+":
                    assert Decimal(mean) < reference_mean, (key, name, symbol)
                elif symbol == "-":
                    assert Decimal(mean) > reference_mean, (key, name, symbol)
            for name, (_, _, symbol) in cells.items():
                if symbol is not None:
                    observed[name][symbol] += 1
            records[key] = {"D": d, "cells": cells}
        for name, index in SOURCE_COLUMNS.items():
            if name == "REMO":
                assert rows[-1][index] is None
                continue
            counts = "/".join(str(observed[name][s]) for s in "+-=")
            assert rows[-1][index] == counts, (path, name, rows[-1][index], counts)
        assert rows[-1][:5] == ("+/-/=", None, None, None, None)
    assert len(records) == 32, len(records)
    assert set(records) == {
        (f"{family}{i}", m)
        for family, ids in FAMILIES.items()
        for i in ids
        for m in SOURCES
    }
    return records


def tex_number(value: str) -> str:
    mantissa, exponent = value.split("e")
    return f"{mantissa}\\mathrm{{e}}{{{exponent}}}"


def tex_cell(cell: tuple[str, str, str | None], best: bool) -> str:
    mean, sd, symbol = cell
    mark = f"^{{{symbol}}}" if symbol is not None else ""
    prefix = "\\bestcell" if best else ""
    return f"{prefix}${tex_number(mean)}\\,({tex_number(sd)}){mark}$"


def make_table(family: str, records: dict) -> str:
    name_range = "1--7" if family == "DTLZ" else "1--9"
    label = f"tab:ablation_igdplus_{family.lower()}"
    lines = [
        "\\begin{table*}[tp]",
        "\\centering",
        f"\\caption{{IGD$^{{+}}$ ablation results on {family}{name_range} with 10 and 20 objectives "
        "($N=100$; configured $FE=300$).}",
        f"\\label{{{label}}}",
        "\\footnotesize",
        "\\setlength{\\tabcolsep}{3pt}",
        "\\renewcommand{\\arraystretch}{1.08}",
        "\\begin{tabular*}{\\textwidth}{@{\\extracolsep{\\fill}}lcccccc@{}}",
        "\\toprule",
        "Problem & $M$ & $D$ & REMO & w/o CDIS & w/o PAQC & Full \\\\",
        "\\midrule",
    ]
    counts = {name: Counter() for name in SOURCE_COLUMNS if name != "REMO"}
    for i in FAMILIES[family]:
        if i > 1:
            lines.append("\\addlinespace[2pt]")
        problem = f"{family}{i}"
        for m in SOURCES:
            entry = records[(problem, m)]
            cells = entry["cells"]
            minimum = min(Decimal(cells[name][0]) for name in TABLE_COLUMNS)
            parts = [problem if m == 10 else "", str(m), str(entry["D"])]
            for name in TABLE_COLUMNS:
                cell = cells[name]
                parts.append(tex_cell(cell, Decimal(cell[0]) == minimum))
                if cell[2] is not None:
                    counts[name][cell[2]] += 1
            lines.append(" & ".join(parts) + " \\\\")
    summary = ["\\multicolumn{2}{c}{$+/-/=$}", "--", "--"]
    summary.extend(
        f"${'/'.join(str(counts[name][symbol]) for symbol in '+-=')}$"
        for name in TABLE_COLUMNS[1:]
    )
    lines.extend([
        "\\midrule",
        " & ".join(summary) + " \\\\",
        "\\bottomrule",
        "\\end{tabular*}",
        "\\par\\smallskip",
        "\\begin{minipage}{\\textwidth}\\footnotesize",
        "Entries give mean (standard deviation); lower IGD$^{+}$ is better. "
        "Light gray cells mark the lowest mean in each row, including displayed ties. "
        "The supplied workbooks report $+$, $-$, and $=$ relative to REMO "
        "(better, worse, and no detected difference, respectively). Their symbols "
        "do not compare Full with either control. Full denotes PACDIS; w/o PAQC "
        "replaces its grouping, whereas w/o CDIS fixes selection to the ambiguity "
        "criterion. REMO uses $k=15$ for $M=10$ and $k=30$ for $M=20$. "
        "Its archived runs can exceed 300 actual evaluations.",
        "\\end{minipage}",
        "\\end{table*}",
    ])
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    records = read_sources()
    generated = (
        "% Generated from the two archived REMO-reference IGD+ workbooks in sources/.\n"
        + "\n\n".join(make_table(family, records) for family in FAMILIES)
        + "\n"
    )
    if args.check:
        assert OUTPUT.read_text(encoding="utf-8") == generated
        print("Ablation table matches both REMO-reference workbooks.")
    else:
        OUTPUT.write_text(generated, encoding="utf-8", newline="\n")
        print("Updated", OUTPUT)
    for name in TABLE_COLUMNS[1:]:
        counts = Counter(
            records[key]["cells"][name][2] for key in records
        )
        print(name, "/".join(str(counts[s]) for s in "+-="))


if __name__ == "__main__":
    main()
