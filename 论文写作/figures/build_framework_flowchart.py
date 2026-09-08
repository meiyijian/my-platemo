"""Draw Fig. 1 from the manuscript method, with compact control-flow nodes.

Rebuild only this figure:
uv run --with-requirements requirements-figures.txt python build_framework_flowchart.py
Coordinates are in mm; PDF/SVG are vector artwork, PNG is exported at 600 dpi.
"""
from pathlib import Path
import hashlib
import json

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Polygon
import pymupdf

OUT = Path(__file__).resolve().parent
INK = '#28313D'
BLUE = '#E8EDF8'
DECISION = '#FFF7D6'


def draw_framework():
    with plt.rc_context({
        'font.family': 'serif', 'font.serif': ['Times New Roman', 'DejaVu Serif'],
        'font.size': 9, 'mathtext.fontset': 'stix', 'text.color': INK,
        'pdf.fonttype': 42, 'svg.fonttype': 'none',
    }):
        fig = plt.figure(figsize=(180/25.4, 157/25.4))
        ax = fig.add_axes([0, 0, 1, 1], xlim=(0, 180), ylim=(0, 157))
        ax.axis('off')
        nodes = []

        def box(x, y, w, h, label, fill=BLUE, bold=False, terminal=False, fs=9):
            patch = FancyBboxPatch((x-w/2, y-h/2), w, h,
                boxstyle=f'round,pad=0,rounding_size={h/2 if terminal else 0.8}',
                facecolor=fill, edgecolor=INK, linewidth=.7, zorder=2)
            ax.add_patch(patch)
            txt = ax.text(x, y, label, ha='center', va='center', fontsize=fs,
                          fontweight='bold' if bold else 'normal', linespacing=1.15, zorder=3)
            nodes.append((patch, txt))

        def diamond(x, y, w, h, label, fs=9):
            patch = Polygon([(x, y+h/2), (x+w/2, y), (x, y-h/2), (x-w/2, y)],
                            closed=True, facecolor=DECISION, edgecolor=INK, linewidth=.7, zorder=2)
            ax.add_patch(patch)
            txt = ax.text(x, y, label, ha='center', va='center', fontsize=fs, zorder=3)
            nodes.append((patch, txt))

        def arrow(points):
            for a, b in zip(points[:-2], points[1:-1]):
                ax.plot([a[0], b[0]], [a[1], b[1]], color=INK, lw=.75, zorder=1)
            ax.add_patch(FancyArrowPatch(points[-2], points[-1], arrowstyle='-|>',
                mutation_scale=7, lw=.75, color=INK, shrinkA=0, shrinkB=.5, zorder=1))

        def label(x, y, text):
            ax.text(x, y, text, ha='center', va='center', fontsize=8.5,
                    bbox=dict(facecolor='white', edgecolor='none', pad=.15), zorder=4)

        # Main expensive-evaluation loop. The initial budget test also handles
        # N_init == FE_max, as specified by Algorithm 1.
        box(32, 151, 21, 6, 'Start', fill='#F0F0F0', terminal=True)
        box(32, 138, 50, 12, 'Latin hypercube sampling\nEvaluate and initialise archive')
        diamond(32, 120, 38, 16, r'$FE<FE_{\max}$?')
        box(32, 100, 50, 12, 'PAQC: quality grouping\nPBI score + binary label',
            fill='#D9E5F6', fs=8.6)
        box(32, 82, 50, 11, 'Build relation pairs\nTrain relation model; obtain $e_r$')
        box(32, 64, 50, 11, 'Compute indicator fitness\nTrain indicator surrogate')
        box(32, 46, 50, 11, 'CDIS: select an infill batch', fill='#F6E8D9', bold=True, fs=8.7)
        box(32, 28, 50, 11, 'Evaluate selected candidates\nUpdate archive and $FE$')
        box(32, 10, 50, 11, 'Environmental selection\nUpdate current population')
        for top, bottom in [(148, 144), (132, 128), (112, 106), (94, 87.5),
                            (76.5, 69.5), (58.5, 51.5), (40.5, 33.5), (22.5, 15.5)]:
            arrow([(32, top), (32, bottom)])
        label(36, 109, 'Yes')
        arrow([(7, 10), (2.5, 10), (2.5, 120), (13, 120)])
        box(83, 138, 34, 10, 'Output evaluated\narchive', fill=BLUE)
        box(120, 138, 20, 6, 'End', fill='#F0F0F0', terminal=True)
        arrow([(51, 120), (62, 120), (62, 138), (66, 138)])
        label(57, 122.6, 'No')
        arrow([(100, 138), (110, 138)])

        # Dotted enclosure and connector indicate an expansion of the CDIS
        # node, not a second independent execution path.
        ax.add_patch(FancyBboxPatch((77, 1.5), 101, 126,
            boxstyle='round,pad=0,rounding_size=2', facecolor='#FCFCFD',
            edgecolor='#7A8391', linestyle=(0, (2, 2)), linewidth=.75, zorder=0))
        ax.plot([57, 77], [46, 46], color='#7A8391', lw=.8, ls=(0, (2, 2)))
        ax.text(127.5, 123, 'CDIS: candidate search and infill selection',
                ha='center', va='center', fontsize=9.4, fontweight='bold')
        box(128, 110, 87, 11, r'Draw mode $m$ ($p_{\mathrm{mix}}=0.5$)'+'\nIndicator mode only if its surrogate is available', fs=8.7)
        box(128, 94, 71, 16, 'Generate offspring using representatives\nRank and retain parents by relation score\nAccumulate candidates', fs=8.7)
        diamond(128, 76, 47, 14, r'$c\geq g_{\max}$?')
        box(128, 61, 65, 8, 'Deduplicate the candidate pool')
        diamond(128, 45, 35, 14, r'$m=\mathrm{ind}$?')
        box(102, 27, 43, 15, 'Relation-based filtering\nIndicator reranking\nQuantile filter; top up', fs=8.4)
        box(153, 27, 43, 15, 'Relation + ambiguity\nQuantile filter; top up\nDiverse greedy selection', fs=8.4)
        box(128, 8.5, 87, 10, 'Bound the evaluation batch\n'+
            r'$|\mathcal{S}|\leq\min(n_{\max},\,FE_{\max}-FE)$', fill='#F6E8D9', fs=8.4)
        arrow([(128, 104.5), (128, 102)])
        arrow([(128, 86), (128, 83)])
        arrow([(151.5, 76), (173, 76), (173, 94), (163.5, 94)])
        label(163, 78.5, 'No')
        arrow([(128, 69), (128, 65)])
        label(132, 67, 'Yes')
        arrow([(128, 57), (128, 52)])
        arrow([(110.5, 45), (102, 45), (102, 34.5)])
        arrow([(145.5, 45), (153, 45), (153, 34.5)])
        label(102, 48, 'Yes')
        label(153, 48, 'No')
        arrow([(102, 19.5), (102, 16.5), (128, 16.5), (128, 13.5)])
        arrow([(153, 19.5), (153, 16.5), (128, 16.5)])

        # Check actual rendered text bounds against process and decision nodes.
        fig.canvas.draw()
        renderer = fig.canvas.get_renderer()
        for patch, txt in nodes:
            extent = txt.get_window_extent(renderer).expanded(1.015, 1.035)
            path = patch.get_path().transformed(patch.get_transform())
            corners = [(extent.x0, extent.y0), (extent.x0, extent.y1),
                       (extent.x1, extent.y0), (extent.x1, extent.y1)]
            if not all(path.contains_point(p) for p in corners):
                raise ValueError(f'Text does not fit node: {txt.get_text()}')
        return fig


def main():
    fig = draw_framework()
    with plt.rc_context({'pdf.fonttype': 42, 'svg.fonttype': 'none'}):
        for suffix in ('pdf', 'svg', 'png'):
            fig.savefig(OUT / f'fig_framework.{suffix}', dpi=600, facecolor='white')
    svg_path = OUT/'fig_framework.svg'
    svg_path.write_text('\n'.join(line.rstrip() for line in svg_path.read_text(encoding='utf-8').splitlines())+'\n', encoding='utf-8')
    plt.close(fig)
    with pymupdf.open(OUT / 'fig_framework.pdf') as doc:
        page = doc[0]
        spans = [s for b in page.get_text('dict')['blocks'] if 'lines' in b
                 for line in b['lines'] for s in line['spans'] if s['text'].strip()]
        min_font = min(s['size'] for s in spans)
        assert min_font >= 5, min_font
        page.get_pixmap(matrix=pymupdf.Matrix(2, 2), alpha=False).save(OUT/'qa/fig_framework_render.png')
        metadata = {
            'source': '../HPDC-MaOEA.tex, Section 3 and Algorithms 1 and 3',
            'source_sha256': hashlib.sha256((OUT.parent/'HPDC-MaOEA.tex').read_bytes()).hexdigest(),
            'width_mm': 180, 'height_mm': 157, 'png_dpi': 600,
            'minimum_pdf_glyph_pt': min_font, 'embedded_raster_count': len(page.get_images()),
            'semantics': 'Method-level flow; c counts generated candidates, not generations.',
            'simplifications': 'Empty-pool safeguards and detailed score formulas remain in the method. Mode is drawn before candidate search. Quantile filtering includes retained-set completion before batch selection.',
            'alt_text': 'PACDIS starts with an evaluated Latin hypercube design, checks the evaluation budget, constructs PAQC groups, trains relation and indicator models, runs CDIS, evaluates the selected batch, and updates the population from the archive. CDIS draws one mode, loops over relation-guided candidate generation, and branches into indicator or exploration selection before applying the batch bound.',
        }
    (OUT/'qa/fig_framework_flowchart.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    manifest_path = OUT/'manifest.json'
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
        for entry in manifest['figures']:
            if entry['name'] == 'fig_framework':
                entry.update(width_mm=180, height_mm=157,
                    minimum_pdf_glyph_pt=round(min_font, 2), pdf_text_spans=len(spans),
                    claim='PACDIS evaluation loop and CDIS control flow.',
                    archetype='method-level flowchart',
                    notes=metadata['simplifications'], text_outside_canvas=[])
        manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    print(json.dumps(metadata, indent=2))


if __name__ == '__main__':
    main()
