# -*- coding: utf-8 -*-
"""Build the 15- and 20-objective IGD+ tables in the exact format of IGDp10目标.xlsx.

Reads the formatted cell texts produced by BuildIGDpTable.m and reproduces the
visual conventions of the reference workbook: Times New Roman 11, centred, thin
borders over the whole A1:J18 block, column widths and row height taken from the
reference file, the label "+/-/=" merged over A:C of the last row, and the
per-row minimum painted in blue (#3333E9). Every cell is written as text, so the
scientific notation of the reference file is preserved verbatim.
"""

import csv
import os

import openpyxl
from openpyxl.styles import Alignment, Border, Font, Side
from openpyxl.utils import get_column_letter

REF_FILE = r"C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本\IGDp10目标.xlsx"
OUT_DIR = r"C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本"
CSV_TMPL = r"C:\Users\lsx\Desktop\AdaMao实验表\IGDplus_M{M}\table_M{M}.csv"

# Column order of the reference workbook: our algorithm is the last column.
COLS = ["REMO", "PIEA", "MCEAD", "CSEA", "PCSAEA_N100", "KRVEA_100",
        "REMO_UniformMix_Pruned_Weighted_Lambdat030"]
LABELS = ["REMO", "PIEA", "MCEAD", "CSEA", "PCSAEA_N100", "KRVEA_100", "PACDIS"]
BLUE = "3333E9"
PROBN = 16
SUMMARY_ROW = PROBN + 2          # header + 16 problems -> row 18
FIRST_ALG_COL = 4                # A Problem, B M, C D, D..J algorithms


def reference_format():
    """Column widths / row height / base font taken from the reference file."""
    wb = openpyxl.load_workbook(REF_FILE)
    ws = wb["IGDp"]
    widths = {}
    for key, dim in ws.column_dimensions.items():
        if dim.width:
            widths[key] = dim.width
    height = ws.row_dimensions[1].height or 20
    f = ws["A1"].font
    return widths, height, (f.name or "Times New Roman", f.size or 11)


def build(m):
    csv_path = CSV_TMPL.format(M=m)
    with open(csv_path, encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    if len(rows) != PROBN:
        raise SystemExit(f"expected {PROBN} rows in {csv_path}, found {len(rows)}")

    widths, height, (fname, fsize) = reference_format()
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "IGDp"

    thin = Side(style="thin")
    border = Border(left=thin, right=thin, top=thin, bottom=thin)
    centre = Alignment(horizontal="center", vertical="center")

    def style(cell, blue=False):
        cell.font = Font(name=fname, size=fsize, color=(BLUE if blue else "000000"))
        cell.alignment = centre
        cell.border = border

    header = ["Problem", "M", "D"] + COLS
    for j, text in enumerate(header, start=1):
        style(ws.cell(row=1, column=j, value=text))

    for i, r in enumerate(rows):
        excel_row = i + 2
        style(ws.cell(row=excel_row, column=1, value=r["Problem"]))
        style(ws.cell(row=excel_row, column=2, value=int(float(r["M"]))))
        style(ws.cell(row=excel_row, column=3, value=int(float(r["D"]))))
        best = r["BestAlg"].strip()
        for k, alg in enumerate(COLS):
            j = FIRST_ALG_COL + k
            style(ws.cell(row=excel_row, column=j, value=r[alg]),
                  blue=(LABELS[k] == best))

    # last row: "+/-/=" merged over A:C, counters under each baseline
    style(ws.cell(row=SUMMARY_ROW, column=1, value="+/-/="))
    for j in (2, 3):
        style(ws.cell(row=SUMMARY_ROW, column=j, value=None))
    ws.merge_cells(start_row=SUMMARY_ROW, start_column=1,
                   end_row=SUMMARY_ROW, end_column=3)
    for k, lab in enumerate(LABELS[:-1]):
        style(ws.cell(row=SUMMARY_ROW, column=FIRST_ALG_COL + k,
                      value=rows[0][f"cnt_{lab}"]))
    style(ws.cell(row=SUMMARY_ROW, column=FIRST_ALG_COL + len(COLS) - 1, value=None))

    # geometry copied from the reference sheet
    for key, width in widths.items():
        if key in "ABC" or key in [get_column_letter(FIRST_ALG_COL + k)
                                   for k in range(len(COLS))]:
            ws.column_dimensions[key].width = width
    for excel_row in range(1, SUMMARY_ROW + 1):
        ws.row_dimensions[excel_row].height = height
    ws.freeze_panes = None

    out_path = os.path.join(OUT_DIR, f"IGDp{m}目标.xlsx")
    wb.save(out_path)
    print(f"M={m}: wrote {out_path}  ({len(rows)} problems, "
          f"{len(COLS)} algorithms, cols widths A={widths.get('A')} D={widths.get('D')})")


if __name__ == "__main__":
    for m in (15, 20):
        build(m)
    print("XLSX BUILD DONE")
