function [modeStream,modeSeed] = CreateSDECandidateModeStream(runId)
%CreateSDECandidateModeStream 创建仅用于 CDIS 准则抽样的随机流。
%   [modeStream,modeSeed] = CreateSDECandidateModeStream(runId) 根据运行编号
%   构造随机种子和独立于 MATLAB 全局流的 mt19937ar 随机流。
%   主程序每轮从该流取一个随机数，用于选择探索或指标准则。

    if isempty(runId) || ~isnumeric(runId) || ~isscalar(runId) || ...
            ~isfinite(runId) || runId <= 0
        runId = 1;
    else
        runId = max(1,floor(double(runId)));
    end

    maxSeed  = double(intmax('uint32'));
    modeSeed = mod(10000000 + runId,maxSeed);
    modeStream = RandStream('mt19937ar','Seed',modeSeed);
end
