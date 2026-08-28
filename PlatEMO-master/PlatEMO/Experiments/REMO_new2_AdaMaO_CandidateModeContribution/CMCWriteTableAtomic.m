function CMCWriteTableAtomic(value,filePath)
%CMCWRITETABLEATOMIC Write a CSV without exposing a partial final file.

    folder = fileparts(filePath);
    if ~isfolder(folder)
        mkdir(folder);
    end
    temporary = [filePath,'.tmp.',char(java.util.UUID.randomUUID),'.csv'];
    cleanup = onCleanup(@()deleteIfPresent(temporary));
    writetable(value,temporary);
    movefile(temporary,filePath,'f');
end

function deleteIfPresent(pathValue)
    if isfile(pathValue)
        delete(pathValue);
    end
end
