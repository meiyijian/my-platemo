%% Smoke Test for REMO_LKCRed
% 冒烟测试：验证算法能正常初始化并运行，无运行时错误
% 测试条件：DTLZ2, M=10, D=10, maxFE=50
% 需要在 PlatEMO 根目录下运行此脚本

fprintf('========================================\n');
fprintf('  REMO_LKCRed 冒烟测试\n');
fprintf('========================================\n');

try
    fprintf('\n[1/2] 启动 REMO_LKCRed...\n');
    fprintf('  问题: DTLZ2, M=10, D=10, maxFE=50\n');

    platemo('algorithm', @REMO_LKCRed, ...
            'problem',   @DTLZ2, ...
            'M',         10, ...
            'D',         10, ...
            'maxFE',     50, ...
            'N',         100);

    fprintf('  [PASS] REMO_LKCRed 运行完成，无错误\n');

catch ME
    fprintf('  [FAIL] REMO_LKCRed 运行出错:\n');
    fprintf('  错误类型: %s\n', ME.identifier);
    fprintf('  错误信息: %s\n', ME.message);
    for i = 1:min(5, numel(ME.stack))
        fprintf('    at %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    return;
end

fprintf('\n[2/2] 测试结束\n');
fprintf('========================================\n');
fprintf('  结果: ALL TESTS PASSED\n');
fprintf('========================================\n');
