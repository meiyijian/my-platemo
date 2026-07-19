function [p,ambiguity,Qsym] = ...
    SymmetrizeSDEFactorialPreference(Qforward,Qreverse)
%SymmetrizeSDEFactorialPreference Enforce reciprocal pair preferences.

    if ~isnumeric(Qforward) || ~isreal(Qforward) || ...
            ~isnumeric(Qreverse) || ~isreal(Qreverse) || ...
            ~isequal(size(Qforward),size(Qreverse)) || ...
            size(Qforward,2) ~= 2
        error('AdaMaO:InvalidPreferenceDimensions', ...
            'Forward and reverse predictions must be equally sized Q-by-2 matrices.');
    end

    invalid = any(~isfinite(Qforward),2) | any(~isfinite(Qreverse),2);
    Qsym = 0.5.*(Qforward + Qreverse(:,[2 1]));
    Qsym = max(Qsym,0);
    mass = sum(Qsym,2);
    invalid = invalid | ~isfinite(mass) | mass <= 0;

    valid = ~invalid;
    Qsym(valid,:) = Qsym(valid,:)./mass(valid);
    Qsym(invalid,:) = repmat([0.5 0.5],sum(invalid),1);

    p = Qsym(:,1);
    ambiguity = 1-abs(2.*p-1);
end
