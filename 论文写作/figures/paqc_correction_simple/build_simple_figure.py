"""Draw a compact, source-verified geometric example in the supplied figure's style.

This is newly drawn vector art, not a modification of the supplied screenshot.
Run verify_simple_paqc.m first; then use the existing figures requirements.
"""
from pathlib import Path
import json
import hashlib
import numpy as np
import matplotlib as mpl
mpl.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from matplotlib.patches import FancyArrowPatch
from PIL import Image, ImageOps
import pymupdf

OUT=Path(__file__).resolve().parent
GREEN='#A1C98F'
ORANGE='#F6AB84'
YELLOW='#FFE76A'
BLUE='#386DA6'
INK='#292929'
RED='#F05B63'


def draw(lang,d):
    cn=lang=='cn'
    font=FontProperties(fname='C:/Windows/Fonts/msyh.ttc' if cn else 'C:/Windows/Fonts/times.ttf')
    rc={'font.family':'Times New Roman','font.size':9,'mathtext.fontset':'stix',
        'text.color':INK,'pdf.fonttype':42,'ps.fonttype':42,'svg.fonttype':'none',
        'figure.facecolor':'white','savefig.facecolor':'white'}
    with mpl.rc_context(rc):
        fig=plt.figure(figsize=(170/25.4,79/25.4),dpi=160)
        states=[]
        for j in [0,1]:
            ax=fig.add_axes([.032+j*.505,.11,.444,.855])
            ax.set_xlim(-.13,2.67)
            ax.set_ylim(-.10,2.77)
            ax.set_aspect('equal')
            ax.axis('off')
            for end in [(2.63,0),(0,2.73)]:
                ax.add_patch(FancyArrowPatch((0,0),end,arrowstyle='-|>',
                    mutation_scale=10,lw=.72,color=INK,zorder=1))
            # The analytic front provides an independent visual reference.
            ang=np.linspace(0,np.pi/2,400)
            ax.plot(d['Z'][0]+np.cos(ang),d['Z'][1]+np.sin(ang),
                    color='#9A9A9A',lw=.8,zorder=1)
            ax.text(.47,.83,'PF',fontsize=8.7,color='#777777',fontstyle='italic')
            selected=d['selected'] if j else d['L']
            if j==0:
                c=np.cos(ang)-1e-6
                r=1/(c+d['delta']*np.sqrt(1-c*c))
                ax.plot(d['Z'][0]+r*np.cos(ang),d['Z'][1]+r*np.sin(ang),
                        color=RED,lw=1.0,ls=(0,(1.7,2.0)),zorder=2)
            else:
                # Both focal points associate with the diagonal direction in
                # this prescribed sparse field; show B's perpendicular penalty.
                va=d['directions'][d['association'][0]-1]
                origin=d['Z']
                end=origin+2.28*va
                ax.add_patch(FancyArrowPatch(origin,end,arrowstyle='-|>',
                    mutation_scale=9,lw=.9,color=BLUE,zorder=2))
                vb=d['directions'][d['association'][2]-1]
                b=d['points'][2]
                projection=origin+np.dot(b-origin,vb)*vb
                ax.plot([b[0],projection[0]],[b[1],projection[1]],
                        color=BLUE,lw=.85,ls=(0,(1.5,2.0)),zorder=2)
                ax.text(1.64,2.38,'方向信息' if cn else 'directional information',
                        fontproperties=font,fontsize=9.2,color=BLUE,
                        fontstyle='normal' if cn else 'italic',ha='center')
            for i,p in enumerate(d['points']):
                if i==1:
                    ax.scatter(*p,s=145,marker='*',c=YELLOW,edgecolors=INK,linewidths=.7,zorder=5)
                    continue
                positive=bool(selected[i])
                focal=i in [0,2]
                ax.scatter(*p,s=75 if focal else 80,marker='o' if positive else 'h',
                           facecolors=GREEN if positive else ORANGE,
                           edgecolors=BLUE if focal else '#6F8B65' if positive else '#C78B6D',
                           linewidths=.9 if focal else .3,zorder=5)
                if focal:
                    label=d['names'][i]
                    dx,dy=(.10,-.06) if i==0 else (-.16,.045)
                    ax.text(p[0]+dx,p[1]+dy,label,fontsize=10.0,color=BLUE)
            title=(('(a)  参考解 PBI' if cn else '(a)  Reference-solution PBI') if j==0
                   else ('(b)  混合 PBI' if cn else '(b)  Hybrid PBI'))
            fig.text(.26+j*.505,.034,title,fontproperties=font,fontsize=10.0,ha='center')
            states.append({'limits':[list(ax.get_xlim()),list(ax.get_ylim())],
                           'points':d['points'].tolist()})
        assert states[0]==states[1]
        for ext in ['pdf','svg','png']:
            fig.savefig(OUT/f'paqc_simple_{lang}.{ext}',dpi=600,facecolor='white')
        plt.close(fig)


def main():
    d=json.loads((OUT/'simple_records.json').read_text(encoding='utf-8'))
    assert d['status']=='MATLAB_SIMPLE_SOURCE_CHECK_PASS'
    for key in ['points','Z','reference','directions','association','selected','L','S','H']:
        d[key]=np.asarray(d[key])
    assert set(np.flatnonzero(d['selected']))=={0,1,4}
    assert not d['L'][0] and d['L'][2]
    qa=OUT/'qa'
    qa.mkdir(exist_ok=True)
    report={'status':'NUMERICAL_AND_EXPORT_PASS','comparison':'same points and scales',
            'style_reference':'user-supplied REMO figure; newly drawn vector artwork',
            'figure_size_mm':[170,79],'cutoff_gap':d['cutoffGap'],'figures':[]}
    for lang in ['cn','en']:
        draw(lang,d)
        doc=pymupdf.open(OUT/f'paqc_simple_{lang}.pdf')
        page=doc[0]
        assert np.allclose([page.rect.width*25.4/72,page.rect.height*25.4/72],[170,79],atol=.02)
        spans=[s for b in page.get_text('dict')['blocks'] if 'lines' in b for l in b['lines'] for s in l['spans']]
        assert all(page.rect.contains(pymupdf.Rect(s['bbox'])) for s in spans)
        assert not page.get_images()
        page.get_pixmap(dpi=180,alpha=False).save(qa/f'{lang}_render.png')
        with Image.open(qa/f'{lang}_render.png') as im:
            ImageOps.grayscale(im).save(qa/f'{lang}_grayscale.png')
        report['figures'].append({'lang':lang,'min_glyph_pt':min(s['size'] for s in spans),
                                  'raster_images_in_pdf':0})
    (qa/'checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
