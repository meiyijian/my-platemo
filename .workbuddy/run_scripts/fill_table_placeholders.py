# -*- coding: utf-8 -*-
"""Replace <!--TABLE_*--> placeholders in the Chinese mirror of the manuscript
with the Markdown fragments produced by tex_table_to_md.py.

Usage:
    python fill_table_placeholders.py <target.md> <KEY>=<fragment.md> [...]
"""
import sys

target = sys.argv[1]
pairs = [a.split('=', 1) for a in sys.argv[2:]]

with open(target, encoding='utf-8') as fh:
    text = fh.read()

for key, path in pairs:
    with open(path, encoding='utf-8') as fh:
        frag = fh.read().strip('\n')
    token = '<!--%s-->' % key
    if token not in text:
        raise SystemExit('placeholder %s not found in %s' % (token, target))
    text = text.replace(token, frag)

with open(target, 'w', encoding='utf-8', newline='\n') as fh:
    fh.write(text)
print('filled %d placeholder(s) in %s' % (len(pairs), target))
