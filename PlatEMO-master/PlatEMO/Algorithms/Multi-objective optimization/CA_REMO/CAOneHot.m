function Out = CAOneHot(In,mode)
% Convert relation labels and one-hot matrices.
% mode 1: labels [1,0,-1] to one-hot columns.
% mode 2: one-hot/probability rows to labels [1,0,-1].

    if mode == 1
        labels = In(:);
        Out = zeros(numel(labels),3);
        Out(labels == 1,1)  = 1;
        Out(labels == 0,2)  = 1;
        Out(labels == -1,3) = 1;
    else
        [~,idx] = max(In,[],2);
        Out = zeros(size(In,1),1);
        Out(idx == 1) = 1;
        Out(idx == 3) = -1;
    end
end
