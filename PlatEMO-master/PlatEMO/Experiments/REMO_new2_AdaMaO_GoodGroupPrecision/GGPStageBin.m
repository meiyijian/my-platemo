function stage = GGPStageBin(feRatio)
%GGPSTAGEBIN Map an FE ratio to one of four closed-right stage intervals.
%   The intervals are [0,0.25], (0.25,0.50], (0.50,0.75], and
%   (0.75,1.00].

    validateattributes(feRatio, {'numeric'}, ...
        {'scalar', 'real', 'finite', '>=', 0, '<=', 1}, mfilename, 'feRatio');

    if feRatio <= 0.25
        stage = "S1_[0,0.25]";
    elseif feRatio <= 0.50
        stage = "S2_(0.25,0.50]";
    elseif feRatio <= 0.75
        stage = "S3_(0.50,0.75]";
    else
        stage = "S4_(0.75,1.00]";
    end
end
