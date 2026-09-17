# -*- coding: utf-8 -*-
r"""Convert the wide ablation table and the inline p_mix sensitivity table of
HPDC-MaOEA.tex into GitHub-flavoured Markdown.

Both tables use booktabs + \multicolumn group banners and a summary row whose
first two columns are merged, so a summary row carries one cell fewer than a
data row.

Usage:
    python tex_ablation_pmix_to_md.py ablation <table_full_dtlz_wfg.tex> <out.md>
    python tex_ablation_pmix_to_md.py pmix     <HPDC-MaOEA.tex>        <out.md>
"""
import re
import sys


def clean(cell):
    """Mean (std) with a trailing significance symbol, or plain text."""
    s = cell.strip()
    bold = r'\textbf' in s or r'\mathbf' in s
    s = re.sub(r'\\cellcolor\{[^}]*\}', '', s)
    prev = None
    while prev != s:                       # unwrap \textbf{...} / \mathbf{...}
        prev = s
        s = re.sub(r'\\(?:textbf|textit|mathbf|mathrm|bm|emph|text)\{([^{}]*)\}',
                   r'\1', s)
    s = s.replace('$', '')
    # trailing ^{+} / ^{-} / ^{=} significance symbol
    m = re.search(r'\^(?:\{\s*)?([-+=])(?:\s*\})?\s*$', s)
    sym = ''
    if m:
        sym = m.group(1)
        s = s[:m.start()]
    s = s.replace(r'\;', ' ')
    s = re.sub(r'\\(?:,|;|quad|qquad|!)\s*', ' ', s)
    s = re.sub(r'\\[A-Za-z]+\s*\{?', ' ', s)   # a command left without a brace
    s = s.replace('{', ' ').replace('}', ' ')
    s = s.replace('\\', ' ')
    s = re.sub(r'\s+', ' ', s).strip()
    if sym:
        s = s + ' ' + sym
    return '**' + s + '**' if bold else s


def tabular_body(path, mode):
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().splitlines()
    if mode == 'pmix':
        start = next((i for i, ln in enumerate(lines)
                      if r'\label{tab:exp:pmix}' in ln and 'sec:' not in ln), None)
        if start is None:
            raise SystemExit('label tab:exp:pmix not found in %s' % path)
        a = min(i for i in range(start, len(lines)) if '\\begin{tabular' in lines[i])
        b = min(i for i in range(start, len(lines)) if '\\end{tabular' in lines[i])
    else:
        a = next(i for i, ln in enumerate(lines) if '\\begin{tabular' in ln)
        b = next(i for i, ln in enumerate(lines) if '\\end{tabular' in ln)
    return lines[a + 1:b]


def convert(mode, path):
    table = []
    for ln in tabular_body(path, mode):
        s = ln.strip()
        if not s or s.startswith('\\toprule') or s.startswith('\\midrule') \
                or s.startswith('\\bottomrule'):
            continue
        if s == r'\end{tabular*}' or s.startswith('\\end{tabular'):
            continue
        cells = [c.strip() for c in s.rstrip('\\').strip().split('&')]
        if cells[0] == 'Problem':          # LaTeX header row
            continue
        table.append(cells)

    ncol = max(len(c) for c in table)
    md = []
    for cells in table:
        first = cells[0]
        if first.startswith('\\multicolumn'):
            span = int(re.match(r'\\multicolumn\{(\d+)\}', first).group(1))
            label = re.sub(r'^\\multicolumn\{\d+\}\{[^}]*\}\{', '', first).rstrip('}')
            label = clean(label)
            vals = [clean(c) for c in cells[1:]]
            if span == ncol:                      # group banner, one plain row
                md.append('| **%s** |%s' % (label, ' |' * (ncol - 1)))
            else:                                 # summary row
                md.append('| **%s** |%s%s' % (label, ' |' * (span - 1),
                                              ''.join(' %s |' % v for v in vals)))
            continue
        md.append('| ' + ' | '.join(clean(c) for c in cells) + ' |')
    return md


def main():
    mode, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    if mode == 'pmix':
        header = ['问题', '$D$', '$p_{\\mathrm{mix}}=0$', '$0.25$', '$0.50$',
                  '$0.75$', '$1.00$']
    else:
        header = ['问题', '$D$', 'Full-CDIS', 'Full-PAQC', 'Full', 'REMO']
    out = ['| ' + ' | '.join(header) + ' |', '|' + '---|' * len(header)]
    out += convert(mode, src)
    with open(dst, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(out) + '\n')
    print('wrote %s (%d lines)' % (dst, len(out)))


if __name__ == '__main__':
    main()
