folder = 'D:/PlatEMO-master/PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SimpleA';
files = dir(fullfile(folder,'*.m'));
fprintf('Checking %d .m files in SimpleA...\n', numel(files));
ok = 0; bad = 0;
for i = 1:numel(files)
    fn = files(i).name;
    try
        pcode(fullfile(folder,fn));
        ok = ok + 1;
    catch ME
        bad = bad + 1;
        fprintf('  SYNTAX_ERR %s : %s\n', fn, ME.message);
    end
end
fprintf('=== DONE: %d OK, %d SYNTAX_ERR ===\n', ok, bad);
