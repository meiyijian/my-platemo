"""Render the IGDp ablation workbooks for the replacement w/o CDIS arm.

Reads the JSON emitted by BuildNoCDISREMOSelectionTables.m and writes one
workbook per (anchor, objective count). Styling is byte-for-byte the same as
build_nobatchdict_tables.py so the new files sit visually next to the old ones.

Existing workbooks in OUT_DIR are never overwritten: every new file carries the
_NoCDISREMOSelection suffix.
"""

import json
import os

import openpyxl
from openpyxl.styles import Alignment, Border, Font, Side
from openpyxl.utils import get_column_letter

JSON_DIR = r"D:\PlatEMO-master\PlatEMO-master\.workbuddy\nocdis_remosel_logs"
OUT_DIR = r"C:\Users\lsx\Desktop\AdaMao实验表\消融实验\nobatchdict版本"
SUFFIX = "_NoCDISREMOSelection"

THIN = Side(style="thin", color="FF000000")
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)
FONT = Font(name="Times New Roman", size=11)
FONT_BEST = Font(name="Times New Roman", size=11, color="FF3333E9")
ALIGN = Alignment(horizontal="center", vertical="center")
WIDTHS = {"A": 10.62, "B": 6.62}          # B..E keep the default width
ALG_WIDTH = 22.62                          # every algorithm column


def build_one(payload, table, out_path):
    M = payload["M"]
    problems = payload["problems"]
    Ds = payload["Ds"]
    labels = table["labels"]
    # MATLAB joins each row of cells with '|' because jsonencode flattens a
    # two-dimensional cell array column-major.
    cells = [row.split("|") for row in table["cells"]]
    counts = table["counts"]
    best = table["best"]
    nA = len(labels)
    nP = len(problems)

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "IGDp"

    header = ["Problem", "N", "M", "D", "FE"] + labels
    for c, txt in enumerate(header, start=1):
        ws.cell(row=1, column=c, value=txt)

    for p in range(nP):
        r = 2 + p
        ws.cell(row=r, column=1, value=problems[p])
        ws.cell(row=r, column=2, value=100)
        ws.cell(row=r, column=3, value=M)
        ws.cell(row=r, column=4, value=int(Ds[p]))
        ws.cell(row=r, column=5, value=300)
        for a in range(nA):
            ws.cell(row=r, column=6 + a, value=cells[p][a])
        # per-row minimum mean in blue
        ws.cell(row=r, column=6 + (best[p] - 1)).font = FONT_BEST

    last = 2 + nP                                   # 18 for 16 problems
    ws.cell(row=last, column=1, value="+/-/=")
    ws.merge_cells(start_row=last, start_column=1, end_row=last, end_column=5)
    for a in range(nA):
        txt = counts[a] if a < len(counts) else ""
        ws.cell(row=last, column=6 + a, value=txt)

    ncol = 5 + nA
    for r in range(1, last + 1):
        ws.row_dimensions[r].height = 15.0
        for c in range(1, ncol + 1):
            cell = ws.cell(row=r, column=c)
            cell.border = BORDER
            cell.alignment = ALIGN
            if cell.font.color is None or cell.font.color.rgb != "FF3333E9":
                cell.font = FONT
    for col, w in WIDTHS.items():
        ws.column_dimensions[col].width = w
    for a in range(nA):
        ws.column_dimensions[get_column_letter(6 + a)].width = ALG_WIDTH

    wb.save(out_path)
    return {
        "file": out_path,
        "anchor": table["anchor"],
        "labels": labels,
        "counts": counts,
        "rows": nP,
    }


def verify_one(path, info):
    """Re-open the saved workbook and check its shape against the payload."""
    wb = openpyxl.load_workbook(path)
    ws = wb.active
    hdr = [ws.cell(row=1, column=c).value for c in range(1, 6 + len(info["labels"]))]
    assert hdr[0] == "Problem" and hdr[5:] == list(info["labels"]), hdr
    last = 2 + info["rows"] - 1 + 1
    cnt = [ws.cell(row=last, column=6 + a).value for a in range(len(info["counts"]) + 1)]
    assert cnt[:-1] == list(info["counts"]), cnt
    blue = sum(
        1
        for r in range(2, 2 + info["rows"])
        for c in range(6, 6 + len(info["labels"]))
        if ws.cell(row=r, column=c).font.color is not None
        and ws.cell(row=r, column=c).font.color.rgb == "FF3333E9"
    )
    assert blue == info["rows"], "blue cells %d != %d rows" % (blue, info["rows"])
    return hdr, cnt, blue


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    summary = []
    for M, cn in ((10, "十目标"), (20, "二十目标")):
        jf = os.path.join(JSON_DIR, "nocdis_remosel_tables_M%d.json" % M)
        if not os.path.isfile(jf):
            print("MISSING %s" % jf)
            continue
        with open(jf, "r", encoding="utf-8") as fh:
            payload = json.load(fh)
        for table in payload["tables"]:
            anchor_is_remo = table["anchor"].lower().startswith("remo")
            tag = "以RMEO为基准" if anchor_is_remo else "以full为基准"
            name = "nobatchdict%s%sIGDp%s.xlsx" % (tag, cn, SUFFIX)
            info = build_one(payload, table, os.path.join(OUT_DIR, name))
            hdr, cnt, blue = verify_one(info["file"], info)
            summary.append(info)
            print("wrote %s" % info["file"])
            print("   labels : %s" % " | ".join(info["labels"]))
            print("   counts : %s" % " | ".join(info["counts"]))
            print("   QA     : header ok, blue min-cells=%d (= rows)" % blue)
    print("\nWROTE %d files" % len(summary))


if __name__ == "__main__":
    main()
