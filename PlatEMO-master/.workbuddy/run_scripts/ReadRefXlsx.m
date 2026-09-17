function ReadRefXlsx()
%ReadRefXlsx Dump one xlsx worksheet cell by cell, verbatim.
    f = 'C:\Users\lsx\Desktop\AdaMao实验表\lambdat030版本\IGDp10目标.xlsx';
    fprintf('FILE: %s\n', f);
    [~, sheets] = xlsfinfo(f);
    fprintf('sheets: %s\n', strjoin(sheets, ', '));
    C = readcell(f, 'Sheet', sheets{1});
    [nr, nc] = size(C);
    fprintf('size: %d rows x %d cols\n\n', nr, nc);
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
    fprintf('\nREAD DONE\n');
end
