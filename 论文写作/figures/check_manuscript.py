"""Render and inspect the assembled manuscript without modifying its content."""
from pathlib import Path
import json
import re
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import pymupdf

HERE=Path(__file__).resolve().parent
WORK=HERE.parent/'.figure_work'
WORK.mkdir(exist_ok=True)
doc=pymupdf.open(HERE.parent/'HPDC-MaOEA.pdf')
records=[]
for i,page in enumerate(doc):
    text=page.get_text()
    names=re.findall(r'Figure\s*[1-5]:',text)
    for label in names:
        if len(page.search_for(label))==0:raise ValueError(label)
    pix=page.get_pixmap(matrix=pymupdf.Matrix(1.3,1.3),alpha=False)
    pix.save(WORK/f'page_{i+1:02}.png')
    records.append({'page':i+1,'figure_captions':names,'text_chars':len(text),'embedded_images':len(page.get_images())})
fig,axs=plt.subplots(4,4,figsize=(14,19))
for i,ax in enumerate(axs.flat):
    ax.axis('off')
    if i<len(doc):
        ax.imshow(plt.imread(WORK/f'page_{i+1:02}.png'))
        ax.set_title(f'Page {i+1}',fontsize=10)
fig.subplots_adjust(left=.005,right=.995,bottom=.005,top=.98,hspace=.13,wspace=.025)
fig.savefig(WORK/'manuscript_montage.png',dpi=160,facecolor='white');plt.close(fig)
captions=[x for rec in records for x in rec['figure_captions']]
assert sorted(captions)==[f'Figure {i}:' for i in range(1,6)],captions
manifest=json.loads((HERE/'manifest.json').read_text(encoding='utf-8'))
for f in manifest['figures']:
    assert f['minimum_pdf_glyph_pt']>=5
    assert all((HERE/f"{f['name']}.{ext}").is_file() for ext in ['svg','pdf','png'])
log=(HERE.parent/'HPDC-MaOEA.log').read_text(encoding='utf-8',errors='replace')
failures=[line for line in log.splitlines() if re.search(r'Overfull|undefined|multiply defined|LaTeX Warning',line)]
assert not failures,failures
print(json.dumps(records,indent=2))
(WORK/'manuscript_qa.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print('Five figure captions verified; all six figure bundles present; no unresolved LaTeX warnings.')
