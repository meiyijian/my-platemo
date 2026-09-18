# -*- coding: utf-8 -*-
"""Build the 20-objective IGDp table in the format of lambdat030nobatch十目标IGDp.xlsx.

Mirrors build_15_tables.py: reads the formatted cell texts from BuildTableM20Data.m
and reproduces the reference conventions — Times New Roman 11, centred, thin
borders, widths/row-height copied from the reference sheet, the "+/-/=" label
merged over A:C of the last row, and the per-row minimum in blue (#3333E9).
"""

import csv
import os

import openpyxl
from openpyxl.styles import Alignment, Border, Font, Side
from openpyxl.utils import get_column_letter

REF_FILE = r"C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本\lambdat030nobatch十目标IGDp.xlsx"
OUT_DIR = r"C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本"
CSV_PATH = os.path.join(OUT_DIR, "table20_IGDp.csv")
OUT_NAME = "lambdat030nobatch二十目标IGDp.xlsx"
SHEET = "IGDp"

ALGS = ["REMO", "PIEA", "MCEAD", "CSEA", "PCSAEA_N100", "KRVEA_100",
        "REMO_UniformMix_Pruned_Weighted_Lambdat030",
        "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist"]
LABELS = ["REMO", "PIEA", "MCEAD", "CSEA", "PCSAEA_N100", "KRVEA_100",
          "Lambdat030", "NoBatchDist"]
BLUE = "3333E9"
PROBN = 16
SUMMARY_ROW = PROBN + 2
FIRST_ALG_COL = 4


def reference_format():
    wb = openpyxl.load_workbook(REF_FILE)
    ws = wb[wb.sheetnames[0]]
    widths = {k: v.width for k, v in ws.column_dimensions.items() if v.width}
    height = ws.row_dimensions[1].height or 20
    f = ws["A1"].font
    return widths, height, (f.name or "Times New Roman", f.size or 11)


def build():
    with open(CSV_PATH, encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    if len(rows) != PROBN:
        raise SystemExit(f"expected {PROBN} rows in {CSV_PATH}, found {len(rows)}")

    widths, height, (fname, fsize) = reference_format()
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = SHEET

    thin = Side(style="thin")
    border = Border(left=thin, right=thin, top=thin, bottom=thin)
    centre = Alignment(horizontal="center", vertical="center")

    def style(cell, blue=False):
        cell.font = Font(name=fname, size=fsize, color=(BLUE if blue else "000000"))
        cell.alignment = centre
        cell.border = border

    for j, text in enumerate(["Problem", "M", "D"] + ALGS, start=1):
        style(ws.cell(row=1, column=j, value=text))

    for i, r in enumerate(rows):
        excel_row = i + 2
        style(ws.cell(row=excel_row, column=1, value=r["Problem"]))
        style(ws.cell(row=excel_row, column=2, value=int(float(r["M"]))))
        style(ws.cell(row=excel_row, column=3, value=int(float(r["D"]))))
        best = r["BestAlg"].strip()
        for k, alg in enumerate(ALGS):
            style(ws.cell(row=excel_row, column=FIRST_ALG_COL + k, value=r[alg]),
                  blue=(LABELS[k] == best))

    style(ws.cell(row=SUMMARY_ROW, column=1, value="+/-/="))
    for j in (2, 3):
        style(ws.cell(row=SUMMARY_ROW, column=j, value=None))
    ws.merge_cells(start_row=SUMMARY_ROW, start_column=1,
                   end_row=SUMMARY_ROW, end_column=3)
    for k, lab in enumerate(LABELS[:-1]):
        style(ws.cell(row=SUMMARY_ROW, column=FIRST_ALG_COL + k,
                      value=rows[0][f"cnt_{lab}"]))
    style(ws.cell(row=SUMMARY_ROW, column=FIRST_ALG_COL + len(ALGS) - 1, value=None))

    alg_cols = [get_column_letter(FIRST_ALG_COL + k) for k in range(len(ALGS))]
    for key, width in widths.items():
        if key in "ABC" or key in alg_cols:
            ws.column_dimensions[key].width = width
    for excel_row in range(1, SUMMARY_ROW + 1):
        ws.row_dimensions[excel_row].height = height

    out_path = os.path.join(OUT_DIR, OUT_NAME)
    wb.save(out_path)
    print(f"wrote {out_path} (sheet '{SHEET}', {len(rows)} problems, {len(ALGS)} algorithms)")


if __name__ == "__main__":
    build()
    print("XLSX BUILD DONE")
