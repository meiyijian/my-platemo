# -*- coding: utf-8 -*-
"""Insert one extra baseline column into a copy of a main-table workbook.

The copy keeps every existing cell, style and the merged A:C of the summary row;
only a new last column is appended, carrying the header, the sixteen cell texts
and the +/-/= totals produced by BuildSAMOEAColumn.m.
"""
import argparse
import csv
import os
import re
from copy import copy

import openpyxl
from openpyxl.styles import Color

BASE = r"C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本"
SRC = {10: "lambdat030nobatch十目标IGDp.xlsx",
       15: "lambdat030nobatch十五目标IGDp.xlsx",
       20: "lambdat030nobatch二十目标IGDp.xlsx"}
PROBLEMS = [f"DTLZ{i}" for i in range(1, 8)] + [f"WFG{i}" for i in range(1, 10)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--m", type=int, required=True)
    ap.add_argument("--csv", required=True, help="output of BuildSAMOEAColumn.m")
    ap.add_argument("--column", default="SAMOEATL2M_N100")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()
    if args.out is None:
        stem, ext = os.path.splitext(SRC[args.m])
        args.out = os.path.join(BASE, stem + "_SAMOEA" + ext)

    with open(args.csv, encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    assert [r["Problem"] for r in rows] == PROBLEMS, [r["Problem"] for r in rows]

    src = os.path.join(BASE, SRC[args.m])
    wb = openpyxl.load_workbook(src)
    ws = wb["IGDp"]
    last = ws.max_column                      # column K of the reference files
    new = last + 1
    assert ws.cell(row=1, column=last).value.endswith("_NoBatchDist"), \
        ws.cell(row=1, column=last).value

    def style_from(src_cell, dst_cell):
        dst_cell.font = copy(src_cell.font)
        dst_cell.border = copy(src_cell.border)
        dst_cell.alignment = copy(src_cell.alignment)
        dst_cell.number_format = src_cell.number_format

    MEAN = re.compile(r"^\s*([\d.]+e[+-]\d+)")

    style_from(ws.cell(row=1, column=last), ws.cell(row=1, column=new, value=args.column))
    for i, r in enumerate(rows):
        row = i + 2
        cell = ws.cell(row=row, column=new, value=r["txt"])
        style_from(ws.cell(row=row, column=last), cell)

    # The blue mark means "lowest mean in the row", and it was computed over the
    # columns that existed before. Adding a column can move that minimum, so the
    # marking is recomputed over D..<new> for every problem row.
    black = copy(ws.cell(row=2, column=1).font.color)
    moved = []
    for row in range(2, 18):
        means = {}
        for c in range(4, new + 1):
            v = ws.cell(row=row, column=c).value
            m = MEAN.match(str(v)) if v is not None else None
            if m:
                means[c] = float(m.group(1))
        lowest = min(means.values())
        winners = [c for c, v in means.items() if v == lowest]
        for c in range(4, new + 1):
            was_blue = ws.cell(row=row, column=c).font.color is not None and \
                ws.cell(row=row, column=c).font.color.rgb == "FF3333E9"
            now_blue = c in winners
            if was_blue != now_blue:
                moved.append((PROBLEMS[row - 2], ws.cell(row=row, column=c).column_letter,
                              "blue->black" if was_blue else "black->blue"))
            font = copy(ws.cell(row=row, column=last).font)
            font.color = Color(rgb="FF3333E9") if now_blue else black
            ws.cell(row=row, column=c).font = font

    n_plus = sum(1 for r in rows if r["symbol"] == "+")
    n_minus = sum(1 for r in rows if r["symbol"] == "-")
    n_eq = sum(1 for r in rows if r["symbol"] == "=")
    assert n_plus + n_minus + n_eq == len(rows)
    totals = "%d/%d/%d" % (n_plus, n_minus, n_eq)
    cell = ws.cell(row=18, column=new, value=totals)
    style_from(ws.cell(row=18, column=last), cell)

    if ws.column_dimensions["K"].width:
        ws.column_dimensions[cell.column_letter].width = ws.column_dimensions["K"].width

    wb.save(args.out)
    print("wrote %s" % args.out)
    print("  new column %s = %s, totals %s" % (cell.column_letter, args.column, totals))
    print("  sheet dims now %s, merged %s" % (ws.dimensions,
                                              [str(x) for x in ws.merged_cells.ranges]))
    print("  blue mark changes (%d):" % len(moved))
    for problem, letter, what in moved:
        print("     %-7s %s  %s" % (problem, letter, what))
    for i, r in enumerate(rows):
        print("  %-7s %s %s" % (r["Problem"], r["txt"], r["symbol"]))


if __name__ == "__main__":
    main()
