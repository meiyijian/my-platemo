function filePath = CMCResultPath(paths,job)
%CMCRESULTPATH Return the arm-aware atomic MAT path for one job.

    folder = fullfile(paths.RawRoot,char(job.Arm),char(job.Problem), ...
        sprintf('M%d',job.M));
    filePath = fullfile(folder,sprintf('run_%03d.mat',job.Run));
end
