function h = LVHashString(x)
%LVHashString Deterministic MD5 hex hash of any serializable value.
%   h = LVHashString(x) returns the 32-char lowercase MD5 hex of a
%   canonical byte representation of x. Supported inputs: scalar/array
%   numeric, logical, char/string, cell array of these, struct (flattened
%   to a sorted field-name-tagged string). Uses the Java JVM so it is
%   deterministic across MATLAB sessions for identical inputs.
%
%   NOTE: struct hashing sorts field names, so reordered-but-equal structs
%   produce the same hash; array values are serialized with high
%   precision via sprintf('%.17g') to avoid locale/numeric formatting
%   differences.

    if isstruct(x)
        fn = sort(fieldnames(x));
        parts = cell(1, 2*numel(fn));
        for i = 1:numel(fn)
            parts{2*i-1} = fn{i};
            v = x.(fn{i});
            if ischar(v)
                parts{2*i} = v;
            elseif islogical(v)
                parts{2*i} = sprintf('%d',v(:)');
            elseif isnumeric(v) && numel(v) <= 10000
                parts{2*i} = sprintf('%.17g ',v(:)');
            else
                parts{2*i} = LVHashString(v);
            end
        end
        bytes = uint8([parts{:}]);
    elseif islogical(x)
        bytes = uint8(x(:));
    elseif isnumeric(x)
        if numel(x) <= 10000
            s = sprintf('%.17g ',x(:)');
            bytes = uint8(s);
        else
            % large numeric arrays: hash a deterministic sample summary
            s = sprintf('%.17g ',x(1:min(numel(x),10000)));
            bytes = uint8(s);
        end
    elseif ischar(x) || isstring(x)
        bytes = uint8(char(x(:))');
    elseif iscell(x)
        parts = cell(1, numel(x));
        for i = 1:numel(x)
            parts{i} = LVHashString(x{i});
        end
        bytes = uint8([parts{:}]);
    else
        error('LVHashString:Unsupported','Unsupported type: %s',class(x));
    end
    md = java.security.MessageDigest.getInstance('MD5');
    md.update(bytes);
    d  = md.digest();
    h  = sprintf('%02x',typecast(d,'uint8'));
end
