# -*- coding: utf-8 -*-
"""Convert the generated main-performance LaTeX tables (booktabs + shortstack)
into GitHub-flavoured Markdown, preserving the mean/std/symbol structure and
marking the row-minimum cell in bold.

Usage:
    python tex_table_to_md.py <table.tex> <out.md>
"""
import re
import sys

SYM = [(r'\,$=$', '='), (r'\,$+$', '+'), (r'\,$-$', '-')]


def strip_bold(s):
    return s.replace(r'\textbf{', '').replace('}', '')


def clean_cell(raw):
    s = raw.replace('\\\\', ' ').strip()
    if not s:
        return ''
    bold = r'\textbf' in s
    s = s.replace(r'\cellcolor{black!25}', '')
    m = re.search(r'\\shortstack\{(.*)\}\s*$', s, re.S)
    if m:
        halves = [h for h in re.split(r'\\\\', m.group(1)) if h.strip()]
        s = ' '.join(strip_bold(h).strip() for h in halves)
    else:
        s = strip_bold(s)
    for k, v in SYM:
        s = s.replace(k, ' ' + v)
    s = re.sub(r'\s+', ' ', s).strip()
    return '**' + s + '**' if bold else s


def main():
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, encoding='utf-8') as fh:
        lines = fh.read().splitlines()

    caption = ''
    for ln in lines:
        m = re.match(r'\\caption\{(.*)\}\s*$', ln)
        if m:
            caption = m.group(1)
            break

    rows, totals = [], None
    for ln in lines:
        if ln.lstrip().startswith('\\multicolumn'):
            cells = [c.strip() for c in ln.split('&')]
            label = strip_bold(re.sub(r'\\multicolumn\{2\}\{c\}\{', '', cells[0])).rstrip('}').strip()
            values = [strip_bold(c).replace('\\\\', '').strip() for c in cells[1:]]
            totals = (label, values)
            continue
        if '&' not in ln or ln.lstrip().startswith('\\'):
            continue
        cells = ln.split('&')
        if len(cells) < 9:
            continue
        head = strip_bold(cells[0]).strip()
        if head == 'Problem':           # LaTeX header row
            continue
        rows.append((head, strip_bold(cells[1]).strip(),
                     [clean_cell(c) for c in cells[2:]]))

    # the problem name sits on the middle row of each M = 10/15/20 triple
    grouped, i = [], 0
    while i < len(rows):
        chunk = rows[i:i + 3]
        name = next((c[0] for c in chunk if c[0]), '')
        for _, m_val, values in chunk:
            grouped.append((name, m_val, values))
        i += 3

    header = ['问题', '$M$', 'REMO', 'PIEA', 'CSEA', 'PC-SAEA', 'K-RVEA', 'MCEA/D', 'PACDIS']
    out = ['<!-- %s -->' % caption, '',
           '| ' + ' | '.join(header) + ' |',
           '|' + '---|' * len(header)]
    prev = None
    for name, m_val, values in grouped:
        if prev is not None and name != prev:
            out.append('| | | | | | | | | |')
        prev = name
        out.append('| %s | %s | %s |' % (name, m_val, ' | '.join(values)))
    if totals:
        label, values = totals
        out.append('| **合计 %s** | | %s |' % (label, ' | '.join(values)))
    out.append('')
    with open(dst, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(out))
    print('wrote %s (%d data rows)' % (dst, len(grouped)))


if __name__ == '__main__':
    main()
