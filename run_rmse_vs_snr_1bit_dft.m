%% run_rmse_vs_snr_1bit_dft.m
% 单比特空间DFT角度估计复现实验：RMSE vs SNR（带进度条）
% 依赖：angle_1bit_dft_estimator.m

clear; clc; close all;
rng(20260412, 'twister');

%% ===== 1) 参数设置（快速版，可显著提速） =====
% 仍采用3GPP FR2关键物理参数（fc/Δf/T），但缩小仿真规模用于快速出图
p = struct();
p.c  = 3e8;
p.fc = 28e9;                  % 28 GHz
p.df = 120e3;                 % 子载波间隔 120 kHz
p.Tu = 8.33e-6;               % 有效符号时长
p.Tcp = 0.6e-6;               % CP时长
p.T  = 8.93e-6;               % 总符号时长 Tu + Tcp

% 阵列参数（基准值，后续会按天线数列表覆盖）
p.Ntx = 4;
p.Mrx = 4;
p.lambda_c = p.c / p.fc;
p.dt = p.lambda_c / 2;
p.dr = p.lambda_c / 2;

% 估计算法参数（降DFT点数）
p.Na = 64;
p.enable_1bit_quantization = true;
p.use_bussgang = true;
p.enable_cfar = true;
p.cfar_num_train = 8;
p.cfar_num_guard = 2;
p.cfar_pfa = 1e-3;
p.enable_interp = true;
p.eps_div = 1e-10;

% 时频资源（降规模）
p.N_RB = 24;
p.sc_per_RB = 12;
p.Ns = p.N_RB * p.sc_per_RB; % 288
p.L  = 32;

% 目标参数开关（默认：固定三目标，更稳定）
use_auto_multi_target = false;   % false: 固定三目标；true: 自动生成多目标

target_num = 3;                  % 仅在 use_auto_multi_target=true 时生效

if ~use_auto_multi_target
    % 固定三目标（恢复原配置）
    truth = struct();
    truth.theta_deg = [-22, 6, 28];
    truth.R = [32, 40, 55];
    truth.v = [-6, 8, 14];
    truth.beta = [1.0*exp(1j*pi/7), ...
                  0.85*exp(-1j*pi/5), ...
                  0.70*exp(1j*pi/3)];
else
    % 自动多目标（调试/扩展用）
    theta_min = -60;
    theta_max = 60;
    if target_num == 1
        theta_list = 12;
    else
        theta_list = linspace(theta_min, theta_max, target_num);
    end

    R_list = 25 + 8*(0:target_num-1);
    v_list = -12 + 24*(0:target_num-1)/max(target_num-1,1);

    beta_amp = 1.0 * (0.85 .^ (0:target_num-1));
    beta_phase = 2*pi*rand(1, target_num);
    beta_list = beta_amp .* exp(1j*beta_phase);

    truth = struct();
    truth.theta_deg = theta_list;
    truth.R = R_list;
    truth.v = v_list;
    truth.beta = beta_list;
end

% SNR扫描与Monte Carlo
snr_db_list =-20:5:20;
mc_trials = 50;

% 对比不同接收天线数
mrx_list = [4, 16, 64];

%% ===== 2) 仿真主循环（带进度条）：对比有/无单比特 + 不同天线数 =====
num_m = numel(mrx_list);
num_snr = numel(snr_db_list);
rmse_1bit_deg = zeros(num_m, num_snr);
rmse_full_deg = zeros(num_m, num_snr);

n_total = num_m * num_snr * mc_trials * 2; % 每次试验估计两条曲线
step = 0;
h = waitbar(0, 'RMSE对比仿真进行中...');
cleaner = onCleanup(@() close_waitbar_safe(h));

for im = 1:num_m
    % 当前天线配置
    p_cur = p;
    p_cur.Mrx = mrx_list(im);
    p_cur.Ntx = mrx_list(im);  % 为公平对比，发射与接收同规模
    p_cur.Na = max(64, 2 * p_cur.Mrx);

    % 配置1：单比特
    p_1bit = p_cur;
    p_1bit.enable_1bit_quantization = true;
    p_1bit.use_bussgang = true;

    % 配置2：无单比特（全精度）
    p_full = p_cur;
    p_full.enable_1bit_quantization = false;
    p_full.use_bussgang = false;

    for is = 1:num_snr
        snr_db = snr_db_list(is);
        err2_acc_1bit = 0;
        err2_acc_full = 0;

        for it = 1:mc_trials
            % 生成一帧数据（含噪声）
            [y, x] = gen_one_frame(p_cur, truth, snr_db);

            % 单比特估计
            est_1bit = angle_1bit_dft_estimator(y, x, p_1bit, []);
            e1_all = wrapTo180(est_1bit.theta_deg - truth.theta_deg(:).');
            e1 = min(abs(e1_all));  % 与最近真实目标角比较
            err2_acc_1bit = err2_acc_1bit + e1.^2;
            step = step + 1;

            % 全精度估计
            est_full = angle_1bit_dft_estimator(y, x, p_full, []);
            e2_all = wrapTo180(est_full.theta_deg - truth.theta_deg(:).');
            e2 = min(abs(e2_all));  % 与最近真实目标角比较
            err2_acc_full = err2_acc_full + e2.^2;
            step = step + 1;

            % 更新进度条
            if mod(step, 20) == 0 || step == n_total
                waitbar(step / n_total, h, sprintf('M=%d | SNR=%+d dB | %d/%d', p_cur.Mrx, snr_db, step, n_total));
            end
        end

        rmse_1bit_deg(im, is) = sqrt(err2_acc_1bit / mc_trials);
        rmse_full_deg(im, is) = sqrt(err2_acc_full / mc_trials);
    end
end

%% ===== 3) 绘图：RMSE vs SNR（有/无单比特 + 不同天线数） =====
fig = figure('Color', 'w', 'Position', [100, 100, 980, 580]);
hold on;
grid on; box on;

colors = [0.10 0.35 0.75; 0.10 0.60 0.25; 0.55 0.25 0.80];
for im = 1:num_m
    c = colors(im, :);
    plot(snr_db_list, rmse_1bit_deg(im, :), '-o', 'LineWidth', 1.8, 'MarkerSize', 6, ...
        'Color', c, 'MarkerFaceColor', c, ...
        'DisplayName', sprintf('1-bit, M=%d', mrx_list(im)));
    plot(snr_db_list, rmse_full_deg(im, :), '--s', 'LineWidth', 1.8, 'MarkerSize', 6, ...
        'Color', c, 'MarkerFaceColor', 'w', ...
        'DisplayName', sprintf('Full-Precision, M=%d', mrx_list(im)));
end

xlabel('SNR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Angle RMSE (deg)', 'FontSize', 12, 'FontWeight', 'bold');
title('Angle RMSE vs SNR under Different Antenna Numbers', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'northeastoutside');
set(gca, 'FontName', 'Times New Roman', 'FontSize', 11, 'LineWidth', 1.1);

% 保存结果
out_png = fullfile(pwd, 'rmse_vs_snr_compare_antenna_1bit_full.png');
exportgraphics(fig, out_png, 'Resolution', 300);

fprintf('\n===== 仿真完成 =====\n');
fprintf('输出图像：\n- %s\n', out_png);

for im = 1:num_m
    T = table(snr_db_list(:), rmse_1bit_deg(im,:).', rmse_full_deg(im,:).', ...
        'VariableNames', {'SNR_dB','RMSE_1bit_deg','RMSE_Full_deg'});
    fprintf('\n---- M = %d ----\n', mrx_list(im));
    disp(T);
end

%% ===== 4) 额外实验：RMSE vs 子载波数（风格与前图一致） =====
% 固定一个中等SNR，比较不同子载波数下的RMSE变化
snr_db_fixed = 0;
ns_list = [72, 144, 288, 576];
num_ns = numel(ns_list);

rmse_ns_1bit_deg = zeros(num_m, num_ns);
rmse_ns_full_deg = zeros(num_m, num_ns);

n_total_ns = num_m * num_ns * mc_trials * 2;
step_ns = 0;
h2 = waitbar(0, 'RMSE-子载波数对比仿真进行中...');
cleaner2 = onCleanup(@() close_waitbar_safe(h2));

for im = 1:num_m
    p_cur = p;
    p_cur.Mrx = mrx_list(im);
    p_cur.Ntx = mrx_list(im);
    p_cur.Na = max(64, 2 * p_cur.Mrx);

    p_1bit = p_cur;
    p_1bit.enable_1bit_quantization = true;
    p_1bit.use_bussgang = true;

    p_full = p_cur;
    p_full.enable_1bit_quantization = false;
    p_full.use_bussgang = false;

    for in = 1:num_ns
        p_cur.Ns = ns_list(in);
        p_1bit.Ns = ns_list(in);
        p_full.Ns = ns_list(in);

        err2_acc_1bit = 0;
        err2_acc_full = 0;

        for it = 1:mc_trials
            [y, x] = gen_one_frame(p_cur, truth, snr_db_fixed);

            est_1bit = angle_1bit_dft_estimator(y, x, p_1bit, []);
            e1_all = wrapTo180(est_1bit.theta_deg - truth.theta_deg(:).');
            e1 = min(abs(e1_all));
            err2_acc_1bit = err2_acc_1bit + e1.^2;
            step_ns = step_ns + 1;

            est_full = angle_1bit_dft_estimator(y, x, p_full, []);
            e2_all = wrapTo180(est_full.theta_deg - truth.theta_deg(:).');
            e2 = min(abs(e2_all));
            err2_acc_full = err2_acc_full + e2.^2;
            step_ns = step_ns + 1;

            if mod(step_ns, 20) == 0 || step_ns == n_total_ns
                waitbar(step_ns / n_total_ns, h2, sprintf('M=%d | Ns=%d | %d/%d', p_cur.Mrx, p_cur.Ns, step_ns, n_total_ns));
            end
        end

        rmse_ns_1bit_deg(im, in) = sqrt(err2_acc_1bit / mc_trials);
        rmse_ns_full_deg(im, in) = sqrt(err2_acc_full / mc_trials);
    end
end

fig2 = figure('Color', 'w', 'Position', [120, 120, 980, 580]);
hold on;
grid on; box on;

colors = [0.10 0.35 0.75; 0.10 0.60 0.25; 0.55 0.25 0.80];
for im = 1:num_m
    c = colors(im, :);
    plot(ns_list, rmse_ns_1bit_deg(im, :), '-o', 'LineWidth', 1.8, 'MarkerSize', 6, ...
        'Color', c, 'MarkerFaceColor', c, ...
        'DisplayName', sprintf('1-bit, M=%d', mrx_list(im)));
    plot(ns_list, rmse_ns_full_deg(im, :), '--s', 'LineWidth', 1.8, 'MarkerSize', 6, ...
        'Color', c, 'MarkerFaceColor', 'w', ...
        'DisplayName', sprintf('Full-Precision, M=%d', mrx_list(im)));
end

xlabel('Number of Subcarriers (N_s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Angle RMSE (deg)', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Angle RMSE vs Subcarriers at SNR = %+d dB', snr_db_fixed), 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'northeastoutside');
set(gca, 'FontName', 'Times New Roman', 'FontSize', 11, 'LineWidth', 1.1);

out_png2 = fullfile(pwd, 'rmse_vs_subcarriers_compare_antenna_1bit_full.png');
exportgraphics(fig2, out_png2, 'Resolution', 300);

fprintf('\n===== 子载波数对比仿真完成 =====\n');
fprintf('输出图像：\n- %s\n', out_png2);

%% ===== 本脚本所需局部函数 =====
function [y, x] = gen_one_frame(p, truth, snr_db)
% 生成多目标MIMO-OFDM回波：
% y(m,i,l) = sum_q beta_q * a_tx^H(theta_q)*x(:,i,l) * exp(j*m*wa_q) * exp(j*i*wr_q) * exp(j*l*wv_q) + z

Ntx = p.Ntx;
Mrx = p.Mrx;
Ns  = p.Ns;
L   = p.L;

lambda_c = p.lambda_c;

theta_list = deg2rad(truth.theta_deg(:).');
R_list = truth.R(:).';
v_list = truth.v(:).';
beta_list = truth.beta(:).';
Q = numel(theta_list);

assert(numel(R_list)==Q && numel(v_list)==Q && numel(beta_list)==Q, ...
    'truth.theta_deg / R / v / beta 的目标数必须一致');

% 发射QPSK符号（单位功率）
const = [1+1j, 1-1j, -1+1j, -1-1j] / sqrt(2);
idx = randi(4, [Ntx, Ns, L]);
x = const(idx);

n_tx = (0:Ntx-1).';
m = (0:Mrx-1).';
i = 0:(Ns-1);
l = 0:(L-1);

% 构造无噪回波（多目标叠加）
y_clean = zeros(Mrx, Ns, L);
for q = 1:Q
    theta = theta_list(q);
    R = R_list(q);
    v = v_list(q);
    beta = beta_list(q);

    a_tx = exp(1j * 2*pi * n_tx * (p.dt * sin(theta) / lambda_c));
    s = squeeze(sum(conj(a_tx) .* x, 1));  % [Ns,L]

    wa = -2*pi * p.dr / lambda_c * sin(theta);
    wr = -4*pi * p.df * R / p.c;
    wv =  4*pi * p.T  * v / lambda_c;

    phase_m = exp(1j * m * wa);            % [Mrx,1]
    phase_i = exp(1j * i * wr);            % [1,Ns]
    phase_l = exp(1j * l * wv);            % [1,L]

    for ll = 1:L
        y_clean(:, :, ll) = y_clean(:, :, ll) + ...
            beta * (phase_m * (phase_i .* (s(:, ll).' * phase_l(ll))));
    end
end

% 按目标SNR加噪
sig_pow = mean(abs(y_clean(:)).^2);
noise_pow = sig_pow / (10^(snr_db/10));
noise_sigma = sqrt(noise_pow/2);
z = noise_sigma * (randn(Mrx, Ns, L) + 1j * randn(Mrx, Ns, L));

y = y_clean + z;
end

function close_waitbar_safe(h)
if ~isempty(h) && isvalid(h)
    close(h);
end
end