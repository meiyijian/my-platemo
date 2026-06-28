function [mode,reliability,acc,reverseAcc] = CAReliability(Pred,Truth,Weight,delta)
% Decide whether the relation model should be used directly, reversed, or
% ignored. The reversed mode captures a model that is systematically wrong.

    Weight = Weight(:);
    if sum(Weight) <= 1e-12
        Weight = ones(size(Truth));
    end

    acc = sum(Weight.*(Pred(:)==Truth(:)))./sum(Weight);
    acc = acc(1);

    nonTie = Truth(:) ~= 0;
    if any(nonTie)
        reverseTruth = -Truth(nonTie);
        reverseAcc = sum(Weight(nonTie).*(Pred(nonTie)==reverseTruth))./sum(Weight(nonTie));
        reverseAcc = reverseAcc(1);
    else
        reverseAcc = 0;
    end

    if acc >= delta
        mode = 1;
        reliability = acc;
    elseif reverseAcc >= delta
        mode = -1;
        reliability = reverseAcc;
    else
        mode = 0;
        reliability = max(acc,reverseAcc);
    end
end
