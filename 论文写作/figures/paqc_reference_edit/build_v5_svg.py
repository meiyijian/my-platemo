from pathlib import Path
import base64
import html
import math
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
parts = ['''<svg xmlns="http://www.w3.org/2000/svg" width="1774" height="887" viewBox="0 0 1774 887">
<title>Representative-based classification and PAQC</title>
<desc>Editable reconstruction of paqc_geometry_v5.png. Conceptual illustration, not a numerically validated classification example. P1 and P2 illustrate non-dominated solutions used in the adaptive reference-direction branch.</desc>
<defs>
<marker id="black-arrow" viewBox="0 0 12 9" refX="11" refY="4.5" markerWidth="11" markerHeight="9" orient="auto-start-reverse" markerUnits="userSpaceOnUse"><path d="M0,0 L12,4.5 L0,9 Z" fill="#111"/></marker>
<marker id="axis-arrow" viewBox="0 0 20 16" refX="19" refY="8" markerWidth="20" markerHeight="16" orient="auto" markerUnits="userSpaceOnUse"><path d="M0,0 L20,8 L0,16 Z" fill="#111"/></marker>
<marker id="ray-arrow" viewBox="0 0 20 14" refX="19" refY="7" markerWidth="20" markerHeight="14" orient="auto" markerUnits="userSpaceOnUse"><path d="M0,0 L20,7 L0,14 Z" fill="#111"/></marker>
<marker id="blue-arrow" viewBox="0 0 15 10" refX="14" refY="5" markerWidth="15" markerHeight="10" orient="auto" markerUnits="userSpaceOnUse"><path d="M0,0 L15,5 L0,10 Z" fill="#0054ff"/></marker>
</defs>
<rect width="1774" height="887" fill="white"/>
<g font-family="Times New Roman, Times, serif" fill="#111" stroke-linejoin="round">''']

def text(x,y,s,size=29,italic=False,color='#111',anchor=None):
    a = f' text-anchor="{anchor}"' if anchor else ''
    parts.append(f'<text x="{x}" y="{y}" font-size="{size}" font-style="{"italic" if italic else "normal"}" fill="{color}"{a}>{s}</text>')

def label(x,y,s,n,size=29,color='#111'):
    text(x,y,f'{s}<tspan baseline-shift="sub" font-size="70%">{n}</tspan>',size,True,color)

def line(x1,y1,x2,y2,color='#111',w=1.9,arrow=None,dash=None):
    length=math.hypot(x2-x1,y2-y1)
    ux,uy=(x2-x1)/length,(y2-y1)/length
    steps=[float(v) for v in dash.split()] if dash else [length]
    pos=0; i=0
    while pos < length:
        stop=min(length,pos+steps[i%len(steps)])
        if i%2==0:
            parts.append(f'<line x1="{x1+ux*pos}" y1="{y1+uy*pos}" x2="{x1+ux*stop}" y2="{y1+uy*stop}" stroke="{color}" stroke-width="{w}"/>')
        pos=stop; i+=1
    if arrow:
        al,aw={'axis-arrow':(20,8),'ray-arrow':(20,7),'black-arrow':(12,4.5),'blue-arrow':(15,5)}[arrow]
        bx,by=x2-al*ux,y2-al*uy
        parts.append(f'<path d="M{x2},{y2} L{bx-aw*uy},{by+aw*ux} L{bx+aw*uy},{by-aw*ux} Z" fill="{color}"/>')

def good(x,y,r=10):
    parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#1ba3a2" stroke="#078f91" stroke-width="1"/>')

def bad(x,y):
    parts.append(f'<rect x="{x-10.5}" y="{y-10.5}" width="21" height="21" fill="white" stroke="#ff6c17" stroke-width="2"/>')

def diamond(x,y,r=12):
    parts.append(f'<path d="M{x},{y-r} L{x+r},{y} L{x},{y+r} L{x-r},{y} Z" fill="#e8b129" stroke="#111" stroke-width="1.4"/>')

def reference_ray(name, through, scale, color='#111', dashed=False):
    # The axes intersect at O=Z=(86,663). Extend exactly through the source point.
    ox,oy=86,663
    px,py=through
    ex,ey=ox+scale*(px-ox),oy+scale*(py-oy)
    parts.append(f'<g id="{name}" data-origin="86,663" data-through="{px},{py}">')
    line(ox,oy,ex,ey,color,1.7 if dashed else 1.9,
         'blue-arrow' if dashed else 'ray-arrow','10 6' if dashed else None)
    parts.append('</g>')

def panel(offset,right=False):
    parts.append(f'<g id="{"paqc" if right else "representative"}" transform="translate({offset} 0)">')
    line(49,663,850,663,arrow='axis-arrow')
    line(86,674,86,75,arrow='axis-arrow')
    label(41,94,'f',2,34)
    label(825,706,'f',1,34)
    text(43,702,'O = Z',33,True)
    prefix='right' if right else 'left'
    reference_ray(prefix+'-R1-ray',(307,263),1.2325)
    reference_ray(prefix+'-R2-ray',(621,434),647/535)
    parts.append('<path d="M125,187 C137,248 155,308 192,362 C248,457 339,541 448,589 C520,617 603,631 677,633" fill="none" stroke="#ff202a" stroke-width="1.65"/>')
    text(670,620,'PF',30,True)
    for a,b in [((252,219),(307,263)),((307,263),(402,287)),((584,352),(621,434)),((621,434),(660,504))]:
        line(*a,*b,'#ff641e',1.8,dash='17 10 2 10')
    if right:
        reference_ray('right-v1-ray',(192,362),468/301,'#0054ff',True)
        reference_ray('right-v2-ray',(448,589),451/362,'#0054ff',True)
        label(205,195,'v',1,28,'#0054ff')
        label(505,542,'v',2,25,'#0054ff')
    diamond(307,263)
    diamond(621,434)
    label(331,253,'R',1)
    label(626,406,'R',2)
    # Solution identities and coordinates are shared by both panels.
    (good if right else bad)(144,243)
    (good if right else bad)(566,571)
    (bad if right else good)(711,247)
    bad(371,392)
    good(192,362)
    good(448,589)
    text(152,220,'A',30,True)
    text(586,542 if right else 567,'B',30,True)
    text(726,229,'C',30,True)
    label(205,350,'P',1,30)
    label(460,582,'P',2,30)
    if right:
        for x,y in [(144,243),(566,571)]:
            parts.append(f'<circle cx="{x}" cy="{y}" r="22" fill="none" stroke="#0054ff" stroke-width="1.6"/>')
        text(317,145,'Directional PBI assessment',24,True,'#0054ff')
        line(312,148,276,176,'#0054ff',1.4,'blue-arrow')
        text(284,424,'Non-dominated solutions',24,True)
        line(277,384,219,369,arrow='black-arrow',w=1.7)
        line(389,436,448,565,arrow='black-arrow',w=1.7)
        text(646,534,'Reassigned to Good group',22,True,'#0054ff')
        line(641,535,604,563,'#0054ff',1.4,'blue-arrow')
    else:
        text(418,177,'Reference-based boundary',25)
        line(415,188,379,222,arrow='black-arrow')
    parts.append('</g>')

text(221,43,'(a) Representative-based classification',36)
text(1264,43,'(b) PAQC',36)
panel(0)
panel(888,True)
parts.append('<g id="legend"><rect x="470" y="765" width="836" height="62" fill="white" stroke="#111" stroke-width="1.6"/>')
good(531,796,13)
text(562,806,'Good group',28)
parts.append('<rect x="770" y="783" width="26" height="27" fill="white" stroke="#ff6c17" stroke-width="2.5"/>')
text(818,806,'Bad group',28)
diamond(1030,797,15)
text(1066,806,'Reference solution',28)
parts.append('</g></g></svg>')
svg = '\n'.join(parts)
ET.fromstring(svg)
(ROOT/'paqc_geometry_v5_editable.svg').write_text(svg,encoding='utf-8')
data=base64.b64encode((ROOT/'paqc_geometry_v5.png').read_bytes()).decode('ascii')
exact=f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1774" height="887" viewBox="0 0 1774 887"><title>PAQC original appearance (embedded raster)</title><desc>Lossless PNG embedded in an SVG container; not editable vector geometry.</desc><image width="1774" height="887" xlink:href="data:image/png;base64,{data}"/></svg>'
ET.fromstring(exact)
(ROOT/'paqc_geometry_v5_exact.svg').write_text(exact,encoding='utf-8')
print('Created editable and exact-appearance SVG files; XML validated.')
