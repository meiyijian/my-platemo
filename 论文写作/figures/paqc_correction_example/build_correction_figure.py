"""Source-verified, bilingual PAQC correction illustration.

1. python build_correction_figure.py --prepare-only
2. matlab -batch "addpath('.../paqc_correction_example'); verify_paqc_example"
3. uv run --with-requirements requirements.txt python build_correction_figure.py

The synthetic coordinates are prescribed, not experimental observations.
MATLAB is the authoritative evaluator. This script only prepares source
snapshots, verifies their provenance, draws the result, and audits exports.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import sys

OUT = Path(__file__).resolve().parent
REPO = OUT.parents[2]
ALG = REPO / 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original/private'
UTILITY = REPO / 'PlatEMO-master/PlatEMO/Algorithms/Utility functions/UniformPoint.m'
BLUE, ORANGE, GRAY, INK = '#24658C', '#AD5F25', '#777777', '#242424'
PARAMS = {'width_mm': 180, 'height_mm': 95, 'dpi': 600}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def prepare():
    dest = OUT / 'source_snapshot'
    dest.mkdir(exist_ok=True)
    sources = []
    for source in [ALG / 'RepresentativeBasedClassification.m', UTILITY]:
        target = dest / source.name
        shutil.copyfile(source, target)
        sources.append({'source': str(source.relative_to(REPO)), 'sha256': sha(source),
                        'snapshot': str(target.relative_to(OUT)), 'snapshot_sha256': sha(target),
                        'operation': 'byte-preserved copy'})
    source = ALG / 'PBIQualityClassification.m'
    text = source.read_text(encoding='utf-8-sig')
    start = text.index('function score_v = ContinuousPBIQualityAssessment(')
    end = text.index('%% ============ 内部函数：解析可选参数', start)
    local_function = text[start:end]
    target = dest / 'ContinuousPBIQualityAssessment.m'
    target.write_text(local_function, encoding='utf-8', newline='\n')
    sources.append({'source': str(source.relative_to(REPO)), 'sha256': sha(source),
                    'snapshot': str(target.relative_to(OUT)), 'snapshot_sha256': sha(target),
                    'operation': 'exact local-function text extraction; no executable edits'})
    (OUT / 'source_provenance.json').write_text(json.dumps(sources, ensure_ascii=False, indent=2), encoding='utf-8')
    print('SOURCE_SNAPSHOT_READY')


def load_verified():
    import numpy as np
    sources = json.loads((OUT / 'source_provenance.json').read_text(encoding='utf-8'))
    for source in sources:
        assert sha(REPO / source['source']) == source['sha256'], 'Source changed: rerun MATLAB verification.'
        assert sha(OUT / source['snapshot']) == source['snapshot_sha256']
    d = json.loads((OUT / 'numerical_records.json').read_text(encoding='utf-8'))
    assert d['verification'] == 'MATLAB_SOURCE_CHECK_PASS'
    for key in ['points', 'directions', 'reference', 'idealPoint', 'directionIndex',
                'S', 'H', 'normalizedG', 'labels', 'selected', 'frontDistance']:
        d[key] = np.asarray(d[key])
    assert d['names'][0] == 'A' and d['names'][2] == 'B'
    assert not d['labels'][0] and d['selected'][0]
    assert d['labels'][2] and not d['selected'][2]
    assert set(np.flatnonzero(d['selected'])) == {0, 1}
    return d, sources


def boundary_points(delta):
    """Exact polar g=1 contour, including the production cosine adjustment."""
    import numpy as np
    angle = np.linspace(0, np.pi/2, 1200)
    c = np.cos(angle)-1e-6
    radius = 1/(c+delta*np.sqrt(1-c*c))
    return radius*np.cos(angle), radius*np.sin(angle)


def render(lang, d):
    import numpy as np
    import matplotlib as mpl
    mpl.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.font_manager import FontProperties
    from matplotlib.patches import Rectangle, ConnectionPatch
    from matplotlib.lines import Line2D

    is_cn = lang == 'cn'
    zh = FontProperties(fname='C:/Windows/Fonts/msyh.ttc')
    en = FontProperties(fname='C:/Windows/Fonts/arial.ttf')
    font = zh if is_cn else en
    style = {'font.family': 'Arial', 'font.size': 8.2, 'text.color': INK,
             'axes.labelcolor': INK, 'axes.edgecolor': '#666666',
             'xtick.color': INK, 'ytick.color': INK,
             'axes.linewidth': .55, 'xtick.major.width': .55, 'ytick.major.width': .55,
             'xtick.major.size': 2.5, 'ytick.major.size': 2.5,
             'xtick.labelsize': 8, 'ytick.labelsize': 8,
             'mathtext.fontset': 'stixsans', 'pdf.fonttype': 42,
             'ps.fonttype': 42, 'svg.fonttype': 'none',
             'figure.facecolor': 'white', 'savefig.facecolor': 'white'}
    with mpl.rc_context(style):
        fig = plt.figure(figsize=(180/25.4, 95/25.4), dpi=150)
        labels = []

        def text_mm(x, y, text, size=8.2, **kw):
            art = fig.text(x/180, y/95, text, fontproperties=font, fontsize=size, **kw)
            labels.append(art)
            return art

        def ax_mm(x, y, w, h):
            return fig.add_axes([x/180, y/95, w/180, h/95])

        angle = np.linspace(0, np.pi/2, 500)
        bdx, bdy = boundary_points(d['delta'])
        panel_info = []
        for j, x0 in enumerate([0, 90]):
            hybrid = j == 1
            selected = d['selected'] if hybrid else d['labels']
            title = ('混合 PBI' if hybrid else '参考解 PBI') if is_cn else ('Hybrid PBI' if hybrid else 'Reference-solution PBI')
            if hybrid:
                title += r'  ($t=0.20$)'
            text_mm(x0+6, 90, '('+('b' if hybrid else 'a')+')  '+title, 9.2)

            # Equal unit lengths; all eight points stay in the full field.
            ax = ax_mm(x0+11, 34, 23, 50)
            ax.set_xlim(-.12, 2.30)
            ax.set_ylim(-.15, 6.30)
            ax.set_aspect('equal', adjustable='box')
            ax.spines[['top', 'right']].set_visible(False)
            ax.spines['left'].set_position(('outward', 3))
            ax.spines['bottom'].set_position(('outward', 3))
            ax.set_xticks([0, 1, 2])
            ax.set_yticks([0, 2, 4, 6])
            ax.set_xlabel(r'$f_1$', labelpad=1)
            ax.set_ylabel(r'$f_2$', labelpad=0)
            ax.plot(np.cos(angle), np.sin(angle), color=INK, lw=1.1, zorder=2)
            ax.plot(bdx, bdy, color=GRAY, lw=.8, ls=(0, (4, 2)), zorder=1)

            if hybrid:
                for i, length, color in [(0, 1.65, BLUE), (2, 3.32, ORANGE)]:
                    v = d['directions'][d['directionIndex'][i]-1]
                    ax.plot([0, length*v[0]], [0, length*v[1]],
                            color=color, lw=.75, ls=(0, (1.3, 1.8)), zorder=1)
                ax.text(.17, 2.00, r'$\mathbf{v}_B$', color=ORANGE, fontsize=8.2)

            def point(axis, i, size=None):
                p = d['points'][i]
                color = BLUE if i == 0 else ORANGE if i == 2 else INK if i == 1 else GRAY
                marker = 'D' if i == 1 else 'o'
                size = size or (25 if i in [0, 2] else 20 if i == 1 else 15)
                axis.scatter(*p, s=size, marker=marker,
                             facecolors=color if selected[i] else 'white',
                             edgecolors=color, linewidths=1.0 if i in [0, 2] else .8,
                             zorder=5, clip_on=False)

            for i in range(8):
                point(ax, i)
            ax.annotate('R', xy=d['points'][1], xytext=(7, -2),
                        textcoords='offset points', fontsize=8.2)
            ax.annotate('B', xy=d['points'][2], xytext=(6, 0),
                        textcoords='offset points', fontsize=8.2, color=ORANGE)

            # The narrow A/boundary separation needs a matched enlargement.
            box = [.84, .21, .20, .20]
            ax.add_patch(Rectangle((box[0],box[1]),box[2],box[3],
                                   fill=False, ec='#aaaaaa', lw=.5, zorder=3))
            zoom = ax_mm(x0+45, 58, 25, 25)
            zoom.set_xlim(.84, 1.04)
            zoom.set_ylim(.21, .41)
            zoom.set_aspect('equal')
            zoom.tick_params(direction='out', pad=1, length=2, labelsize=7.5)
            zoom.set_xticks([.9, 1.0])
            zoom.set_yticks([.25, .35])
            for spine in zoom.spines.values():
                spine.set_color('#aaaaaa')
                spine.set_linewidth(.5)
            zoom.plot(np.cos(angle), np.sin(angle), color=INK, lw=1.1)
            zoom.plot(bdx,bdy,color=GRAY,lw=.8,ls=(0,(4,2)))
            if hybrid:
                v = d['directions'][d['directionIndex'][0]-1]
                zoom.plot([0,2*v[0]],[0,2*v[1]],color=BLUE,lw=.8,ls=(0,(1.3,1.8)))
                zoom.text(.997,.327,r'$\mathbf{v}_A$',color=BLUE,fontsize=8.2)
            point(zoom, 0, 31)
            zoom.annotate('A',xy=d['points'][0],xytext=(6,6),
                          textcoords='offset points',color=BLUE,fontsize=8.5)
            text_mm(x0+45, 85, 'A 附近放大' if is_cn else 'Detail near A', 8.0)
            connector = ConnectionPatch(xyA=(1.04,.41), coordsA=ax.transData,
                                        xyB=(.84,.21), coordsB=zoom.transData,
                                        arrowstyle='-', color='#b4b4b4', lw=.45, zorder=3)
            fig.add_artist(connector)
            text_mm(x0+43, 49.7,
                    r'$H=0.8S+0.2L$' if hybrid else r'$L=\mathbf{1}[g_R\leq 1]$',8.2)
            text_mm(x0+43, 44.0,
                    ('A：进入正组' if hybrid else 'A：漏判为负类') if is_cn
                    else ('A: recovered' if hybrid else 'A: missed'),
                    8.6, color=BLUE)
            text_mm(x0+43, 38.5,
                    ('B：未进入正组' if hybrid else 'B：判为正类') if is_cn
                    else ('B: not selected' if hybrid else 'B: positive'),
                    8.6, color=ORANGE)

            # Compact keys have no tinted backgrounds or enclosing cards.
            legend_y = [32.5, 27.6]
            for yy, st, label in zip(legend_y, ['-', (0,(4,2))],
                                      ['已知前沿', '参考解分类边界'] if is_cn else ['Known Pareto front', 'Reference boundary']):
                fig.add_artist(Line2D([(x0+43)/180,(x0+48)/180],[yy/95, yy/95],
                                      transform=fig.transFigure, color=INK if st=='-' else GRAY,
                                      ls=st,lw=1.0 if st=='-' else .8))
                text_mm(x0+50, yy-1.0,label,7.9)
            panel_info.append({'main_limits': [list(ax.get_xlim()), list(ax.get_ylim())],
                               'zoom_limits':[list(zoom.get_xlim()), list(zoom.get_ylim())],
                               'points': d['points'].tolist()})

        # Three horizontal rules; no cells, background blocks, or grid.
        for y,lw in [(23.8,.65),(17.6,.4),(5.3,.65)]:
            fig.add_artist(Line2D([7/180,173/180],[y/95,y/95],transform=fig.transFigure,color='#777777',lw=lw))
        cols = [13, 38, 75, 104, 143]
        heads = ['解','参考解标签 L','连续得分 S','融合得分 H','混合分组'] if is_cn else ['Solution','Reference label L','Score S','Score H','Hybrid group']
        for x, head in zip(cols,heads):
            text_mm(x,19.5,head,8.0,ha='center')
        for i, y in [(0,13.0),(2,7.5)]:
            color=BLUE if i==0 else ORANGE
            vals=[d['names'][i],str(int(d['labels'][i])),f"{d['S'][i]:.3f}",f"{d['H'][i]:.3f}",
                  ('正组' if i==0 else '非正组') if is_cn else ('Positive' if i==0 else 'Non-positive')]
            for col,(x,val) in enumerate(zip(cols,vals)):
                text_mm(x,y,val,8.3,ha='center',color=color if col in [0,4] else INK)
        text_mm(7,1.6,
                '实心：正组   空心：非正组   菱形：参考解 R' if is_cn
                else 'Filled: positive group   Open: non-positive group   Diamond: reference R',7.8)
        text_mm(173,1.6,'构造示例；非实验结果' if is_cn else 'Constructed example',7.8,ha='right')

        assert panel_info[0] == panel_info[1], 'Panels must share positions and limits.'
        stem=OUT/f'paqc_correction_{lang}'
        fig.canvas.draw()
        renderer=fig.canvas.get_renderer()
        outside=[]
        for artist in labels:
            bbox=artist.get_window_extent(renderer)
            if bbox.x0<0 or bbox.y0<0 or bbox.x1>fig.bbox.width or bbox.y1>fig.bbox.height:
                outside.append(artist.get_text())
        assert not outside, outside
        for fmt in ['pdf','svg','png']:
            fig.savefig(stem.with_suffix('.'+fmt),dpi=600,facecolor='white',transparent=False)
        plt.close(fig)
        return {'lang':lang,'physical_mm':[180,95],'panels':panel_info,'outside_text':outside}


def audit(exports, sources, d):
    import numpy as np
    import pymupdf
    from PIL import Image, ImageOps
    qa=OUT/'qa'
    qa.mkdir(exist_ok=True)
    report={'status':'AUTOMATED_CHECK_PASS; visual review still required',
            'sources':sources,'matlab_verified':True,'figures':[],
            'cutoff_gap':d['cutoffGap'],'boundary_epsilon_control':'A/B result unchanged without cosine epsilon',
            'requirements':'Provisional general manuscript dimensions, not a journal compliance claim.'}
    for export in exports:
        lang=export['lang']
        pdf=OUT/f'paqc_correction_{lang}.pdf'
        doc=pymupdf.open(pdf)
        page=doc[0]
        assert len(doc)==1
        actual_mm=[page.rect.width*25.4/72,page.rect.height*25.4/72]
        assert np.allclose(actual_mm,[180,95],atol=.02)
        spans=[s for b in page.get_text('dict')['blocks'] if 'lines' in b for line in b['lines'] for s in line['spans'] if s['text'].strip()]
        clipped=[s['text'] for s in spans if not page.rect.contains(pymupdf.Rect(s['bbox']))]
        assert not clipped, clipped
        assert not page.get_images(), 'PDF should contain vector line art and text only.'
        assert all('�' not in s['text'] for s in spans)
        fonts=page.get_fonts(full=True)
        assert all(f[1]!='n/a' for f in fonts), fonts
        minimum=min(s['size'] for s in spans)
        assert minimum>=5.2, minimum  # Mathematical subscripts only; base text >=7.5pt.
        page.get_pixmap(dpi=220,alpha=False).save(qa/f'{lang}_pdf_render.png')
        with Image.open(qa/f'{lang}_pdf_render.png') as img:
            ImageOps.grayscale(img).save(qa/f'{lang}_grayscale.png')
        with Image.open(OUT/f'paqc_correction_{lang}.png') as img:
            px=img.size
            dpi=img.info.get('dpi')
            assert abs(dpi[0]-600)<1
        report['figures'].append({**export,'actual_pdf_mm':actual_mm,'png_pixels':px,'png_dpi':dpi,
                                  'min_pdf_glyph_pt':minimum,'clipped_spans':clipped,
                                  'embedded_fonts':[f[3] for f in fonts],'raster_images_in_pdf':0})
    # A's crossing is not an all-early-stage guarantee.
    ds=float(d['S'][0]-d['S'][2])
    report['A_over_B_crossing_t']=ds/(1+ds)
    report['selection_change']={'reference_positive':['B','C'],'hybrid_positive':['A','R']}
    (qa/'verification_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('FIGURE_EXPORT_CHECK_PASS')
    print(json.dumps({'cutoff_gap':d['cutoffGap'],'A_over_B_crossing_t':report['A_over_B_crossing_t'],
                      'files':[f"paqc_correction_{x}.{ext}" for x in ['cn','en'] for ext in ['pdf','svg','png']]},indent=2))


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--prepare-only',action='store_true')
    args=parser.parse_args()
    if args.prepare_only:
        prepare()
        return
    d,sources=load_verified()
    exports=[render(lang,d) for lang in ['cn','en']]
    audit(exports,sources,d)


if __name__=='__main__':
    main()
