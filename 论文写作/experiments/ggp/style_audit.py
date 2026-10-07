"""Mechanical checks for the changed GGP prose and generated table."""
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
tex = (HERE.parents[1]/'HPDC-MaOEA.tex').read_text(encoding='utf-8')
start = tex.index(r'\subsection{Good-Group Precision Analysis of PAQC}')
end = tex.index(r'\subsection{Effect of Selection-Criterion Switching}', start)
section = tex[start:end]
table = (HERE/'table_ggp.tex').read_text(encoding='utf-8')
appendix = (HERE/'appendix_ggp.tex').read_text(encoding='utf-8')
complete_table = (HERE/'table_ggp_complete.tex').read_text(encoding='utf-8')
conclusion = tex[tex.index('The matched group analysis shows'):tex.index(r'\begin{thebibliography}',tex.index('The matched group analysis shows'))]
text = '\n'.join(line for line in (section+'\n'+table+'\n'+conclusion+'\n'+appendix+'\n'+complete_table).splitlines() if not line.lstrip().startswith('%'))
flat = re.sub(r'\s+', ' ', text)
checks = {
 'M1': r'---|—|–| -- ',
 'M11': r'\b(is|are|was|were|be|been|being)\s+([a-z]+ed|done|made|shown|given|taken|held|built|drawn|chosen|written|known|found|seen|set|put|sent|kept|met|run|used|based)\b',
 'M2': r',? not [0-9A-Za-z\\]|not only .*? but|rather than|less .*? than|is the point|whatever it is|means nothing|more than just|not in competition with|on one hand|on the other hand',
 'M3/M4/M8/M9': r'in effect|in a sense|at (its|the) (heart|core)|in essence|\btruly\b|\bgenuinely\b|\bindeed\b|\bin fact\b|precisely because|a testament to|the kind of .*? that|exactly the kind|is the point|sets? .*? apart|no (predecessor|one) .*? (made|posed)|the key (insight|idea) is|the machine that|draws? .*? power from|under the hood|where .*? meets',
 'M6': r'\b(Moreover|Furthermore|Additionally|Notably|Importantly|Indeed|Ultimately|Crucially|In turn|That said)\b',
 'M5/M16': r'\b(novel|significant|substantial|impressive|promising|comprehensive|robust|powerful|seamless|crucial|paradigm|factor|features?|meaningful|insightful|prestigious|currently|impacts?)\b|\b(leverage|utiliz|finaliz|possess|contact)\w*|[a-z]+-oriented\b',
 'M10': r'promises to|stands? to|is poised to|opens the door to|is set to|has the potential to|keeps .*? from|stands? in the way|\bunlocks?\b',
 'M17': r'\b(pits?|pitted|pitting|dispatch\w*|chip\w* (away )?at|marshal\w*|orchestrat\w*|wrangl\w*|harness\w*|forges?|forged|weav\w*|delve into|usher\w* in|grapple with|anew|afresh)\b',
 'M18': r'In this (paper|section), we',
 'M12': r'the fact that|the question (as to |of )?whether|as to whether|in order to|there is no doubt but|the reason .*? is because|owing to the fact that|in a [a-z]+ manner|is a (subject|man|woman) (that|who)|in the last analysis|along these lines|in terms of|one of the most',
 'M13': r'\b(rather|very|pretty|little|quite|somewhat|fairly|certainly)\b',
 'M14': r'\b(thusly|muchly|overly|firstly|secondly|thirdly)\b|[a-z]+wise\b',
 'M15': r'(?<!\\)!',
 'Part B': r'\bcomprised of\b|\bdata is\b|different than|\bvery unique\b|\bdue to\b|\bless (than )?[0-9]',
}
for rule, pattern in checks.items():
    matches = list(re.finditer(pattern,flat,re.IGNORECASE))
    print(f'{rule}: {len(matches)}')
    for match in matches:
        print('  '+flat[max(0,match.start()-50):match.end()+50])
print('Canonical terms: PAQC; direction control S; representative-margin control A; native binary label L.')
print('Decomposition: two outcomes, three equal-quota rules, eight configurations, 32 comparisons.')
