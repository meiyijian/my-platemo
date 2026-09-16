function DumpXlsx(f)
%DumpXlsx Dump one xlsx worksheet cell by cell, verbatim.
    if nargin < 1
        f = 'C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本\IGDp10目标.xlsx';
    end
    fprintf('FILE: %s\n', f);
    [~, sheets] = xlsfinfo(f);
    fprintf('sheets: %s\n', strjoin(sheets, ', '));
    for s = 1:numel(sheets)
        C = readcell(f, 'Sheet', sheets{s});
        [nr, nc] = size(C);
        fprintf('--- sheet "%s": %d rows x %d cols ---\n', sheets{s}, nr, nc);
        for i = 1:nr
            parts = cell(1, nc);
            for j = 1:nc
                v = C{i, j};
                if ismissing(v)
                    parts{j} = '<empty>';
                elseif ischar(v)
                    parts{j} = v;
                elseif isstring(v)
                    parts{j} = char(v);
                elseif isnumeric(v)
                    parts{j} = num2str(v, 17);
                else
                    parts{j} = ['<' class(v) '>'];
                end
            end
            fprintf('R%02d | %s\n', i, strjoin(parts, ' | '));
        end
    end
    fprintf('\nDUMP DONE\n');
end
