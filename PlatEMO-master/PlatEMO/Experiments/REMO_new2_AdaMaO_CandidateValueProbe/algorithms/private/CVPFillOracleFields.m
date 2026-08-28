function row = CVPFillOracleFields(row, oracle)
%CVPFILLORACLEFIELDS Copy oracle-batch diagnostics into a generation row.

    row.OracleValid = logical(oracle.Valid);
    row.OracleHitCount = oracle.HitCount;
    row.OracleHitRate = oracle.HitRate;
    row.OracleAlgorithmK = oracle.AlgorithmK;
    row.OracleK = oracle.OracleK;
    row.OracleBaselineCoverage = oracle.BaselineCoverage;
    row.OracleAlgorithmCoverage = oracle.AlgorithmCoverage;
    row.OracleOracleCoverage = oracle.OracleCoverage;
    row.OracleAlgorithmGain = oracle.AlgorithmGain;
    row.OracleOracleGain = oracle.OracleGain;
    row.OracleGainRatio = oracle.GainRatio;
    row.OraclePoolConsidered = oracle.PoolConsidered;
    row.OraclePoolTotal = oracle.PoolTotal;
    row.OracleSubsampled = logical(oracle.Subsampled);
end
