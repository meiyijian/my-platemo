function reg = fe500_m20_registry()
%FE500_M20_REGISTRY Single source of truth for the seven-algorithm FE500 sweep.
%
%   REG = FE500_M20_REGISTRY() returns a struct array with one row per
%   algorithm. Every other script of this experiment (runner, driver, prober,
%   verifier) reads its algorithm list from HERE, so the class names, the
%   output folders and the parameter vectors can never drift apart.
%
%   Fields
%     key     short handle used on the command line / in the driver
%     folder  sub-folder created inside <OutputRoot> (one per algorithm)
%     cls     MATLAB class actually instantiated
%     params  cell passed as the algorithm's 'parameter' ({} = class defaults)
%     note    why this class and not another one
%
%   ---- Protocol of the whole experiment ----------------------------------
%     problems  DTLZ1..DTLZ7 + WFG1..WFG9        (16, DTLZ first)
%     M         20
%     N         100 (fixed initial design)
%     D         30  requested  ->  WFG2/WFG3 report D=31 (WFG fixes L=D-K to
%                                 be even), every other problem reports D=30
%     maxFE     500
%     save      30 snapshots
%     runs      1..20
%     metrics   runtime + IGD + IGDp, all three as full snapshot traces
%     seed      22260912 + 1000*problemIndex + runId   with rng(seed,'twister')
%               applied BEFORE the problem object is constructed;
%               22260912 = 20260912 + 20*100000, i.e. exactly the formula the
%               rest of the 20-objective dataset uses, so FE500 and the
%               existing FE300 batches stay PAIRED run-by-run.
%     output    D:\REMOandDREMO测试集\20目标\FE500\<folder>\<cls>_<prob>_M20_D<D>_<run>.mat
%
%   ---- Why these classes (all decisions measured, not guessed) ------------
%     REMO        D=30 > 10 makes the class pick N=100 by itself, so the
%                 published class already satisfies the N=100 protocol.
%                 Hyper-parameters stay at the published defaults {k,gmax}
%                 = {6,3000}; passing the house five-element vector here would
%                 silently set k=3000 / gmax=0.50.
%     PCSAEA      ORIGINAL published class, by explicit user instruction.
%                 Its initial design is NI = 11*D-1 = 329, which is 66% of the
%                 maxFE=500 budget, leaving 171 true evaluations for the main
%                 loop. (Under the old maxFE=300 budget this class was unusable:
%                 329 > 300, the main loop never ran and the stored run was a
%                 bare initial design. At FE500 it does run.) See the
%                 FE500_*_FE_PROFILE notes printed by verify_FE500_M20.
%     CSEA        N = min(11*D-1,109) = 109 <= 500, runs as published.
%     HES_EA      ORIGINAL published class, by explicit user instruction.
%                 Initial design 11*D-1 = 329, so ~171 FE remain for evolution.
%                 !! KNOWN DEFECT, see the WARNING block below !!
%     SSDE        N = Problem.N = 100 through Problem.Initialization().
%     SAMOEA      ORIGINAL published class, by explicit user instruction.
%                 NI = 11*D-1 = 329, so ~171 FE remain for infill (34 generations
%                 at KE=5).
%     PACDIS      the paper's own algorithm, house hyper-parameters
%                 {gmax,pMix,rGood,qKeep,nMax} = {3000,0.50,0.25,0.70,6}.
%
%   ---- WARNING: HES_EA can hang (established in this project) -------------
%     HES_EA / HES_EA_N100 share one shared cluster-assignment block. When the
%     two randomly projected objectives share a minimiser (DTLZ2 and DTLZ4 do),
%     that solution's normalised pair is exactly zero, pdist2(...,'cosine')
%     returns NaN and the row can end up with Cluster == 0. CSS is then asked
%     for N rows but can never select an unassigned one, so its "while" loop
%     spins forever while FE does not advance: measured earlier at M=20 this
%     killed ~12% of runs (DTLZ2/DTLZ3/DTLZ4/DTLZ6) and blocked a whole 12-slot
%     pool. HES_EA_N100_guard is a byte-faithful copy plus one orphan-assignment
%     guard and is the only variant that has ever finished a full M=20 sweep.
%
%     The experiment therefore ships with SLICE_TIMEOUT (driver.sh) so a hung
%     process can never block the pool indefinitely, and with an escape hatch:
%         ALGS="HES_EA" HES_CLASS=HES_EA_N100_guard bash driver.sh
%     switches to the guarded copy. Whichever class is used MUST be disclosed
%     in the paper.

    reg = struct('key',{},'folder',{},'cls',{},'params',{},'note',{});

    reg(1).key    = 'REMO';
    reg(1).folder = 'REMO';
    reg(1).cls    = 'REMO';
    reg(1).params = {};
    reg(1).note   = 'published defaults {k,gmax}={6,3000}; N=100 because D>10';

    reg(2).key    = 'PCSAEA';
    reg(2).folder = 'PCSAEA';
    reg(2).cls    = 'PCSAEA';
    reg(2).params = {};
    reg(2).note   = 'ORIGINAL published class; NI = 11*D-1 = 329 of the 500 FE';

    reg(3).key    = 'CSEA';
    reg(3).folder = 'CSEA';
    reg(3).cls    = 'CSEA';
    reg(3).params = {};
    reg(3).note   = 'published defaults {k,gmax}={6,3000}; N=min(11*D-1,109)=109';

    reg(4).key    = 'HES_EA';
    reg(4).folder = 'HES_EA';
    reg(4).cls    = 'HES_EA';
    reg(4).params = {};
    reg(4).note   = 'ORIGINAL published class; NI = 11*D-1 = 329 of the 500 FE; CAN HANG';

    reg(5).key    = 'SSDE';
    reg(5).folder = 'SSDE';
    reg(5).cls    = 'SSDE';
    reg(5).params = {};
    reg(5).note   = 'published defaults {num_nodes,eta0,sigma0}={N,0.2,N}';

    reg(6).key    = 'SAMOEA';
    reg(6).folder = 'SAMOEATL2M';
    reg(6).cls    = 'SAMOEATL2M';
    reg(6).params = {};
    reg(6).note   = 'ORIGINAL published class; NI = 11*D-1 = 329 of the 500 FE';

    reg(7).key    = 'PACDIS';
    reg(7).folder = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    reg(7).cls    = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    reg(7).params = {3000,0.50,0.25,0.70,6};
    reg(7).note   = 'house parameters {gmax,pMix,rGood,qKeep,nMax}';
end
