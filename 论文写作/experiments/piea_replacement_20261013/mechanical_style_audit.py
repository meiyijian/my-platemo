"""Run the paper-writing mechanical patterns over added manuscript prose."""
from pathlib import Path
import ast
import difflib
import json
import re
import subprocess

HERE=Path(__file__).resolve().parent
PAPER=HERE.parents[1]
ROOT=PAPER.parent
BASELINE='9c2c4d6'


def main():
    validator=PAPER/'experiments/fe500_convergence/validate_convergence_fe500.py'
    tree=ast.parse(validator.read_text(encoding='utf-8'))
    patterns=next(ast.literal_eval(n.value) for n in ast.walk(tree) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='patterns' for t in n.targets))
    before=subprocess.check_output(['git','show',f'{BASELINE}:论文写作/HPDC-MaOEA.tex'],cwd=ROOT).decode('utf-8')
    current=(PAPER/'HPDC-MaOEA.tex').read_text(encoding='utf-8')
    lines=[]
    for tag,i,j,k,l in difflib.SequenceMatcher(None,before.splitlines(),current.splitlines()).get_opcodes():
        if tag in {'insert','replace'}:
            for n,line in enumerate(current.splitlines()[k:l],k+1):
                if line.strip() and not line.lstrip().startswith('%'):
                    lines.append((n,line))
    raw=[]
    hits={}
    for rule,pattern in patterns.items():
        found=[{'line':n,'match':m.group(),'text':line} for n,line in lines for m in re.finditer(pattern,line,re.I)]
        hits[rule]=found
        raw.append(f'{rule}: {len(found)}')
        raw.extend(f"  L{h['line']}: {h['text']}" for h in found)
    # M14's broad pseudo-suffix pattern matches the standard technical term pairwise.
    justified={}
    for rule,found in hits.items():
        if found:
            if rule=='M14_adverbs' and all(h['match'].lower()=='pairwise' for h in found):
                justified[rule]='pairwise is the established comparison type, not a coined adverb.'
            else:
                raise AssertionError((rule,found))
    sentences=re.split(r'(?<=[.!?])\s+',re.sub(r'\s+',' ',' '.join(line for _,line in lines)))
    # A line diff can concatenate separate partial sentences. Inspect length in the closure review.
    report={'baseline_commit':BASELINE,'changed_prose_lines':len(lines),
            'mechanical_counts':{r:len(v) for r,v in hits.items()},'hits':hits,
            'justifications':justified,'raw_scan_output':raw}
    (HERE/'style_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('\n'.join(raw))
    print('All introduced mechanical hits fixed or explicitly justified.')


if __name__=='__main__':
    main()
