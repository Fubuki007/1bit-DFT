%% run_multi_target_rmse_compare.m
% 多目标角度估计对比：RMSE vs SNR（单图四曲线）
% 风格说明：
% - 按你原先脚本的写法组织（参数区 -> 主循环 -> 画图 -> 局部函数）
% - 支持并行开关 enable_parallel，并在失败时自动回退串行
% - 带 waitbar 进度条，便于长时间仿真观察

clear; clc; close all;
rng(20260414, 'twister');

%% ===== 1) 参数设置（与先前脚本风格一致） =====
p = struct();

% 物理/OFDM参数
p.c  = 3e8;
p.fc = 28e9;
p.df = 120e3;
p.Tu = 8.33e-6;
p.Tcp = 0.6e-6;
p.T  = 8.93e-6;
p.lambda_c = p.c / p.fc;

% 阵列参数
p.Ntx = 16;
p.Mrx = 16;
p.dt = p.lambda_c / 2;
p.dr = p.lambda_c / 2;
p.Na = 64;

% 时频资源
p.Ns = 256;
p.L  = 32;

% 多目标设置（三目标）
p.num_targets = 3;
truth = struct();
truth.theta_deg = [-22, 6, 28];
truth.R = [32, 40, 55];
truth.v = [-6, 8, 14];
truth.beta = [1.0*exp(1j*pi/7), 0.85*exp(-1j*pi/5), 0.70*exp(1j*pi/3)];

% 只统计第 target_idx 个目标的RMSE
target_idx = 2;

% 仿真配置
snr_db_list = -20:5:20;
mc_trials = 100;

% 并行配置
enable_parallel = true;   % true: 优先并行; false: 强制串行
desired_workers = 8;

% 算法配置（四条曲线）
algorithms = struct( ...
    'name', { ...
        'Full-Precision + Peak + Interp', ...
        '1-bit + NoPeak + NoInterp', ...
        '1-bit + Peak + NoInterp', ...
        '1-bit + Peak + Interp'}, ...
    'use_1bit',  {false, true,  true,  true}, ...
    'use_peak',  {true,  false, true,  true}, ...
    'use_interp',{true,  false, false, true});

num_alg = numel(algorithms);
num_snr = numel(snr_db_list);
rmse_deg = zeros(num_alg, num_snr);

%% ===== 2) 并行池设置（可选） =====
use_parallel = false;
if enable_parallel
    use_parallel = true;
    try
        pool = gcp('nocreate');
        if isempty(pool) || pool.NumWorkers ~= desired_workers
            if ~isempty(pool)
                delete(pool);
            end
            parpool('local', desired_workers);
        end
    catch ME
        warning('并行池启动失败，回退串行。\n%s', ME.message);
        use_parallel = false;
    end
end

%% ===== 3) Monte Carlo 主循环（带进度条） =====
seed_base = 2026041400;
n_total = num_snr * mc_trials;
step = 0;

h = waitbar(0, 'RMSE对比仿真进行中...');
cleaner = onCleanup(@() close_waitbar_safe(h)); %#ok<NASGU>

for is = 1:num_snr
    snr_db = snr_db_list(is);
    err2_this = zeros(num_alg, mc_trials);

    if use_parallel
        % 并行模式：每个SNR点内部并行跑mc_trials
        parfor it = 1:mc_trials
            trial_seed = seed_base + 1000*is + it;
            err2_this(:, it) = run_one_trial(p, truth, algorithms, target_idx, snr_db, trial_seed);
        end

        % 并行块完成后，统一更新一次进度条
        step = step + mc_trials;
        waitbar(step / n_total, h, sprintf('SNR=%+d dB | %d/%d', snr_db, step, n_total));
    else
        % 串行模式：逐次更新进度条
        for it = 1:mc_trials
            trial_seed = seed_base + 1000*is + it;
            err2_this(:, it) = run_one_trial(p, truth, algorithms, target_idx, snr_db, trial_seed);

            step = step + 1;
            if mod(step, 10) == 0 || step == n_total
                waitbar(step / n_total, h, sprintf('SNR=%+d dB | %d/%d', snr_db, step, n_total));
            end
        end
    end

    rmse_deg(:, is) = sqrt(mean(err2_this, 2));
    fprintf('SNR = %+3d dB 完成。\n', snr_db);
end

%% ===== 4) 绘图与保存 =====
fig = figure('Color', 'w', 'Position', [100, 100, 980, 580]);
hold on; grid on; box on;

style = {
    '-',  'o', [0.10, 0.35, 0.75];
    '--', 's', [0.85, 0.33, 0.10];
    '-.', '^', [0.10, 0.60, 0.25];
    '-',  'd', [0.55, 0.20, 0.65]};

for ia = 1:num_alg
    y_plot = max(rmse_deg(ia, :), 1e-4); % 对数坐标安全下限
    semilogy(snr_db_list, y_plot, ...
        'LineStyle', style{ia,1}, ...
        'Marker', style{ia,2}, ...
        'Color', style{ia,3}, ...
        'MarkerFaceColor', style{ia,3}, ...
        'LineWidth', 1.9, ...
        'MarkerSize', 6, ...
        'DisplayName', algorithms(ia).name);
end

xlabel('SNR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(sprintf('Target %d Angle RMSE (deg)', target_idx), 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Multi-target RMSE vs SNR (Target %d at %.1f^\circ)', target_idx, truth.theta_deg(target_idx)), ...
    'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'northeastoutside');
set(gca, 'YScale', 'log', 'FontName', 'Times New Roman', 'FontSize', 11, 'LineWidth', 1.1);

out_png = fullfile(pwd, sprintf('rmse_vs_snr_target_%d_multitarget_4curves.png', target_idx));
out_mat = fullfile(pwd, sprintf('rmse_vs_snr_target_%d_multitarget_4curves.mat', target_idx));

exportgraphics(fig, out_png, 'Resolution', 300);
save(out_mat, 'p', 'truth', 'algorithms', 'target_idx', 'snr_db_list', 'mc_trials', ...
    'enable_parallel', 'desired_workers', 'rmse_deg');

fprintf('\n===== 仿真完成 =====\n');
fprintf('目标: #%d (%.2f deg)\n', target_idx, truth.theta_deg(target_idx));
fprintf('输出文件:\n- %s\n- %s\n', out_png, out_mat);

%% ===== 局部函数 =====
function err2_vec = run_one_trial(p, truth, algorithms, target_idx, snr_db, trial_seed)
% 单次试验：生成一帧数据，跑四种算法，输出误差平方
rng(trial_seed, 'twister');
[y, ~] = gen_one_frame(p, truth, snr_db);

num_alg = numel(algorithms);
err2_vec = zeros(num_alg, 1);

for ia = 1:num_alg
    theta_hat_all = estimate_angles_spectrum(y, p, algorithms(ia));
    theta_hat_all = sort(theta_hat_all, 'ascend');

    % 兜底：数量不足时补齐
    if numel(theta_hat_all) < p.num_targets
        theta_hat_all(end+1:p.num_targets) = theta_hat_all(end);
    end

    theta_hat = theta_hat_all(target_idx);
    err2_vec(ia) = wrap_to_180(theta_hat - truth.theta_deg(target_idx))^2;
end
end

function theta_hat_deg = estimate_angles_spectrum(y, p, alg)
% 基于空间谱的稳健多目标角估计（不依赖外部缺失函数）
% - Full-Precision: 直接用y
% - 1-bit: 先做符号量化
% - Peak/Interp: 控制峰值选择与抛物线插值

if alg.use_1bit
    y_proc = sign(real(y)) + 1j*sign(imag(y));
else
    y_proc = y;
end

Ysp = fftshift(fft(y_proc, p.Na, 1), 1) / p.Mrx;               % [Na, Ns, L]
spec = squeeze(mean(mean(abs(Ysp).^2, 3), 2));                 % [Na, 1]
na_axis = (-floor(p.Na/2)):(ceil(p.Na/2)-1);

if alg.use_peak
    peak_idx = pick_topk_peaks(spec, p.num_targets, 2);
else
    [~, idx_sort] = sort(spec, 'descend');
    peak_idx = idx_sort(1:p.num_targets).';
end

na_hat = na_axis(peak_idx);

% 可选插值（逐峰）
if alg.use_interp
    for k = 1:numel(peak_idx)
        c = peak_idx(k);
        il = mod(c - 2, p.Na) + 1;
        ir = mod(c,     p.Na) + 1;

        y1 = spec(il); y2 = spec(c); y3 = spec(ir);
        den = y1 - 2*y2 + y3;
        if abs(den) > 1e-12
            delta = 0.5 * (y1 - y3) / den;
            delta = max(-0.5, min(0.5, delta));
            na_hat(k) = na_hat(k) + delta;
        end
    end
end

arg = -na_hat * p.lambda_c / (p.dr * p.Na);
arg = max(-1, min(1, arg));
theta_hat_deg = rad2deg(asin(arg));
end

function idx = pick_topk_peaks(spec, k, guard)
% 从谱中选k个峰，主瓣附近加保护间隔，避免重复选到同一峰
spec = spec(:);
N = numel(spec);
idx = zeros(1, k);
blocked = false(N,1);
filled = 0;

while filled < k
    cand = find(~blocked);
    if isempty(cand)
        break;
    end
    [~, imax] = max(spec(cand));
    p0 = cand(imax);

    filled = filled + 1;
    idx(filled) = p0;

    for d = -guard:guard
        b = mod(p0-1+d, N) + 1;
        blocked(b) = true;
    end
end

idx = idx(1:max(1,filled));
if numel(idx) < k
    idx(end+1:k) = idx(end);
end
end

function [y, x] = gen_one_frame(p, truth, snr_db)
% 生成多目标MIMO-OFDM回波
Ntx = p.Ntx; Mrx = p.Mrx; Ns = p.Ns; L = p.L;
Q = p.num_targets;

const = [1+1j, 1-1j, -1+1j, -1-1j] / sqrt(2);
idx = randi(4, [Ntx, Ns, L]);
x = const(idx);

n_tx = (0:Ntx-1).';
m = (0:Mrx-1).';
i = 0:(Ns-1);
l = 0:(L-1);

y_clean = zeros(Mrx, Ns, L);
for q = 1:Q
    theta = deg2rad(truth.theta_deg(q));
    R = truth.R(q);
    v = truth.v(q);
    beta = truth.beta(q);

    a_tx = exp(1j * 2*pi * n_tx * (p.dt * sin(theta) / p.lambda_c));
    s = squeeze(sum(conj(a_tx) .* x, 1));

    wa = -2*pi * p.dr / p.lambda_c * sin(theta);
    wr = -4*pi * p.df * R / p.c;
    wv =  4*pi * p.T  * v / p.lambda_c;

    phase_m = exp(1j * m * wa);
    phase_i = exp(1j * i * wr);
    phase_l = exp(1j * l * wv);

    for ll = 1:L
        y_clean(:,:,ll) = y_clean(:,:,ll) + ...
            beta * (phase_m * (phase_i .* (s(:,ll).' * phase_l(ll))));
    end
end

sig_pow = mean(abs(y_clean(:)).^2);
noise_pow = sig_pow / (10^(snr_db/10));
noise_sigma = sqrt(noise_pow/2);
z = noise_sigma * (randn(Mrx,Ns,L) + 1j*randn(Mrx,Ns,L));
y = y_clean + z;
end

function x = wrap_to_180(x)
% 将角度映射到[-180,180)
x = mod(x + 180, 360) - 180;
end

function close_waitbar_safe(h)
% 安全关闭waitbar
if ~isempty(h) && isvalid(h)
    close(h);
end
end
