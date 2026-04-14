%% run_multitarget_threefig_compare_1bit.m
% 多目标1-bit角度估计三图对比（重构稳定版）
% 图1: RMSE vs SNR
% 图2: RMSE vs 接收天线数
% 图3: RMSE vs 子载波数
%
% 说明：
% - 完全按你先前脚本风格重构：参数区、三段主循环、统一绘图函数、局部函数。
% - 不依赖仓库中不存在的 angle_1bit_dft_multi_estimator，避免“根本跑不了”。
% - 保留并行开关 + 自动回退串行 + waitbar 进度条。

clear; clc; close all;
rng(20260414, 'twister');

%% ===== 1) 公共参数 =====
p0 = struct();

% 物理/OFDM参数
p0.c  = 3e8;
p0.fc = 28e9;
p0.df = 120e3;
p0.Tu = 8.33e-6;
p0.Tcp = 0.6e-6;
p0.T  = 8.93e-6;
p0.lambda_c = p0.c / p0.fc;

% 阵列参数
p0.Ntx = 16;
p0.Mrx = 16;
p0.dt = p0.lambda_c / 2;
p0.dr = p0.lambda_c / 2;
p0.Na = 64;

% 时频参数
p0.Ns = 256;
p0.L  = 32;

% 数值参数
p0.eps_div = 1e-10;
p0.num_targets = 3;

% 三目标真值（同你先前风格）
truth = struct();
truth.theta_deg = [-22, 6, 28];
truth.R = [32, 40, 55];
truth.v = [-6, 8, 14];
truth.beta = [1.0*exp(1j*pi/7), 0.85*exp(-1j*pi/5), 0.70*exp(1j*pi/3)];

% 统计第几个目标
target_idx = 2;

% 扫参配置
snr_db_list = -20:5:20;
snr_db_fixed = 0;
antenna_list = [8, 16, 64, 128, 256];
subcarrier_list = [16, 32, 64, 128, 256, 512];
mc_trials = 80;

% 并行配置
enable_parallel = true;
desired_workers = 8;

% 统一算法列表（四条曲线）
algorithms = struct( ...
    'name', { ...
        '1-bit + ESPRIT', ...
        '1-bit + MUSIC', ...
        '1-bit + DFT', ...
        '1-bit + Improved DFT'}, ...
    'tag', { ...
        'onebit_esprit', ...
        'onebit_music', ...
        'onebit_dft', ...
        'onebit_dft_improved'});
num_alg = numel(algorithms);

checkpoint_file = fullfile(pwd, sprintf('multitarget_threefig_target_%d_1bit_compare_checkpoint.mat', target_idx));

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
        warning('并行池启动失败，自动回退串行。\n%s', ME.message);
        use_parallel = false;
    end
end

%% ===== 3) 三组扫参（带进度条） =====
rmse_vs_snr = zeros(num_alg, numel(snr_db_list));
rmse_vs_ant = zeros(num_alg, numel(antenna_list));
rmse_vs_ns  = zeros(num_alg, numel(subcarrier_list));

seed_base = 2026041400;

n_total = numel(snr_db_list) + numel(antenna_list) + numel(subcarrier_list);
step = 0;
h = waitbar(0, '三图对比仿真进行中...');
cleaner = onCleanup(@() close_waitbar_safe(h)); %#ok<NASGU>

% ---- Sweep 1: RMSE vs SNR ----
fprintf('===== Sweep 1/3: RMSE vs SNR =====\n');
for is = 1:numel(snr_db_list)
    p_cur = p0;
    snr_db = snr_db_list(is);

    rmse_vs_snr(:, is) = run_mc_block(p_cur, truth, algorithms, target_idx, snr_db, mc_trials, use_parallel, seed_base + 10000*is);

    step = step + 1;
    waitbar(step/n_total, h, sprintf('Sweep1/3 SNR=%+d dB | %d/%d', snr_db, step, n_total));
    fprintf('SNR = %+3d dB 完成。\n', snr_db);

    save(checkpoint_file, 'rmse_vs_snr', 'rmse_vs_ant', 'rmse_vs_ns', ...
        'snr_db_list', 'antenna_list', 'subcarrier_list', 'mc_trials', 'target_idx', ...
        'enable_parallel', 'desired_workers');
end

% ---- Sweep 2: RMSE vs 天线数 ----
fprintf('\n===== Sweep 2/3: RMSE vs antenna number =====\n');
for ia = 1:numel(antenna_list)
    p_cur = p0;
    p_cur.Mrx = antenna_list(ia);
    p_cur.Ntx = antenna_list(ia);   % 与你先前脚本一致：同规模更公平
    p_cur.Na  = max(64, 2*p_cur.Mrx);

    rmse_vs_ant(:, ia) = run_mc_block(p_cur, truth, algorithms, target_idx, snr_db_fixed, mc_trials, use_parallel, seed_base + 20000*ia);

    step = step + 1;
    waitbar(step/n_total, h, sprintf('Sweep2/3 Mrx=%d | %d/%d', p_cur.Mrx, step, n_total));
    fprintf('Mrx = %4d 完成。\n', p_cur.Mrx);

    save(checkpoint_file, 'rmse_vs_snr', 'rmse_vs_ant', 'rmse_vs_ns', ...
        'snr_db_list', 'antenna_list', 'subcarrier_list', 'mc_trials', 'target_idx', ...
        'enable_parallel', 'desired_workers');
end

% ---- Sweep 3: RMSE vs 子载波数 ----
fprintf('\n===== Sweep 3/3: RMSE vs subcarrier number =====\n');
for in = 1:numel(subcarrier_list)
    p_cur = p0;
    p_cur.Ns = subcarrier_list(in);

    rmse_vs_ns(:, in) = run_mc_block(p_cur, truth, algorithms, target_idx, snr_db_fixed, mc_trials, use_parallel, seed_base + 30000*in);

    step = step + 1;
    waitbar(step/n_total, h, sprintf('Sweep3/3 Ns=%d | %d/%d', p_cur.Ns, step, n_total));
    fprintf('Ns = %4d 完成。\n', p_cur.Ns);

    save(checkpoint_file, 'rmse_vs_snr', 'rmse_vs_ant', 'rmse_vs_ns', ...
        'snr_db_list', 'antenna_list', 'subcarrier_list', 'mc_trials', 'target_idx', ...
        'enable_parallel', 'desired_workers');
end

%% ===== 4) 绘图与保存 =====
style = {
    '-',  'o', [0.10, 0.35, 0.75];
    '--', 's', [0.85, 0.33, 0.10];
    '-.', '^', [0.10, 0.60, 0.25];
    '-',  'd', [0.55, 0.20, 0.65]};

fig1 = plot_rmse_curve(snr_db_list, rmse_vs_snr, algorithms, style, ...
    'SNR (dB)', sprintf('Target %d Angle RMSE (deg)', target_idx), ...
    sprintf('Multi-target RMSE vs SNR (Target %d at %.1f^\circ)', target_idx, truth.theta_deg(target_idx)));

fig2 = plot_rmse_curve(antenna_list, rmse_vs_ant, algorithms, style, ...
    'Antenna Number (M_{rx})', sprintf('Target %d Angle RMSE (deg)', target_idx), ...
    sprintf('Multi-target RMSE vs Antenna Number (SNR = %+d dB)', snr_db_fixed));

fig3 = plot_rmse_curve(subcarrier_list, rmse_vs_ns, algorithms, style, ...
    'Subcarrier Number N_s', sprintf('Target %d Angle RMSE (deg)', target_idx), ...
    sprintf('Multi-target RMSE vs Subcarrier Number (SNR = %+d dB)', snr_db_fixed));

out_png_1 = fullfile(pwd, sprintf('rmse_vs_snr_target_%d_1bit_esprit_music_dft_improved.png', target_idx));
out_png_2 = fullfile(pwd, sprintf('rmse_vs_antenna_target_%d_1bit_esprit_music_dft_improved.png', target_idx));
out_png_3 = fullfile(pwd, sprintf('rmse_vs_subcarrier_target_%d_1bit_esprit_music_dft_improved.png', target_idx));
out_mat = fullfile(pwd, sprintf('multitarget_threefig_target_%d_1bit_compare.mat', target_idx));

exportgraphics(fig1, out_png_1, 'Resolution', 300);
exportgraphics(fig2, out_png_2, 'Resolution', 300);
exportgraphics(fig3, out_png_3, 'Resolution', 300);

save(out_mat, 'p0', 'truth', 'algorithms', 'target_idx', 'mc_trials', ...
    'enable_parallel', 'desired_workers', 'snr_db_list', 'snr_db_fixed', ...
    'antenna_list', 'subcarrier_list', 'rmse_vs_snr', 'rmse_vs_ant', 'rmse_vs_ns');

fprintf('\n===== 三图实验完成 =====\n');
fprintf('目标: #%d (%.2f deg)\n', target_idx, truth.theta_deg(target_idx));
fprintf('输出文件:\n- %s\n- %s\n- %s\n- %s\n', ...
    out_png_1, out_png_2, out_png_3, out_mat);

%% ===== 局部函数 =====
function rmse_vec = run_mc_block(p, truth, algorithms, target_idx, snr_db, mc_trials, use_parallel, seed_offset)
% 固定参数块下的Monte Carlo，返回各算法RMSE
num_alg = numel(algorithms);
err2 = zeros(num_alg, mc_trials);

if use_parallel
    parfor it = 1:mc_trials
        err2(:, it) = run_one_trial(p, truth, algorithms, target_idx, snr_db, seed_offset + it);
    end
else
    for it = 1:mc_trials
        err2(:, it) = run_one_trial(p, truth, algorithms, target_idx, snr_db, seed_offset + it);
    end
end

rmse_vec = sqrt(mean(err2, 2));
end

function err2_vec = run_one_trial(p, truth, algorithms, target_idx, snr_db, trial_seed)
% 单次试验：生成数据并跑四种算法
rng(trial_seed, 'twister');
[y, ~] = gen_one_frame(p, truth, snr_db);

num_alg = numel(algorithms);
err2_vec = zeros(num_alg, 1);

for ia = 1:num_alg
    switch algorithms(ia).tag
        case 'onebit_esprit'
            theta_hat_all = estimate_angles_esprit_1bit(y, p);

        case 'onebit_music'
            theta_hat_all = estimate_angles_music_1bit(y, p);

        case 'onebit_dft'
            theta_hat_all = estimate_angles_dft_1bit(y, p, false);

        case 'onebit_dft_improved'
            theta_hat_all = estimate_angles_dft_1bit(y, p, true);

        otherwise
            error('未知算法标签: %s', algorithms(ia).tag);
    end

    theta_hat_all = sort(theta_hat_all, 'ascend');
    if numel(theta_hat_all) < p.num_targets
        theta_hat_all(end+1:p.num_targets) = theta_hat_all(end);
    end

    theta_hat = theta_hat_all(target_idx);
    err2_vec(ia) = wrap_to_180(theta_hat - truth.theta_deg(target_idx))^2;
end
end

function [y, x] = gen_one_frame(p, truth, snr_db)
% 多目标回波生成函数
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

function theta_hat_deg = estimate_angles_esprit_1bit(y, p)
% 1-bit ESPRIT
Yq = sign(real(y)) + 1j*sign(imag(y));
Ysnap = reshape(Yq, p.Mrx, []);
R = (Ysnap * Ysnap') / size(Ysnap,2);
R = forward_backward_average(R);

num_sig = min(p.num_targets, max(1, p.Mrx-1));
Es = dominant_signal_subspace(R, num_sig);

Es1 = Es(1:end-1,:);
Es2 = Es(2:end,:);
Psi = pinv(Es1) * Es2;
lmb = eig(Psi);

wa = angle(lmb);
sin_theta = -(wa * p.lambda_c) / (2*pi*p.dr);
sin_theta = max(-1, min(1, real(sin_theta)));

theta_hat_deg = rad2deg(asin(sin_theta)).';
theta_hat_deg = complete_target_list(theta_hat_deg, p.num_targets);
end

function theta_hat_deg = estimate_angles_music_1bit(y, p)
% 1-bit MUSIC
Yq = sign(real(y)) + 1j*sign(imag(y));
Ysnap = reshape(Yq, p.Mrx, []);
R = (Ysnap * Ysnap') / size(Ysnap,2);
R = forward_backward_average(R);

num_sig = min(p.num_targets, max(1, p.Mrx-1));
Es = dominant_signal_subspace(R, num_sig);

theta_grid = -80:0.1:80;
n = (0:p.Mrx-1).';
A = exp(-1j * 2*pi * p.dr / p.lambda_c * n * sind(theta_grid));
res = A - Es * (Es' * A);
den = sum(abs(res).^2, 1);
pseudo = 1 ./ max(den, p.eps_div);

peak_idx = pick_topk_peaks(pseudo(:), p.num_targets, 8);
theta_hat_deg = theta_grid(peak_idx);
theta_hat_deg = complete_target_list(theta_hat_deg, p.num_targets);
end

function theta_hat_deg = estimate_angles_dft_1bit(y, p, use_interp)
% 1-bit DFT / Improved DFT
Yq = sign(real(y)) + 1j*sign(imag(y));
Ysp = fftshift(fft(Yq, p.Na, 1), 1) / p.Mrx;
spec = squeeze(mean(mean(abs(Ysp).^2,3),2));

peak_idx = pick_topk_peaks(spec, p.num_targets, 2);
na_axis = (-floor(p.Na/2)):(ceil(p.Na/2)-1);
na_hat = na_axis(peak_idx);

if use_interp
    for k = 1:numel(peak_idx)
        c = peak_idx(k);
        il = mod(c-2, p.Na) + 1;
        ir = mod(c,   p.Na) + 1;

        y1 = spec(il); y2 = spec(c); y3 = spec(ir);
        den = y1 - 2*y2 + y3;
        if abs(den) > p.eps_div
            delta = 0.5 * (y1 - y3) / den;
            delta = max(-0.5, min(0.5, delta));
            na_hat(k) = na_hat(k) + delta;
        end
    end
end

arg = -na_hat * p.lambda_c / (p.dr * p.Na);
arg = max(-1, min(1, arg));
theta_hat_deg = rad2deg(asin(arg));
theta_hat_deg = complete_target_list(theta_hat_deg, p.num_targets);
end

function peak_idx = pick_topk_peaks(spec, k, guard)
% 谱峰挑选（带保护间隔）
spec = spec(:);
N = numel(spec);
blocked = false(N,1);
peak_idx = zeros(1,k);
filled = 0;

while filled < k
    cand = find(~blocked);
    if isempty(cand)
        break;
    end
    [~, imax] = max(spec(cand));
    idx = cand(imax);

    filled = filled + 1;
    peak_idx(filled) = idx;

    for d = -guard:guard
        b = mod(idx-1+d, N) + 1;
        blocked(b) = true;
    end
end

peak_idx = peak_idx(1:max(1,filled));
if numel(peak_idx) < k
    peak_idx(end+1:k) = peak_idx(end);
end
end

function theta_list = complete_target_list(theta_list, k)
% 补齐/截断目标数
theta_list = theta_list(:).';
if isempty(theta_list)
    theta_list = zeros(1, k);
elseif numel(theta_list) < k
    theta_list(end+1:k) = theta_list(end);
elseif numel(theta_list) > k
    theta_list = theta_list(1:k);
end
end

function Rfb = forward_backward_average(R)
% 前后向平均
J = fliplr(eye(size(R,1)));
Rfb = 0.5 * (R + J*conj(R)*J);
end

function Es = dominant_signal_subspace(R, num_sig)
% 主信号子空间
R = (R + R')/2;
N = size(R,1);
num_sig = min(num_sig, N);

if N <= 256
    [U, D] = eig(R, 'vector');
    [~, idx] = sort(real(D), 'descend');
    Es = U(:, idx(1:num_sig));
    return;
end

try
    [U, D] = eigs(R, num_sig, 'largestabs');
    [~, idx] = sort(real(diag(D)), 'descend');
    Es = U(:, idx);
catch
    [U, D] = eig(R, 'vector');
    [~, idx] = sort(real(D), 'descend');
    Es = U(:, idx(1:num_sig));
end
end

function fig = plot_rmse_curve(x_axis, rmse_mat, algorithms, style, xlab_txt, ylab_txt, ttl_txt)
% 统一绘图风格
fig = figure('Color', 'w', 'Position', [120, 120, 980, 580]);
hold on; grid on; box on;

for ia = 1:numel(algorithms)
    y_plot = max(rmse_mat(ia, :), 1e-4);
    semilogy(x_axis, y_plot, ...
        'LineStyle', style{ia,1}, ...
        'Marker', style{ia,2}, ...
        'Color', style{ia,3}, ...
        'MarkerFaceColor', style{ia,3}, ...
        'LineWidth', 1.9, ...
        'MarkerSize', 6, ...
        'DisplayName', algorithms(ia).name);
end

xlabel(xlab_txt, 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ylab_txt, 'FontSize', 12, 'FontWeight', 'bold');
title(ttl_txt, 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'northeastoutside');
set(gca, 'YScale', 'log', 'FontName', 'Times New Roman', 'FontSize', 11, 'LineWidth', 1.1);
end

function x = wrap_to_180(x)
% 角度映射到[-180,180)
x = mod(x + 180, 360) - 180;
end

function close_waitbar_safe(h)
% 安全关闭waitbar
if ~isempty(h) && isvalid(h)
    close(h);
end
end
