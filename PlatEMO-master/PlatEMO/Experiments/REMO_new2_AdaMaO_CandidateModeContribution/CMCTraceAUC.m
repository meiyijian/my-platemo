function value = CMCTraceAUC(trace)
%CMCTRACEAUC Recompute the normalized IGD+ area on observed FE points.

    required = ["FE","FERatio","IGDp"];
    if ~istable(trace) || isempty(trace) || ...
            ~all(ismember(required,string(trace.Properties.VariableNames)))
        error('CMC:InvalidAnytimeTrace', ...
            'Anytime trace must be a nonempty FE/FERatio/IGDp table.');
    end
    x = trace.FERatio(:);
    y = trace.IGDp(:);
    if any(~isfinite(trace.FE(:))) || any(~isfinite(x)) || ...
            any(~isfinite(y)) || any(y < 0) || any(diff(trace.FE(:)) <= 0) || ...
            any(diff(x) <= 0) || x(1) < 0 || x(end) > 1+1e-12
        error('CMC:InvalidAnytimeTrace', ...
            'Anytime trace values must be finite, ordered, and in range.');
    end
    if numel(x) == 1 || x(end)-x(1) <= eps(max(1,x(end)))
        value = y(end);
    else
        value = trapz(x,y)/(x(end)-x(1));
    end
end
