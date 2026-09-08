"""Repair the supplied editable schematic and export a single-column vector PDF.

Run with uv run --with cairosvg --with pymupdf python build_paqc_vector.py.
The original SVG/PNG are preserved. Geometry is illustrative, not PBI data.
"""
from pathlib import Path
import copy
import os
import xml.etree.ElementTree as ET

BASE = Path(__file__).resolve().parent
DLL = Path(os.environ['USERPROFILE']) / '.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/Library/bin'
if DLL.exists():
    os.environ['PATH'] = str(DLL) + os.pathsep + os.environ['PATH']
    dll_handle = os.add_dll_directory(str(DLL))
import cairosvg
import pymupdf

NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', NS)
def tag(s): return f'{{{NS}}}{s}'
def add(parent, name, **attrs):
    return ET.SubElement(parent, tag(name), {k.replace('_', '-'): str(v) for k, v in attrs.items()})
def label(parent, x, y, text, cls='t lab'):
    e = add(parent, 'text', x=x, y=y, **{'class': cls}); e.text = text; return e
def bez(t):
    pts = [(121,181),(163,390),(345,585),(659,616)]
    weights = [(1-t)**3,3*(1-t)**2*t,3*(1-t)*t*t,t**3]
    return tuple(sum(w*p[i] for w,p in zip(weights,pts)) for i in range(2))

root = ET.parse(BASE / 'PAQC示意图.svg').getroot()
left = root.find(".//*[@id='left_panel']")
origin = (84,644)
circles = left.findall(tag('circle'))
p1,p2 = bez(.28),bez(.75)
for point, pos, name in zip(circles[:2], [p1,p2], ['P₁','P₂']):
    point.set('cx',str(pos[0])); point.set('cy',str(pos[1]))
    for text in left.findall(tag('text')):
        if text.text == name:
            text.set('x',str(pos[0]+14)); text.set('y',str(pos[1]-12))
for ray, ref in zip([e for e in left.findall(tag('line')) if e.get('x1') == '95'], [(299,255),(604,422)]):
    ray.set('x1','84');ray.set('y1','644')
    ray.set('x2',str(84+1.23*(ref[0]-84)));ray.set('y2',str(644+1.23*(ref[1]-644)))
# Explicitly put the local schematic thresholds through their reference markers.
boundaries = [e for e in left.findall(tag('path')) if e.get('class')=='redDash']
boundaries[0].set('d','M243 213 L299 255 L394 279')
boundaries[1].set('d','M568 345 L604 422 L643 493')
# A is drawn on the illustrative PF; B remains outside it.
a = bez(.085)
rects = left.findall(tag('rect'))
rects[0].set('x',str(a[0]-10));rects[0].set('y',str(a[1]-10))
for text in left.findall(tag('text')):
    if text.text=='A':text.set('x',str(a[0]+15));text.set('y',str(a[1]-19))
right = copy.deepcopy(left)
right.set('id','right_panel')
# Remove only the left panel's boundary callout, preserving all shared geometry.
for e in list(right):
    if e.text=='Reference-based boundary' or (e.tag==tag('line') and e.get('x1')=='403'):
        right.remove(e)
for e in list(right.findall(tag('circle'))):
    if e.get('cx')=='692':
        right.remove(e);add(right,'rect',x=682,y=229,width=20,height=20,fill='none',stroke='#ff4c10',stroke_width=2)
for e in list(right.findall(tag('rect'))):
    if e.get('x') in [str(a[0]-10),'542']:
        x,y=float(e.get('x'))+10,float(e.get('y'))+10
        right.remove(e);add(right,'circle',cx=x,cy=y,r=11,fill='#24aaa5')
        add(right,'circle',cx=x,cy=y,r=22,fill='none',stroke='#1769ff',stroke_width=2)
# Draw full rays behind the points; verify exact collinearity with direction sources.
for i,(p,scale) in enumerate([(p1,1.60),(p2,1.18)],1):
    end=(84+scale*(p[0]-84),644+scale*(p[1]-644))
    ray=ET.Element(tag('line'),{'x1':'84','y1':'644','x2':str(end[0]),'y2':str(end[1]),'class':'blueDash','marker-end':'url(#arrow-blue)'})
    right.insert(2,ray)
    label(right,end[0]-24,end[1]-14,'v'+('₁' if i==1 else '₂'),'tb lab')
    assert abs((p[0]-84)*(end[1]-644)-(p[1]-644)*(end[0]-84))<1e-7
label(right,350,130,'Directional PBI assessment','tb txt')
add(right,'line',x1=342,y1=137,x2=245,y2=198,**{'class':'blue','marker-end':'url(#arrow-blue)'})
label(right,310,310,'Non-dominated solutions','t txt')
add(right,'line',x1=303,y1=307,x2=p1[0]+22,y2=p1[1]+4,**{'class':'thin','marker-end':'url(#arrow-black)'})
add(right,'line',x1=418,y1=324,x2=p2[0]-4,y2=p2[1]-22,**{'class':'thin','marker-end':'url(#arrow-black)'})
label(right,610,519,'Reassigned to','tb small')
label(right,610,544,'Good group','tb small')
add(right,'line',x1=602,y1=548,x2=579,y2=556,**{'class':'blue','marker-end':'url(#arrow-blue)'})

# Single-column adaptation: stack two full-width panels to retain 7--9 pt text.
out=ET.Element(tag('svg'),{'width':'88.56mm','height':'149.5mm','viewBox':'0 0 840 1418'})
out.append(copy.deepcopy(root.find(tag('defs'))))
style=copy.deepcopy(root.find(tag('style')))
style.text=style.text.replace('font-size:21px','font-size:24px')
out.append(style)
add(out,'rect',x=0,y=0,width=840,height=1418,fill='white')
left.set('transform','translate(0,-10)');right.set('transform','translate(0,650)')
out.append(left);out.append(right)
label(out,125,35,'(a) Representative-based classification','t title')
label(out,350,695,'(b) PAQC','t title')
legend=add(out,'g')
add(legend,'circle',cx=80,cy=1384,r=11,fill='#24aaa5');label(legend,102,1393,'Good group','t legend')
add(legend,'rect',x=285,y=1373,width=22,height=22,fill='none',stroke='#ff4c10',stroke_width=2);label(legend,319,1393,'Bad group','t legend')
add(legend,'polygon',points='538,1372 550,1384 538,1396 526,1384',fill='#f2b51d',stroke='black',stroke_width=1.5);label(legend,562,1393,'Reference solution','t legend')
svg=BASE/'paqc_mechanism_single_column.svg'
ET.ElementTree(out).write(svg,encoding='utf-8',xml_declaration=True)
cairosvg.svg2pdf(url=str(svg),write_to=str(BASE/'paqc_mechanism_single_column.pdf'))
doc=pymupdf.open(BASE/'paqc_mechanism_single_column.pdf')
assert len(doc[0].get_images())==0, 'PDF must contain no raster image objects'
doc[0].get_pixmap(matrix=pymupdf.Matrix(3,3)).save(BASE/'paqc_mechanism_single_column_preview.png')
cairosvg.svg2png(url=str(BASE/'PAQC示意图.svg'),write_to=str(BASE/'paqc_svg_original_preview.png'))
print('Vector PDF:',doc[0].rect,'raster images:',len(doc[0].get_images()))
print('Exporter versions:',cairosvg.__version__,pymupdf.VersionBind)
