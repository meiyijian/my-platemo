function varargout = SRMaO_onehot2(varargin)
% Binary one-hot encoder/decoder for labels 0 and 1.

    data = varargin{1};
    mode = varargin{2};
    if mode == 1
        labels = data(:);
        out = zeros(numel(labels),2);
        out(labels == 1,1) = 1;
        out(labels == 0,2) = 1;
        varargout = {out};
    else
        [~,idx] = max(data,[],2);
        labels = zeros(size(data,1),1);
        labels(idx == 1) = 1;
        labels(idx == 2) = 0;
        varargout = {labels};
    end
end
