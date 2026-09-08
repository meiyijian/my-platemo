"""Rebuild the PACDIS manuscript figures from source tables and equations.

Run from any directory:
uv run --with matplotlib --with pandas --with scipy --with pymupdf \
       --with openpyxl python build_figures.py
"""
from pathlib import Path
import hashlib
import json
import re
import sys
import importlib.metadata

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle
from matplotlib.colors import TwoSlopeNorm
from matplotlib.lines import Line2D
from matplotlib.transforms import ScaledTranslation
import pymupdf
import openpyxl

OUT = Path(__file__).resolve().parent
REPO = OUT.parents[1]
EXPS = REPO / 'PlatEMO-master/PlatEMO/Experiments'
ALG = REPO / 'PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Original'
DATA = OUT / 'source_data'
QA = OUT / 'qa'
DATA.mkdir(exist_ok=True)
QA.mkdir(exist_ok=True)
ORIGINAL = ['DTLZ2', 'DTLZ4', 'DTLZ7', 'WFG3', 'WFG7']
PROBLEMS = ['DTLZ2', 'DTLZ7', 'WFG3', 'WFG7']
ARMS = ['V0_REMO_RULE', 'V1_POOL_ONLY', 'V2_EXPLORE_ONLY', 'V3_INDICATOR_ONLY', 'V4_FULL']
ARM_LABELS = ['V0', 'V1', 'V2', 'V3', 'V4']
BLUE = '#24658C'
ORANGE = '#AD5F25'
PURPLE = '#776193'
TEAL = '#28756B'
INK = '#253442'
GRAY = '#6D7680'
LIGHT = '#D8DEE4'
COLORS = [GRAY, '#414B54', BLUE, ORANGE, TEAL]
MARKERS = ['o', 's', '^', 'D', 'P']
plt.rcParams.update({
    'font.family': 'sans-serif', 'font.sans-serif': ['Arial', 'DejaVu Sans'],
    'font.size': 8, 'axes.titlesize': 9, 'axes.labelsize': 8,
    'xtick.labelsize': 7.5, 'ytick.labelsize': 7.5,
    'legend.fontsize': 7.5, 'text.color': INK, 'axes.labelcolor': INK,
    'axes.edgecolor': GRAY, 'xtick.color': INK, 'ytick.color': INK,
    'axes.spines.top': False, 'axes.spines.right': False,
    'axes.linewidth': .65, 'lines.linewidth': 1.2,
    'pdf.fonttype': 42, 'ps.fonttype': 42, 'svg.fonttype': 'none',
    'savefig.facecolor': 'white', 'figure.facecolor': 'white',
    'mathtext.fontset': 'dejavusans', 'legend.frameon': False,
})
MANIFEST = {'seed': 20260906, 'figures': [], 'sources': [], 'checks': {}}


def source(path):
    path = Path(path)
    MANIFEST['sources'].append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    return path


def panel(ax, letter, title):
    ax.set_title(title, loc='left', pad=9, fontweight='bold')
    transform = ax.transAxes + ScaledTranslation(-10/72, 0, ax.figure.dpi_scale_trans)
    ax.text(0, 1.055, letter, transform=transform, fontweight='bold', fontsize=10, va='bottom')


def save(fig, name, claim, kind, notes):
    fig.canvas.draw()
    renderer = fig.canvas.get_renderer()
    outside = []
    for txt in fig.findobj(matplotlib.text.Text):
        if not txt.get_visible() or not txt.get_text():
            continue
        box = txt.get_window_extent(renderer)
        if box.x0 < -1 or box.y0 < -1 or box.x1 > fig.bbox.x1 + 1 or box.y1 > fig.bbox.y1 + 1:
            outside.append(txt.get_text())
    if outside:
        raise ValueError(f'{name}: text outside canvas: {outside}')
    fig.savefig(OUT / f'{name}.pdf', dpi=600, facecolor='white')
    fig.savefig(OUT / f'{name}.svg', dpi=600, facecolor='white')
    fig.savefig(OUT / f'{name}.png', dpi=600, facecolor='white')
    doc = pymupdf.open(OUT / f'{name}.pdf')
    page = doc[0]
    spans = [s for b in page.get_text('dict')['blocks'] if 'lines' in b for l in b['lines'] for s in l['spans'] if s['text'].strip()]
    minimum = min(s['size'] for s in spans)
    if minimum < 4.99:
        raise ValueError(f'{name}: glyph below 5 pt: {minimum}')
    pix = page.get_pixmap(matrix=pymupdf.Matrix(1.8, 1.8), alpha=False)
    pix.save(QA / f'{name}_render.png')
    MANIFEST['figures'].append({
        'name': name, 'claim': claim, 'archetype': kind,
        'width_mm': round(fig.get_figwidth()*25.4, 2),
        'height_mm': round(fig.get_figheight()*25.4, 2),
        'minimum_pdf_glyph_pt': round(minimum, 2),
        'pdf_text_spans': len(spans), 'notes': notes,
        'text_outside_canvas': outside,
    })
    plt.close(fig)


def canvas(height):
    fig = plt.figure(figsize=(180/25.4, height/25.4))
    ax = fig.add_axes([0, 0, 1, 1], xlim=(0,180), ylim=(0,height))
    ax.axis('off')
    return fig, ax


def box(ax, xy, wh, title, body='', color=GRAY, fill='#F4F6F8', title_size=8.5, body_size=8):
    x, y = xy
    w, h = wh
    ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle='round,pad=0.0,rounding_size=1.4',
                              facecolor=fill,edgecolor=color,linewidth=.85))
    if body:
        ax.text(x+w/2,y+h-4.4,title,ha='center',va='center',fontsize=title_size,fontweight='bold',color=color)
        ax.text(x+w/2,y+(h-5.3)/2,body,ha='center',va='center',fontsize=body_size,linespacing=1.4)
    else:
        ax.text(x+w/2,y+h/2,title,ha='center',va='center',fontsize=title_size,fontweight='bold',color=color)


def arrow(ax, pts, color=GRAY, style='-', width=.95):
    for a,b in zip(pts[:-2],pts[1:-1]):
        ax.plot([a[0],b[0]],[a[1],b[1]],color=color,lw=width,ls=style)
    ax.add_patch(FancyArrowPatch(pts[-2],pts[-1],arrowstyle='-|>',mutation_scale=8,
                               color=color,lw=width,linestyle=style,shrinkA=0,shrinkB=1))


def framework():
    from build_framework_flowchart import draw_framework
    fig = draw_framework()
    save(fig, 'fig_framework',
         'PACDIS evaluation loop with explicit budget, candidate-search, and mode decisions.',
         'method-level flowchart',
         'Compact nodes and Yes/No branches; c counts generated candidates. Mode is drawn before inner search. Detailed safeguards remain in the manuscript.')
    svg_path = OUT / 'fig_framework.svg'
    svg_path.write_text('\n'.join(line.rstrip() for line in svg_path.read_text(encoding='utf-8').splitlines())+'\n', encoding='utf-8')

def grouping():
    fig = plt.figure(figsize=(180/25.4,124/25.4))
    gs=fig.add_gridspec(2,2,left=.075,right=.98,bottom=.16,top=.925,hspace=.65,wspace=.32)
    a=fig.add_subplot(gs[0,0]); b=fig.add_subplot(gs[0,1])
    for ax in [a,b]:
        ax.set_xlim(0,3.7); ax.set_ylim(0,3.25); ax.set_aspect('equal')
        ax.set_xticks([]); ax.set_yticks([])
        ax.set_xlabel(r'Translated objective $f_1-z_1^*$',fontsize=8)
        ax.set_ylabel(r'Translated objective $f_2-z_2^*$',fontsize=8)
    panel(a,'a','Continuous directional quality')
    v=np.array([.8,.6]); point=np.array([1.35,2.55]); d1=point@v; proj=d1*v
    a.plot([0,3.5*v[0]],[0,3.5*v[1]],color=BLUE,lw=1.2)
    a.text(2.85,2.1,r'$\mathbf{v}$',color=BLUE,fontsize=10)
    a.plot([point[0],proj[0]],[point[1],proj[1]],'--',color=ORANGE)
    a.scatter(*point,s=29,c=INK,zorder=4); a.scatter(*proj,s=20,facecolor='white',edgecolor=BLUE,zorder=4)
    a.text(point[0]-.25,point[1]+.15,r'$\mathbf{f}_i-\mathbf{z}^*$',fontsize=8.5)
    a.text(.65,.39,r'$d_1$',fontsize=10,color=BLUE)
    a.text(1.82,2.11,r'$d_2$',fontsize=10,color=ORANGE)
    a.text(.03,3.0,r'$S_i=(1+d_{1,i}+\theta d_{2,i})^{-1}$',fontsize=9)
    a.text(0,0,r'$0$',fontsize=8,ha='right',va='top')
    panel(b,'b','Representative-relative boundary')
    # One associated representative, z*=0 and delta=1: exact local analytic boundary.
    r=np.array([1.7,1.7]); normr=np.linalg.norm(r); w=r/normr
    xx=np.linspace(0,3.7,250); yy=np.linspace(0,3.25,240)
    X,Y=np.meshgrid(xx,yy); D1=X*w[0]+Y*w[1]
    D2=np.sqrt(np.maximum(0,X*X+Y*Y-D1*D1))
    G=(D1+D2)/normr
    b.contourf(X,Y,G,levels=[-1,1,10],colors=['#EAF3F7','#F8F3ED'],alpha=.9)
    b.contour(X,Y,G,levels=[1],colors=[ORANGE],linewidths=1.2)
    b.plot([0,2.5],[0,2.5],'--',color=GRAY,lw=.8)
    b.scatter(*r,marker='D',s=30,color=ORANGE,zorder=4)
    b.text(1.90,1.50,r'$\mathbf{r}$',fontsize=10,color=ORANGE)
    b.text(.45,.9,r'$L=1$',fontsize=10,color=BLUE)
    b.text(2.35,1.5,r'$L=0$',fontsize=10,color=ORANGE)
    b.text(.04,2.95,r'$\hat d_1+\delta\hat d_2=\|\mathbf{r}-\mathbf{z}^*\|_2$',fontsize=8.8)
    b.text(.08,2.5,r'One region; illustrative $\delta=1$',fontsize=7.5)
    c=fig.add_subplot(gs[1,0]); d=fig.add_subplot(gs[1,1])
    panel(c,'c','Hybrid score: H = (1−t)S + tL')
    S=np.array([.94,.83,.72,.61,.48,.36,.22,.10]); L=np.array([0,0,1,0,1,0,1,1])
    times=np.linspace(0,1,201)
    for i in [0,2,4,6]:
        clr=BLUE if L[i]==0 else ORANGE
        ls='--' if L[i]==0 else '-'
        c.plot(times,(1-times)*S[i]+times*L[i],ls=ls,color=clr,lw=1.2,alpha=1 if i in [0,2] else .7)
        x=.68; y=(1-x)*S[i]+x*L[i]
        c.text(x+.02,y+.018,f'{chr(65+i)}',color=clr,fontsize=7.5)
    c.axvspan(.5,1,color='#F2F4F5',zorder=-5)
    c.axvline(.5,color=GRAY,ls=':',lw=.8)
    c.set(xlim=(0,1.02),ylim=(0,1.04),xlabel=r'Budget progress $t$',ylabel='Hybrid score H')
    c.set_xticks([0,.25,.5,.75,1]); c.set_yticks([0,.5,1])
    c.text(.75,.47,'Binary-positive priority\nfor 0.5 ≤ t < 1',ha='center',fontsize=7.3)
    panel(d,'d','Top-quarter group from eight solutions')
    tgrid=np.array([0,.25,.5,.75]); H=(1-tgrid[:,None])*S+tgrid[:,None]*L
    selected=np.zeros_like(H,dtype=bool)
    for row in range(len(tgrid)):
        selected[row,np.argsort(-H[row],kind='stable')[:2]]=True
    d.set_xlim(-.5,7.5);d.set_ylim(3.5,-.5)
    for ri in range(4):
        for ci in range(8):
            d.add_patch(Rectangle((ci-.5,ri-.5),1,1,facecolor='#DCEBE7' if selected[ri,ci] else '#F5F6F7',edgecolor='none'))
            d.text(ci,ri,f'{H[ri,ci]:.2f}',ha='center',va='center',fontsize=7.4,color=TEAL if selected[ri,ci] else GRAY,
                   fontweight='bold' if selected[ri,ci] else 'normal')
            if selected[ri,ci]:
                d.add_patch(Rectangle((ci-.49,ri-.47),.98,.94,fill=False,edgecolor=TEAL,lw=1.1))
    d.set_xticks(range(8),[f'{chr(65+i)}\nL={L[i]}' for i in range(8)],fontsize=7.4)
    d.set_yticks(range(4),[f't={t:g}' for t in tgrid]); d.tick_params(length=0)
    for sp in d.spines.values():sp.set_visible(False)
    d.text(.5,-.32,'Outlined cells enter the positive group (2/8).',transform=d.transAxes,ha='center',fontsize=7.5)
    fig.text(.5,.022,'Analytical illustration of the definitions; values and geometry are not experimental observations.',ha='center',fontsize=7.5,color=GRAY)
    pd.DataFrame({'ID':list('ABCDEFGH'),'S':S,'L':L}).to_csv(DATA/'analytic_grouping_inputs.csv',index=False)
    pd.DataFrame(H,index=tgrid,columns=list('ABCDEFGH')).to_csv(DATA/'analytic_hybrid_scores.csv',index_label='t')
    assert all(np.all(H[i,L==1,None]>H[i,L==0]) for i in [2,3])
    save(fig,'fig_hybrid_grouping','A continuous score refines binary-group order and a bounded schedule induces group priority.',
         'schematic-led composite','Panels a,b use translated geometry after association. Panel b fixes delta=1; production delta is adapted and can be negative. At t=1, only L remains. Example S values are analytic inputs, not measured outcomes.')


def candidate():
    fig,ax=canvas(113)
    box(ax,(7,94),(166,15),'Draw one mode per outer iteration',
        'Indicator available: each mode has probability 0.5; otherwise use exploration.',INK,'#F4F6F8',body_size=8)
    arrow(ax,[(46,94),(46,87)],BLUE); arrow(ax,[(134,94),(134,87)],ORANGE)
    box(ax,(7,65),(78,22),'Exploration: relation-guided search',
        'Sharpness-weighted pair averages → variation\nAccumulate offspring; deduplicate the candidate pool',BLUE,'#EDF4F8')
    box(ax,(95,65),(78,22),'Indicator: relation-guided search',
        'Unweighted pair averages → variation\nAccumulate offspring; deduplicate the candidate pool',ORANGE,'#FBF2E9')
    arrow(ax,[(46,65),(46,59)],BLUE); arrow(ax,[(134,65),(134,59)],ORANGE)
    box(ax,(7,39),(78,20),'Acquisition and quantile filtering',
        r'$A_{\mathrm{exp}}=\widetilde R+\lambda_t\widetilde U$'+'\nWeight decreases with progress and model error',BLUE,'#EDF4F8',body_size=9)
    box(ax,(95,39),(78,20),'Relation filter → indicator reranking',
        r'Top relation scores → predicted indicator $\widehat I$'+'\nRetain candidates above the indicator quantile',ORANGE,'#FBF2E9',body_size=8)
    arrow(ax,[(46,39),(46,33)],BLUE); arrow(ax,[(134,39),(134,33)],ORANGE)
    box(ax,(7,18),(78,15),'Greedy batch construction',
        'Acquisition quality + distance from selected decisions',BLUE,'#EDF4F8',body_size=7.8)
    box(ax,(95,18),(78,15),'Ordered batch construction',
        'Select by descending predicted indicator',ORANGE,'#FBF2E9',body_size=8)
    arrow(ax,[(46,18),(46,14),(90,14),(90,11)])
    arrow(ax,[(134,18),(134,14),(90,14),(90,11)])
    box(ax,(18,1),(144,10),r'Retained-set and remaining-budget bound: $|\mathcal{S}|=\min(n_{\max},|\mathcal{H}^{m}|,FE_{\max}-FE)$',
        color=INK,title_size=8.8)
    save(fig,'fig_candidate_selection','An iteration uses one mode-specific search and ranking criterion with an explicit evaluation cap.',
         'schematic-led composite','The two branches denote alternative executions, not a shared fixed pool or parallel selections. Empty-pool variation and prediction-failure fallbacks are specified in the algorithm and source.')


def bootstrap_stratified(frame, value_cols, strata, seed=20260906, B=4000):
    """Equal-weight fixed configurations; resample whole paired runs within each."""
    rng=np.random.default_rng(seed)
    estimates=[]
    for _, group in frame.groupby(strata,sort=True):
        values=group[value_cols].to_numpy(float)
        assert np.isfinite(values).all()
        n=len(values)
        estimates.append(values[rng.integers(0,n,size=(B,n))].mean(axis=1))
    boot=np.mean(estimates,axis=0)
    center=frame.groupby(strata,sort=True)[value_cols].mean().mean().to_numpy()
    ci=np.quantile(boot,[.025,.975],axis=0)
    return center,ci


def group_evidence():
    src=source(EXPS/'REMO_new2_AdaMaO_GoodGroupPrecision/results/analysis/formal/GGP_PerRunStage.csv')
    raw=pd.read_csv(src)
    g=raw[(raw.Truth=='population_final') & (raw.SelectionRule=='top25') & raw.Problem.isin(ORIGINAL)].copy()
    views=['score_hybrid','score_v','anchor_margin']
    g=g[g.View.isin(views)]
    assert len(g)==3000 and g.M.isin([10,20]).all() and g.MeanPrecision.notna().all()
    assert g.groupby(['Problem','M','Run','Stage','View']).size().eq(1).all()
    g.to_csv(DATA/'group_precision_original_five.csv',index=False)
    stages=sorted(g.Stage.unique())
    p=g.pivot(index=['Problem','M','Run','Seed','Stage'],columns='View',values='MeanPrecision').reset_index()
    p['Hybrid - Direction']=p.score_hybrid-p.score_v
    p['Hybrid - Margin']=p.score_hybrid-p.anchor_margin
    p.to_csv(DATA/'group_precision_paired.csv',index=False)
    summary=[]
    for stage in stages:
        z=p[p.Stage==stage]
        assert len(z)==250
        cols=views+['Hybrid - Direction','Hybrid - Margin']
        center,ci=bootstrap_stratified(z,cols,['Problem','M'])
        for i,col in enumerate(cols):summary.append({'stage':stage,'view':col,'mean':center[i],'low':ci[0,i],'high':ci[1,i],'n':250})
    s=pd.DataFrame(summary);s.to_csv(DATA/'group_precision_summary.csv',index=False)
    expected=np.array([[.08547,.05949,.07949],[.11804,.10751,.12414],[.29011,.28834,.27126],[.65431,.65458,.62980]])
    observed=np.array([[s[(s.stage==st)&(s.view==v)]['mean'].iloc[0] for v in views] for st in stages])
    assert np.allclose(expected,observed,atol=6e-6)
    fig,axs=plt.subplots(1,2,figsize=(180/25.4,85/25.4),gridspec_kw={'left':.085,'right':.97,'bottom':.24,'top':.82,'wspace':.32})
    panel(axs[0],'a','Final-population retention');panel(axs[1],'b','Paired precision differences')
    xs=np.arange(4)
    for v,label,color,marker,shift in zip(views,['Hybrid','Direction','Margin'],[TEAL,BLUE,ORANGE],['o','s','^'],[-.16,0,.16]):
        z=s[s.view==v]; y=z['mean'].to_numpy(); lo=z.low.to_numpy();hi=z.high.to_numpy()
        axs[0].errorbar(xs+shift,y,yerr=[y-lo,hi-y],color=color,marker=marker,lw=1,capsize=2,label=label,ms=4)
    axs[0].set(ylabel='Precision@25%',ylim=(0,.74));axs[0].legend(loc='upper left')
    diff_names=['Hybrid - Direction','Hybrid - Margin']
    for name,color,marker,shift in zip(diff_names,[BLUE,ORANGE],['s','^'],[-.08,.08]):
        z=s[s.view==name];y=z['mean'].to_numpy()*100;lo=z.low.to_numpy()*100;hi=z.high.to_numpy()*100
        axs[1].errorbar(xs+shift,y,yerr=[y-lo,hi-y],color=color,marker=marker,capsize=2,ms=4,label=name)
    axs[1].axhline(0,color=GRAY,lw=.8,ls='--');axs[1].set_ylabel('Precision difference (percentage points)')
    axs[1].legend(loc='upper left',bbox_to_anchor=(0,1.08),fontsize=7.1)
    axs[1].set_ylim(-2.2,4.7)
    for ax in axs:
        ax.set_xticks(xs,['0–0.25','0.25–0.50','0.50–0.75','0.75–1.00'],rotation=25,ha='right',rotation_mode='anchor')
        ax.set_xlabel(r'Budget stage $FE/FE_{\max}$');ax.grid(axis='y',lw=.45,color=LIGHT,alpha=.65)
    fig.text(.5,.935,'Original five-problem study  |  250 runs  |  M = 10, 20  |  FE budget = 500',ha='center',fontsize=8.2)
    fig.text(.5,.035,'Means and 95% stratified bootstrap CIs; checkpoints averaged within each run and stage.',ha='center',fontsize=7.5)
    MANIFEST['checks']['group_rows']={'before':len(raw),'included':len(g),'paired_run_stages':len(p),'scope':'original five problems, population_final, top25, three views'}
    save(fig,'fig_group_evidence','Retention association varies by stage, including reversals relative to a single-view comparator.',
         'quantitative grid','Fixed original 10 configurations, 25 trajectories each. 4000 percentile-bootstrap draws resample paired runs within configuration. Four stage estimates each use 250 runs. No causal or endpoint IGD inference; 5 newly added problems excluded to match manuscript protocol.')


def candidate_evidence():
    src=source(EXPS/'REMO_new2_AdaMaO_CandidateValueProbe/docs/data/runs.csv')
    raw=pd.read_csv(src)
    assert len(raw)==200 and raw.meta_M.eq(20).all() and raw.meta_CompletedFE.eq(300).all()
    assert raw.groupby(['Problem','Arm']).size().eq(10).all()
    metrics=['BatchSizeMean','BatchSpreadMean','SurvivalRateLate','OracleGainRatioLate']
    assert raw[metrics+['IGD']].notna().all().all()
    raw.to_csv(DATA/'candidate_runs.csv',index=False)
    summary=[]
    for arm in ARMS:
        center,ci=bootstrap_stratified(raw[raw.Arm==arm],metrics,['Problem'])
        for i,metric in enumerate(metrics):summary.append({'arm':arm,'metric':metric,'mean':center[i],'low':ci[0,i],'high':ci[1,i]})
    s=pd.DataFrame(summary);s.to_csv(DATA/'candidate_summary.csv',index=False)
    genpath=source(EXPS/'REMO_new2_AdaMaO_CandidateValueProbe/docs/data/generations.csv')
    gen=pd.read_csv(genpath)
    regular=gen[(gen.Arm!='V0_REMO_RULE') & (gen.TruncatedBatch==0)]
    assert len(regular)==5280 and regular.BatchSize.eq(6).all()
    assert gen[(gen.Arm!='V0_REMO_RULE') & (gen.TruncatedBatch==1)].BatchSize.eq(2).all()
    fig=plt.figure(figsize=(180/25.4,136/25.4))
    gs=fig.add_gridspec(2,4,left=.10,right=.98,bottom=.24,top=.86,hspace=.58,wspace=.9,height_ratios=[1,1])
    titles=['Batch size','Batch spread','Late retention','Late gain ratio']
    ys=['Candidates / iteration','Normalized decision distance','Accepted / evaluated','Gain / greedy-reference gain']
    rng=np.random.default_rng(20260906)
    for j,metric in enumerate(metrics):
        ax=fig.add_subplot(gs[0,j]);panel(ax,chr(97+j),titles[j])
        for i,arm in enumerate(ARMS):
            vals=raw[raw.Arm==arm][metric].to_numpy()
            ax.scatter(i+rng.uniform(-.16,.16,len(vals)),vals,s=5,color=COLORS[i],alpha=.23,edgecolors='none',zorder=1)
            z=s[(s.arm==arm)&(s.metric==metric)].iloc[0]
            ax.errorbar(i,z['mean'],yerr=[[z['mean']-z.low],[z.high-z['mean']]],color=COLORS[i],marker=MARKERS[i],capsize=2,ms=4,lw=1.3,zorder=3)
        ax.set_xticks(range(5),ARM_LABELS,fontsize=7.5);ax.set_ylabel(ys[j],fontsize=7.6)
        ax.grid(axis='y',color=LIGHT,lw=.4)
        ax.set_ylim(bottom=0)
        if j==0:
            ax.axhline(6,color=GRAY,ls=':',lw=.8)
        if j==2:ax.set_ylim(0,1)
    ax=fig.add_subplot(gs[1,:]);panel(ax,'e','Final IGD relative to relation top-six (paired runs)')
    p=raw.pivot(index=['Problem','Run'],columns='Arm',values='IGD')
    ratios=[]
    # The geometric mean is used only for paired IGD ratios on a log axis.
    for pi,problem in enumerate(PROBLEMS):
        block=p.loc[problem]
        for ai,arm in enumerate([ARMS[0],ARMS[2],ARMS[3],ARMS[4]]):
            x=pi+(ai-1.5)*.18
            v=(block[arm]/block[ARMS[1]]).to_numpy()
            assert (v>0).all(), 'All IGD ratios must be strictly positive before taking logarithms.'
            lv=np.log(v);boot=lv[rng.integers(0,len(lv),size=(4000,len(lv)))].mean(axis=1)
            center=np.exp(lv.mean());lo,hi=np.exp(np.quantile(boot,[.025,.975]))
            armindex=ARMS.index(arm)
            ax.scatter(x+rng.uniform(-.028,.028,len(v)),v,s=7,color=COLORS[armindex],alpha=.35,zorder=1)
            ax.errorbar(x,center,yerr=[[center-lo],[hi-center]],color=COLORS[armindex],marker=MARKERS[armindex],capsize=2,ms=4,zorder=3)
            for run,val in zip(block.index,v):ratios.append({'Problem':problem,'Run':int(run),'Arm':arm,'IGD_ratio_to_V1':val})
    ax.axhline(1,color=GRAY,lw=.85,ls='--');ax.set_yscale('log',base=2)
    ax.set_yticks([.5,1,2,4],['0.5','1','2','4']);ax.set_ylim(.38,4.3)
    ax.set_xticks(range(4),PROBLEMS);ax.set_ylabel('IGD / IGD of V1\n(log scale; lower is better)',fontsize=8)
    ax.grid(axis='y',color=LIGHT,lw=.45)
    ax.set_xlim(-.65,3.65)
    handles=[Line2D([],[],color=c,marker=m,ls='',ms=4,label=label) for c,m,label in zip(COLORS,MARKERS,
             ['V0: REMO rule','V1: relation top-six','V2: exploration','V3: indicator','V4: CDIS'])]
    fig.legend(handles=handles,loc='lower center',bbox_to_anchor=(.5,.10),ncol=3,columnspacing=1.4,handletextpad=.5,fontsize=7.6)
    fig.text(.5,.945,'Candidate-value probe  |  4 problems × 5 policies × 10 runs  |  M = 20  |  FE budget = 300',ha='center',fontsize=8.2)
    fig.text(.5,.065,'a–d: 40 run values per policy; means and 95% stratified bootstrap CIs.',ha='center',fontsize=7.5)
    fig.text(.5,.038,'e: 10 paired IGD ratios per problem and policy; geometric means and 95% bootstrap CIs.',ha='center',fontsize=7.5)
    pd.DataFrame(ratios).to_csv(DATA/'candidate_igd_paired_ratios.csv',index=False)
    MANIFEST['checks']['candidate']={'runs':len(raw),'regular_capped_batches':len(regular),'all_regular_capped_batches_equal_six':True,'all_truncated_capped_batches_equal_two':True}
    save(fig,'fig_candidate_evidence','Batch properties differ among criteria, while endpoint IGD gains are problem-dependent.',
         'quantitative grid','All 200 runs. Dots are run-level observations. For a-d fixed problems are equally weighted and whole runs are bootstrapped within problem; e bootstraps paired log ratios by seed within problem. Late metrics use FE/maxFE>=0.5; all-trajectory batch metrics include truncated final batches. V0 is a transplanted selection rule. Sampled-pool gain is an offline diagnostic.')


def performance():
    base=Path.home()/'Desktop/AdaMao实验表/最新版算法总实验'
    rows=[]; matrices=[]; names=[]
    for m in [10,20]:
        path=source(base/f'{m}目标.xlsx')
        wb=openpyxl.load_workbook(path,read_only=True,data_only=True)
        table=list(wb[wb.sheetnames[0]].values);wb.close()
        h=table[0];algs=h[5:-1]; target=h[-1]; mat=[]; probs=[]
        def parse(x):
            match=re.fullmatch(r'\s*([\d.]+e[+-]\d+)\s*\(([\d.]+e[+-]\d+)\)\s*([+=-])?\s*',str(x),re.I)
            if not match:raise ValueError(x)
            return float(match[1]),float(match[2]),match[3]
        for r in table[1:]:
            if not re.fullmatch(r'(DTLZ|WFG)\d+',str(r[0])):continue
            assert r[1]==100 and r[2]==m and r[4]==300
            probs.append(r[0]);own,ownsd,_=parse(r[-1]);vals=[]
            for a,x in zip(algs,r[5:-1]):
                mean,sd,sign=parse(x); ratio=own/mean
                vals.append(np.log2(ratio))
                rows.append({'M':m,'Problem':r[0],'Comparator':a,'Comparator_mean':mean,'Comparator_SD':sd,
                             'HPDC_mean':own,'HPDC_SD':ownsd,'IGD_ratio':ratio,'log2_ratio':np.log2(ratio),'source_symbol':sign})
            mat.append(vals)
        assert len(mat)==16 and len(algs)==7
        matrices.append(np.array(mat));names.append((probs,[x.replace('HES_EA','HES-EA') for x in algs]))
    data=pd.DataFrame(rows);data.to_csv(DATA/'performance_mean_ratios.csv',index=False)
    limit=max(abs(data.log2_ratio.min()),abs(data.log2_ratio.max()))
    cmap=matplotlib.colors.LinearSegmentedColormap.from_list('benefit', ['#216C69','#FAFAFA','#AF633E'])
    fig,axs=plt.subplots(1,2,figsize=(180/25.4,137/25.4),gridspec_kw={'left':.105,'right':.97,'bottom':.23,'top':.90,'wspace':.33})
    for j,(ax,mat,(probs,algs)) in enumerate(zip(axs,matrices,names)):
        im=matplotlib.cm.ScalarMappable(norm=TwoSlopeNorm(vmin=-limit,vcenter=0,vmax=limit),cmap=cmap)
        ax.set_xlim(-.5,6.5);ax.set_ylim(15.5,-.5)
        panel(ax,chr(97+j),f'M = {[10,20][j]}')
        ax.set_xticks(range(7),algs,rotation=35,ha='right',rotation_mode='anchor',fontsize=7.5)
        ax.set_yticks(range(16),probs,fontsize=7.5);ax.tick_params(length=0)
        for ri in range(16):
            for ci in range(7):
                ax.add_patch(Rectangle((ci-.5,ri-.5),1,1,facecolor=cmap(im.norm(mat[ri,ci])),edgecolor='none'))
                suffix='*' if j==0 and ri==0 and algs[ci] in ['PCSAEA','KRVEA'] else ''
                rgb=np.array(cmap(im.norm(mat[ri,ci])))[:3]
                linear=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
                luminance=float(linear@np.array([.2126,.7152,.0722]))
                color='white' if luminance<.179 else 'black'
                ax.text(ci,ri,f'{2**mat[ri,ci]:.2f}{suffix}',ha='center',va='center',fontsize=6.9,color=color)
        for sp in ax.spines.values():sp.set_visible(False)
    cbax=fig.add_axes([.31,.095,.40,.017]);cb=fig.colorbar(im,cax=cbax,orientation='horizontal')
    cb.solids.set_rasterized(False)
    cb.solids.set_edgecolor('face')
    ticks=[x for x in [-2,-1,0,1,2] if -limit<=x<=limit]
    cb.set_ticks(ticks,labels=[f'{2.**x:g}' for x in ticks]);cb.ax.tick_params(labelsize=7.5)
    cb.set_label(r'Mean IGD of PACDIS / comparator ($\log_2$ color scale)',fontsize=8,labelpad=2)
    fig.text(.5,.975,'Main-comparison overview  |  all 16 problems per objective count  |  FE budget = 300',ha='center',fontsize=8.3)
    fig.text(.5,.012,'Ratio < 1 favors PACDIS. * Identical source entries awaiting provenance check; no significance encoded.',ha='center',fontsize=7.3)
    save(fig,'fig_performance_overview','Mean IGD ratios reveal problemwise gains and counterexamples across all reported comparisons.',
         'quantitative grid','Supplementary descriptive overview, 224 cells. Original workbook values and symbols exported in source CSV; symbols not interpreted as newly computed tests. No interval because independent-run data are not available for these workbooks. Full means and SDs remain in the manuscript tables. No color clipping.')


def gallery():
    figures=MANIFEST['figures']
    fig,axs=plt.subplots(3,2,figsize=(13,15),facecolor='white')
    for i,(ax,item) in enumerate(zip(axs.flat,figures)):
        img=plt.imread(QA/f"{item['name']}_render.png")
        ax.imshow(img);ax.axis('off');ax.set_title(f"{'S1' if i==5 else i+1}. {item['name']}",fontsize=11,pad=5)
    fig.subplots_adjust(left=.015,right=.985,bottom=.015,top=.985,hspace=.16,wspace=.06)
    fig.savefig(OUT/'figure_gallery.png',dpi=300,facecolor='white');plt.close(fig)
    combined=pymupdf.open()
    for item in figures:
        doc=pymupdf.open(OUT/f"{item['name']}.pdf");combined.insert_pdf(doc);doc.close()
    combined.save(OUT/'HPDC-MaOEA_figure_collection.pdf');combined.close()


if __name__=='__main__':
    for file in ['REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m','ResolveUniformMixMode.m','private/PBIQualityClassification.m','private/RepresentativeBasedClassification.m','private/DiversifiedInfillSelection.m','private/IndicatorSelectorSDEOnly.m']:
        source(ALG/file)
    for fn in [framework,grouping,candidate,group_evidence,candidate_evidence,performance]:
        print('Building',fn.__name__,flush=True);fn()
    gallery()
    MANIFEST['versions']={x:importlib.metadata.version(x) for x in ['matplotlib','numpy','pandas','scipy','pymupdf','openpyxl']}
    (OUT/'requirements-figures.txt').write_text(''.join(f'{k}=={v}\n' for k,v in MANIFEST['versions'].items()),encoding='utf-8')
    (OUT/'manifest.json').write_text(json.dumps(MANIFEST,indent=2,ensure_ascii=False),encoding='utf-8')
    print(json.dumps(MANIFEST['checks'],indent=2))
    print('Saved',len(MANIFEST['figures']),'figures, gallery, source data, and collection PDF.')
