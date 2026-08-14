function bin = LVStageBin(ratio)
%LVStageBin Map an FE ratio to the frozen StageBin string.
%   bin = LVStageBin(ratio)
%     EARLY:  ratio < 0.40
%     MIDDLE: 0.40 <= ratio < 0.70
%     LATE:   ratio >= 0.70

    if ratio < 0.40
        bin = 'EARLY';
    elseif ratio < 0.70
        bin = 'MIDDLE';
    else
        bin = 'LATE';
    end
end
