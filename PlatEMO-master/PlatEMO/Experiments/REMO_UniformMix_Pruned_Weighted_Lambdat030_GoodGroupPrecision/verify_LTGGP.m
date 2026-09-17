function verify_LTGGP()
%VERIFY_LTGGP Prove LTGGPAudit reproduces the Lambdat030 production path.
%   Three small-budget cases compare the frozen production class
%   REMO_UniformMix_Pruned_Weighted_Lambdat030 against the audit class on
%   the final archive, the complete IGD trajectory is not needed here: the
%   final populations and the post-run RNG state must be identical.
%   equivalence_passed.txt is only written after every case passes.

    [info, cleanup] = LTGGPSetupPaths(); %#ok<ASGLU>
    fid=fopen(info.EquivalenceEvidence,'w'); fprintf(fid,'RUNNING\n'); fclose(fid);
    net=patternnet(2); net.trainParam.showWindow=0; train(net,rand(4,20),double(rand(1,20)>0.5));
    fitrsvm(rand(20,4),rand(20,1),'KernelFunction','rbf','KernelScale','auto','Standardize',true);
    cases = { 'WFG3',2,3,20,42,1,1; 'DTLZ2',10,30,100,112,10,1; 'DTLZ2',20,30,100,112,200,0.5 };
    for c=1:size(cases,1)
        x=cases(c,:); results=cell(2,1); states=cell(2,1);
        for a=1:2
            p=feval(x{1},'M',x{2},'D',x{3},'N',x{4},'maxFE',x{5});
            args={'parameter',{x{6},x{7},0.25,0.70,6},'run',1,'save',0,'outputFcn',@(~,~) []};
            if a==1
                alg=REMO_UniformMix_Pruned_Weighted_Lambdat030(args{:});
            else
                alg=LTGGPAudit(args{:});
            end
            rng(712+c,'twister'); alg.Solve(p);
            results{a}={alg.result{end,2}.decs,alg.result{end,2}.objs};
            states{a}=rng;
            assert(p.FE==x{5},'Incomplete evaluation budget');
        end
        assert(isequaln(results{1},results{2}),'LTGGP:TrajectoryMismatch','Production/audit mismatch');
        assert(isequaln(states{1},states{2}),'LTGGP:RNGMismatch','Production/audit RNG mismatch');
        fprintf('Equivalence case %d PASS\n',c);
    end
    fid=fopen(info.EquivalenceEvidence,'w'); fprintf(fid,'PASS\n'); fclose(fid);
end
