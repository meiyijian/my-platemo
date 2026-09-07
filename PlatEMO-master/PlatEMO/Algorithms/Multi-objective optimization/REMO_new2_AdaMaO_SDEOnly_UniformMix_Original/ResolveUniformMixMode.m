function [mode,pInd] = ResolveUniformMixMode(indicatorAvailable,u,pMix)
%ResolveUniformMixMode 根据指标模型可用性和 pMix 选择 CDIS 准则。
%   [MODE,pInd] = ResolveUniformMixMode(indicatorAvailable,U,pMix) 在指标
%   模型可用且 U<pMix 时返回 'indicator'，其余情况返回 'explore'。
%   U 为当前迭代的 [0,1) 随机数。pInd 返回配置的 pMix；指标模型不可用时，
%   实际指标准则选择概率为 0。默认主入口设置 pMix=0.50。

    if ~isscalar(pMix) || ~isnumeric(pMix) || ~isfinite(pMix) || ...
            pMix < 0 || pMix > 1
        error('AdaMaO:InvalidCandidateMixProbability', ...
            'pMix must be a finite scalar in [0,1].');
    end
    if ~isscalar(u) || ~isnumeric(u) || ~isfinite(u) || u < 0 || u >= 1
        error('AdaMaO:InvalidCandidateModeDraw', ...
            'The candidate-mode draw must be a finite scalar in [0,1).');
    end
    if ~isscalar(indicatorAvailable) || ~logical(indicatorAvailable)
        indicatorAvailable = false;
    end

    pInd = pMix;
    mode = 'explore';
    if indicatorAvailable && u < pMix
        mode = 'indicator';
    end
end
