"""Export the user-selected SVG without changing its artwork or arrangement.

Run: uv run --with cairosvg --with pymupdf python export_editable_pdf.py
"""
from pathlib import Path
import os
import xml.etree.ElementTree as ET

base = Path(__file__).resolve().parent
dll = Path(os.environ['USERPROFILE']) / '.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/Library/bin'
os.environ['PATH'] = str(dll) + os.pathsep + os.environ['PATH']
handle = os.add_dll_directory(str(dll))
import cairosvg
import pymupdf

source = base / 'paqc_geometry_v5_editable.svg'
target = source.with_suffix('.pdf')
# CairoSVG misinterprets percentage font sizes on nested tspans. Resolve the
# equivalent absolute size in memory, keeping the user-selected SVG intact.
root = ET.parse(source).getroot()
def resolve_fonts(element, inherited=16.0):
    value = element.get('font-size')
    size = inherited
    if value:
        size = inherited * float(value[:-1]) / 100 if value.endswith('%') else float(value.removesuffix('px'))
        if value.endswith('%'):
            element.set('font-size', str(size))
    for child in element:
        resolve_fonts(child, size)
resolve_fonts(root)
cairosvg.svg2pdf(bytestring=ET.tostring(root), write_to=str(target))
doc = pymupdf.open(target)
assert not doc[0].get_images(), 'Expected pure vector PDF'
doc[0].get_pixmap(matrix=pymupdf.Matrix(1, 1)).save(base / 'paqc_geometry_v5_editable_preview.png')
print(f'{target}: {doc[0].rect}, no raster images')
