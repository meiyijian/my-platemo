"""Extract supplied IGD exports and build manuscript tables without editing Excel.

Usage: python build_tables.py --source-dir <directory containing the three xlsx>
       python build_tables.py  # rebuild from the committed, cell-addressed snapshot
Statistical symbols are supplied results, never inferred from means/stds.
"""
import argparse
import csv
import hashlib
import json
import re
from collections import Counter
from decimal import Decimal
from pathlib import Path

HERE = Path(__file__).resolve().parent
# Source set as of 2026-09-23: the FE500 / requested runs 1-20
# seven-algorithm export. Some baseline cells have fewer stored runs.
# Previous source set (git history, commit e8387bf and earlier): the FE300 /
# runs 1-20 export lambdat030nobatch{十,十五,二十}目标IGDp.xlsx, whose baseline
# columns were REMO / PIEA / CSEA / PCSAEA_N100 / KRVEA_100 / MCEAD.
OURS = "PACDIS"
FILES = {10: "nobatchdict以PACDIS为基准十目标IGDp.xlsx",
         15: "nobatchdict以PACDIS为基准十五目标IGDp.xlsx",
         20: "nobatchdict以PACDIS为基准二十目标IGDp.xlsx"}
SHEET = "IGDp"
ORDER = ["REMO", "SSDE", "PC-SAEA", "SAMOEA-TL2M", "CSEA", "HES-EA", "PACDIS"]
# The six baselines are already labelled with their paper names in these
# workbooks; the legacy suffixed spellings are kept so the same script still
# reads the older exports. PACDIS is the proposed method (the NoBatchDist
# variant); any column absent from this map is ignored.
ALIASES = {"REMO": "REMO", "SSDE": "SSDE",
           "PC-SAEA": "PC-SAEA", "PCSAEA": "PC-SAEA", "PCSAEA_N100": "PC-SAEA",
           "SAMOEA-TL2M": "SAMOEA-TL2M", "SAMOEATL2M": "SAMOEA-TL2M",
           "CSEA": "CSEA", "HES-EA": "HES-EA", "HES_EA": "HES-EA",
           "PIEA": "PIEA", "K-RVEA": "K-RVEA", "KRVEA": "K-RVEA",
           "KRVEA_100": "K-RVEA", "MCEA/D": "MCEA/D", "MCEAD": "MCEA/D",
           OURS: OURS}
PROBLEMS = [f"DTLZ{i}" for i in range(1, 8)] + [f"WFG{i}" for i in range(1, 10)]
CELL = re.compile(r"^\s*([\d.]+e[+-]\d+)\s*\(([\d.]+e[+-]\d+)\)\s*([+=-])?\s*$", re.I)


def extract(source):
    from openpyxl import load_workbook
    records, manifest = [], {"excluded_algorithm": None,
                             "excluded_algorithm_note":
                                 "The FE500 workbooks carry only the seven table columns; "
                                 "earlier exports additionally carried the Lambdat030 column.",
                             "sources": []}
    for m in [10, 15, 20]:
        path = source / FILES[m]
        content = path.read_bytes()
        wb = load_workbook(path, data_only=True)
        ws = wb[SHEET]
        headers = {str(c.value): c.column for c in ws[1] if c.value is not None}
        assert set(ALIASES[h] for h in headers if h in ALIASES) == set(ORDER)
        info = {"filename": path.name, "source_path": str(path.resolve()), "sha256": hashlib.sha256(content).hexdigest(),
                "sheet": SHEET, "M": m, "reference_algorithm": OURS,
                "headers": list(headers), "metadata": [], "exported_summary": {}}
        for row in range(2, 18):
            problem = ws.cell(row, headers["Problem"]).value
            assert problem == PROBLEMS[row - 2]
            assert ws.cell(row, headers["M"]).value == m
            meta = {k: ws.cell(row, headers[k]).value if k in headers else None
                    for k in ["N", "M", "D", "FE"]}
            info["metadata"].append({"problem": problem, **meta})
            for header, col in headers.items():
                if header not in ALIASES:
                    continue
                cell = ws.cell(row, col)
                match = CELL.fullmatch(str(cell.value))
                assert match, (path.name, cell.coordinate, cell.value)
                mean, std, symbol = match.groups()
                assert (symbol is None) == (header == OURS), (path.name, cell.coordinate)
                records.append({"M": m, "problem": problem, "algorithm": ALIASES[header],
                                "source_algorithm": header, "mean": mean, "std": std,
                                "symbol": symbol or "", "source_file": path.name,
                                "source_sheet": SHEET, "source_cell": cell.coordinate,
                                "raw": cell.value})
        for header, col in headers.items():
            if header in ALIASES and header != OURS:
                actual = Counter(r["symbol"] for r in records
                                 if r["M"] == m and r["source_algorithm"] == header)
                original = str(ws.cell(18, col).value)
                assert original == f"{actual['+']}/{actual['-']}/{actual['=']}", (m, header)
                info["exported_summary"][header] = original
        manifest["sources"].append(info)
        wb.close()
        assert path.read_bytes() == content, "Source workbook changed during extraction"
    with (HERE / "igd_snapshot.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=records[0].keys())
        writer.writeheader()
        writer.writerows(records)
    (HERE / "source_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path)
    args = parser.parse_args()
    if args.source_dir:
        extract(args.source_dir)
    with (HERE / "igd_snapshot.csv").open(encoding="utf-8-sig", newline="") as f:
        records = list(csv.DictReader(f))
    assert len(records) == 3 * 16 * 7
    summary = {"symbol_order": "+/-/=", "by_objectives": {}, "by_suite": {}}
    for m in [10, 15, 20]:
        data = [r for r in records if int(r["M"]) == m]
        lookup = {(r["problem"], r["algorithm"]): r for r in data}
        assert len(lookup) == 112
        totals = {}
        best = Counter()
        mean_comparisons = {}
        for algorithm in ORDER[:-1]:
            c = Counter(lookup[p, algorithm]["symbol"] for p in PROBLEMS)
            totals[algorithm] = [c["+"], c["-"], c["="]]
            mean_comparisons[algorithm] = sum(Decimal(lookup[p, "PACDIS"]["mean"]) < Decimal(lookup[p, algorithm]["mean"]) for p in PROBLEMS)
        for p in PROBLEMS:
            lowest = min(Decimal(lookup[p, a]["mean"]) for a in ORDER)
            best.update(a for a in ORDER if Decimal(lookup[p, a]["mean"]) == lowest)
        assert {r["algorithm"] for r in data} == set(ORDER)
        assert {r["source_algorithm"] for r in data if r["algorithm"] == "PC-SAEA"} <= {"PC-SAEA", "PCSAEA", "PCSAEA_N100"}
        summary["by_objectives"][str(m)] = {"baseline_plus_minus_equal": totals,
            "best_mean_counts": dict(best), "lower_mean_counts": mean_comparisons,
            "best_mean_problems_PACDIS": [p for p in PROBLEMS if Decimal(lookup[p, "PACDIS"]["mean"]) == min(Decimal(lookup[p, a]["mean"]) for a in ORDER)]}
    lookup = {(r["problem"], int(r["M"]), r["algorithm"]): r for r in records}
    for suite, problems in [("DTLZ", PROBLEMS[:7]), ("WFG", PROBLEMS[7:])]:
        totals = {}
        for algorithm in ORDER[:-1]:
            counts = Counter(lookup[p, m, algorithm]["symbol"] for p in problems for m in [10, 15, 20])
            totals[algorithm] = [counts["+"], counts["-"], counts["="]]
        lines = ["% Generated from igd_snapshot.csv by build_tables.py.",
                 r"\begin{table*}[tp]", r"\centering",
                 rf"\caption{{Comparison of IGD$+$ values on {suite}1--{len(problems)}.}}",
                 rf"\label{{tab:exp:{suite.lower()}}}", r"\footnotesize",
                 r"\setlength{\tabcolsep}{4pt}", r"\renewcommand{\arraystretch}{1.08}",
                 r"\begin{tabular}{@{}>{\centering\arraybackslash}m{32pt}>{\centering\arraybackslash}m{14pt}*{7}{>{\centering\arraybackslash}m{\dimexpr(\textwidth-110pt)/7\relax}}@{}}",
                 r"\toprule", "Problem & $M$ & " + " & ".join(ORDER) + r" \\", r"\midrule"]
        for i, p in enumerate(problems):
            if i:
                lines.append(r"\midrule")
            for j, m in enumerate([10, 15, 20]):
                lowest = min(Decimal(lookup[p, m, a]["mean"]) for a in ORDER)
                cells = []
                for a in ORDER:
                    r = lookup[p, m, a]
                    sign = (r"\," + "$" + r["symbol"] + "$") if r["symbol"] else ""
                    line1, line2 = r["mean"], "(" + r["std"] + ")" + sign
                    prefix = ""
                    if Decimal(r["mean"]) == lowest:
                        prefix = ""
                        line1 = r"\textbf{" + line1 + "}"
                        line2 = r"\textbf{" + line2 + "}"
                    cells.append(prefix + r"\shortstack{" + line1 + r"\\" + line2 + "}")
                group = p if j == 1 else ""
                lines.append(group + " & " + str(m) + " & " + " & ".join(cells) + r" \\")
        lines += [r"\midrule", r"\multicolumn{2}{c}{$+/-/=$} & " + " & ".join("/".join(map(str, totals[a])) for a in ORDER[:-1]) + r" & --- \\",
                  r"\bottomrule", r"\end{tabular}", r"\par\smallskip",
                  r"\begin{minipage}{\textwidth}\footnotesize",
                  r"Each entry shows the mean above the standard deviation in parentheses. Bold cells have the lowest mean in their row. Symbols $+$, $-$ and $=$ indicate that the baseline is reported as better than, worse than or not significantly different from PACDIS, respectively. The last row totals these symbols in the stated order."]
        lines += [r"\end{minipage}", r"\end{table*}", ""]
        (HERE / f"table_{suite.lower()}.tex").write_text("\n".join(lines), encoding="utf-8")
        summary["by_suite"][suite] = {"baseline_plus_minus_equal": totals}
    (HERE / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
