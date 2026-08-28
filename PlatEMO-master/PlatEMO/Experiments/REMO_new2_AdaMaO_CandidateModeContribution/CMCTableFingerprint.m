function value = CMCTableFingerprint(input,ignoredVariables)
%CMCTABLEFINGERPRINT Hash decision-relevant table content canonically.

    if nargin < 2
        ignoredVariables = strings(0,1);
    end
    if ~istable(input)
        error('CMC:InvalidFingerprintInput','Fingerprint input must be a table.');
    end
    present = intersect(string(input.Properties.VariableNames), ...
        string(ignoredVariables),'stable');
    if ~isempty(present)
        input = removevars(input,cellstr(present));
    end
    payload = struct( ...
        'VariableNames',{input.Properties.VariableNames}, ...
        'Data',table2struct(input,'ToScalar',true));
    value = CMCTextHash(jsonencode(payload));
end
