%% run_rmse_vs_subcarriers_1bit_dft.m
% 单独脚本：横轴子载波数 Ns，纵轴角度RMSE
% 对比：1-bit+Bussgang vs Full-Precision；并比较不同天线数 M
% 依赖：angle_1bit_dft_estimator.m

clear; clc; close all;
rng(20260412, 'twister');

%% ===== 1) 参数设置 =====
p = struct();
p.c  = 3e8;
p.fc = 28e9;
p.df = 120e3;
p.Tu = 8.33e-6;
p.Tcp = 0.6e-6;
p.T  = 8.93e-6;

p.lambda_c = p.c / p.fc;
p.dt = p.lambda_c / 2;
p.dr = p.lambda_c / 2;

% 估计算法参数
p.Na = 64;
p.enable_1bit_quantization = true;
p.use_bussgang = true;
p.enable_cfar = true;
p.cfar_num_train = 8;
p.cfar_num_guard = 2;
p.cfar_pfa = 1e-3;
p.enable_interp = true;
p.eps_div = 1e-10;

% 资源与仿真参数
p.L = 32;
snr_db_fixed = 0;
mc_trials = 50;
mrx_list = [4, 16, 32];
ns_list = [48, 72, 144, 288, 576, 864];

% 目标参数（默认固定3目标，稳定版）
use_auto_multi_target = false;   % false: 固定三目标；true: 自动多目标
target_num = 3;                  % 仅在true时生效

if ~use_auto_multi_target
    truth = struct();
    truth.theta_deg = [-22, 6, 28];
    truth.R = [32, 40, 55];
    truth.v = [-6, 8, 14];
    truth.beta = [1.0*exp(1j*pi/7), 0.85*exp(-1j*pi/5), 0.70*exp(1j*pi/3)];
else
    theta_min = -60; theta_max = 60;
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

%% ===== 2) 主循环（带进度条） =====
num_m = numel(mrx_list);
num_ns = numel(ns_list);
rmse_ns_1bit_deg = zeros(num_m, num_ns);
rmse_ns_full_deg = zeros(num_m, num_ns);

n_total = num_m * num_ns * mc_trials * 2;
step = 0;
h = waitbar(0, 'RMSE-子载波数对比仿真进行中...');
cleaner = onCleanup(@() close_waitbar_safe(h));

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
            [y, x] = gen_one_frame_multi_target(p_cur, truth, snr_db_fixed);

            est_1bit = angle_1bit_dft_estimator(y, x, p_1bit, []);
            e1_all = wrapTo180(est_1bit.theta_deg - truth.theta_deg(:).');
            e1 = min(abs(e1_all));
            err2_acc_1bit = err2_acc_1bit + e1.^2;
            step = step + 1;

            est_full = angle_1bit_dft_estimator(y, x, p_full, []);
            e2_all = wrapTo180(est_full.theta_deg - truth.theta_deg(:).');
            e2 = min(abs(e2_all));
            err2_acc_full = err2_acc_full + e2.^2;
            step = step + 1;

            if mod(step, 20) == 0 || step == n_total
                waitbar(step / n_total, h, sprintf('M=%d | Ns=%d | %d/%d', p_cur.Mrx, p_cur.Ns, step, n_total));
            end
        end

        rmse_ns_1bit_deg(im, in) = sqrt(err2_acc_1bit / mc_trials);
        rmse_ns_full_deg(im, in) = sqrt(err2_acc_full / mc_trials);
    end
end

%% ===== 3) 绘图 =====
fig = figure('Color', 'w', 'Position', [120, 120, 980, 580]);
hold on; grid on; box on;

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

out_png = fullfile(pwd, 'rmse_vs_subcarriers_compare_antenna_1bit_full.png');
out_pdf = fullfile(pwd, 'rmse_vs_subcarriers_compare_antenna_1bit_full.pdf');
exportgraphics(fig, out_png, 'Resolution', 300);
exportgraphics(fig, out_pdf, 'ContentType', 'vector');

fprintf('\n===== 子载波数对比仿真完成 =====\n');
fprintf('输出图像：\n- %s\n- %s\n', out_png, out_pdf);

for im = 1:num_m
    T = table(ns_list(:), rmse_ns_1bit_deg(im,:).', rmse_ns_full_deg(im,:).', ...
        'VariableNames', {'Ns','RMSE_1bit_deg','RMSE_Full_deg'});
    fprintf('\n---- M = %d ----\n', mrx_list(im));
    disp(T);
end

%% ===== 局部函数 =====
function [y, x] = gen_one_frame_multi_target(p, truth, snr_db)
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

const = [1+1j, 1-1j, -1+1j, -1-1j] / sqrt(2);
idx = randi(4, [Ntx, Ns, L]);
x = const(idx);

n_tx = (0:Ntx-1).';
m = (0:Mrx-1).';
i = 0:(Ns-1);
l = 0:(L-1);

y_clean = zeros(Mrx, Ns, L);
for q = 1:Q
    theta = theta_list(q);
    R = R_list(q);
    v = v_list(q);
    beta = beta_list(q);

    a_tx = exp(1j * 2*pi * n_tx * (p.dt * sin(theta) / lambda_c));
    s = squeeze(sum(conj(a_tx) .* x, 1));

    wa = -2*pi * p.dr / lambda_c * sin(theta);
    wr = -4*pi * p.df * R / p.c;
    wv =  4*pi * p.T  * v / lambda_c;

    phase_m = exp(1j * m * wa);
    phase_i = exp(1j * i * wr);
    phase_l = exp(1j * l * wv);

    for ll = 1:L
        y_clean(:, :, ll) = y_clean(:, :, ll) + ...
            beta * (phase_m * (phase_i .* (s(:, ll).' * phase_l(ll))));
    end
end

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
