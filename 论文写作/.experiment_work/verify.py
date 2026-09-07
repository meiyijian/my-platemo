from pathlib import Path
import re,json
from pypdf import PdfReader
from PIL import Image,ImageDraw
work=Path(__file__).parent
paper=work.parent/'HPDC-MaOEA.tex'
before=(work/'HPDC-MaOEA.before.tex').read_bytes();after=paper.read_bytes()
start=b'\\section{Experimental Studies}';end=b'\\section{Conclusion}'
assert before.split(start)[0]==after.split(start)[0]
assert before.split(end)[1]==after.split(end)[1]
doc=PdfReader(work.parent/'HPDC-MaOEA.pdf')
thumbs=[]
for i,page in enumerate(doc.pages):
    text=page.extract_text()
    print(i+1,'TABLES',re.findall(r'Table \d+',text),'EXPERIMENT', 'Experimental Studies' in text,'CONCLUSION','5. Conclusion' in text)
    if i>=4:
        png=work/f'page-{i+1:02}.png'
        im=Image.open(png).convert('RGB');im.thumbnail((460,650))
        tile=Image.new('RGB',(480,680),'#dddddd');tile.paste(im,((480-im.width)//2,24));ImageDraw.Draw(tile).text((12,5),f'Page {i+1}',fill='black');thumbs.append(tile)
montage=Image.new('RGB',(480*3,680*((len(thumbs)+2)//3)),'white')
for i,im in enumerate(thumbs):montage.paste(im,((i%3)*480,(i//3)*680))
montage.save(work/'montage.png')
print('Total pages:',len(doc.pages))
print('Scope preservation passed. PDF pages rendered:',len(thumbs))
