"""Render a method-level preview of the PACDIS framework figure.

This script writes only to figures/previews; it does not replace Fig. 1 in the
manuscript. Run from the figures directory with the local figure requirements.
"""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch, Polygon
import pymupdf


OUT = Path(__file__).resolve().parent / "previews"
INK = "#28313D"
BLUE = "#E8EDF8"
PAQC = "#D9E5F6"
CDIS = "#F6E8D9"
DECISION = "#FFF7D6"


def draw_framework():
    with plt.rc_context(
        {
            "font.family": "serif",
            "font.serif": ["Times New Roman", "DejaVu Serif"],
            "font.size": 9,
            "mathtext.fontset": "stix",
            "text.color": INK,
            "pdf.fonttype": 42,
            "svg.fonttype": "none",
        }
    ):
        fig = plt.figure(figsize=(180 / 25.4, 136 / 25.4))
        ax = fig.add_axes([0, 0, 1, 1], xlim=(0, 180), ylim=(0, 136))
        ax.axis("off")
        nodes = []

        def box(x, y, w, h, title, detail=None, fill=BLUE, bold=False):
            patch = FancyBboxPatch(
                (x - w / 2, y - h / 2),
                w,
                h,
                boxstyle="round,pad=0,rounding_size=0.8",
                facecolor=fill,
                edgecolor=INK,
                linewidth=0.72,
                zorder=2,
            )
            ax.add_patch(patch)
            if detail is None:
                label = ax.text(
                    x,
                    y,
                    title,
                    ha="center",
                    va="center",
                    fontsize=8.9,
                    fontweight="bold" if bold else "normal",
                    zorder=3,
                )
                nodes.append((patch, label))
            else:
                top = ax.text(
                    x,
                    y + 2.3,
                    title,
                    ha="center",
                    va="center",
                    fontsize=8.5,
                    fontweight="bold" if bold else "normal",
                    zorder=3,
                )
                bottom = ax.text(
                    x,
                    y - 2.3,
                    detail,
                    ha="center",
                    va="center",
                    fontsize=7.8,
                    zorder=3,
                )
                nodes.extend([(patch, top), (patch, bottom)])

        def diamond(x, y, w, h, title):
            patch = Polygon(
                [(x, y + h / 2), (x + w / 2, y), (x, y - h / 2), (x - w / 2, y)],
                closed=True,
                facecolor=DECISION,
                edgecolor=INK,
                linewidth=0.72,
                zorder=2,
            )
            ax.add_patch(patch)
            label = ax.text(x, y, title, ha="center", va="center", fontsize=8.3, zorder=3)
            nodes.append((patch, label))

        def line(points, arrow=True, dashed=False):
            for start, end in zip(points[:-2], points[1:-1]):
                ax.plot(
                    [start[0], end[0]],
                    [start[1], end[1]],
                    color=INK,
                    lw=0.76,
                    ls=(0, (2, 2)) if dashed else "-",
                    zorder=1,
                )
            if arrow:
                ax.add_patch(
                    FancyArrowPatch(
                        points[-2],
                        points[-1],
                        arrowstyle="-|>",
                        mutation_scale=7,
                        lw=0.76,
                        color=INK,
                        shrinkA=0,
                        shrinkB=0.5,
                        zorder=1,
                    )
                )
            else:
                start, end = points[-2:]
                ax.plot([start[0], end[0]], [start[1], end[1]], color=INK, lw=0.76, zorder=1)

        ax.text(32, 133, "PACDIS evaluation loop", ha="center", va="center", fontsize=9.5, fontweight="bold")
        box(32, 120, 52, 10, "Evaluate initial population")
        diamond(32, 103, 42, 14, "Budget remaining?")
        box(
            32,
            84,
            53,
            13,
            "PAQC: form training groups",
            "PBI + representative signals",
            fill=PAQC,
            bold=True,
        )
        box(32, 66, 52, 10, "Train relation model")
        box(32, 50, 52, 10, "Train indicator surrogate")
        box(32, 34, 52, 10, "CDIS: select candidates", fill=CDIS, bold=True)
        box(32, 19, 52, 13, "Evaluate candidates", "Update archive")
        box(32, 5.5, 52, 8, "Environmental selection")
        box(85, 131, 38, 9, "Final archive")

        for upper, lower in [
            (115, 110),
            (96, 90.5),
            (77.5, 71),
            (61, 55),
            (45, 39),
            (29, 25.5),
            (12.5, 9.5),
        ]:
            line([(32, upper), (32, lower)])
        ax.text(38, 93, "Yes", ha="center", va="center", fontsize=8)
        line([(6, 5.5), (1.5, 5.5), (1.5, 103), (11, 103)])
        line([(53, 103), (65, 103), (65, 131), (66, 131)])
        ax.text(58, 106, "No", ha="center", va="center", fontsize=8)

        ax.add_patch(
            FancyBboxPatch(
                (76, 3.5),
                102,
                114.5,
                boxstyle="round,pad=0,rounding_size=2",
                facecolor="#FCFCFD",
                edgecolor="#7A8391",
                linestyle=(0, (2, 2)),
                linewidth=0.75,
                zorder=0,
            )
        )
        ax.plot([58, 76], [34, 34], color="#7A8391", lw=0.8, ls=(0, (2, 2)))
        ax.text(
            127,
            112,
            "CDIS: candidate search and infill selection",
            ha="center",
            va="center",
            fontsize=9.4,
            fontweight="bold",
        )
        box(127, 98, 82, 10, "Choose an infill criterion", fill=CDIS)
        box(127, 79, 82, 11, "Relation-guided offspring generation", "Population and representatives")
        box(127, 60, 82, 10, "Screen candidates by relation quality")
        box(101, 40, 42, 13, "Indicator-based", "reranking")
        box(153, 40, 43, 13, "Ambiguity-rewarded", "ranking")
        box(127, 16, 82, 10, "Candidates for expensive evaluation", fill=CDIS, bold=True)

        line([(127, 93), (127, 84.5)])
        line([(127, 73.5), (127, 65)])
        line([(127, 55), (127, 52), (101, 52), (101, 46.5)])
        line([(127, 52), (153, 52), (153, 46.5)])
        line([(101, 33.5), (101, 27), (127, 27)], arrow=False)
        line([(153, 33.5), (153, 27), (127, 27)], arrow=False)
        line([(127, 27), (127, 21)])

        fig.canvas.draw()
        renderer = fig.canvas.get_renderer()
        for patch, label in nodes:
            extent = label.get_window_extent(renderer).expanded(1.012, 1.03)
            path = patch.get_path().transformed(patch.get_transform())
            corners = [
                (extent.x0, extent.y0),
                (extent.x0, extent.y1),
                (extent.x1, extent.y0),
                (extent.x1, extent.y1),
            ]
            if not all(path.contains_point(corner) for corner in corners):
                raise ValueError(f"Text does not fit node: {label.get_text()}")
        return fig


def main():
    OUT.mkdir(exist_ok=True)
    fig = draw_framework()
    for suffix in ("pdf", "svg", "png"):
        fig.savefig(OUT / f"fig_framework_method_preview.{suffix}", dpi=600, facecolor="white")
    plt.close(fig)
    with pymupdf.open(OUT / "fig_framework_method_preview.pdf") as document:
        page = document[0]
        if page.get_images():
            raise ValueError("The PDF contains a raster image")
        spans = [
            span
            for block in page.get_text("dict")["blocks"]
            if "lines" in block
            for item in block["lines"]
            for span in item["spans"]
            if span["text"].strip()
        ]
        if min(span["size"] for span in spans) < 5:
            raise ValueError("Figure text is smaller than 5 pt")
    print(OUT / "fig_framework_method_preview.png")


if __name__ == "__main__":
    main()
