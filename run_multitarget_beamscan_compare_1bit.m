%% run_multitarget_beamscan_compare_1bit.m
% Multi-target beam-scan comparison with averaged spectra over multiple targets.
% Targets are evaluated individually, then the beam-scan spectra are averaged.
%
% This script is standalone and does NOT reuse the RMSE plotting script.
% It compares:
% - 1-bit + DFT
% - 1-bit + Improved DFT
% - DFT
% - Improved DFT

clear; clc; close all;
rng(20260413, 'twister');

%% ===== 1) Common setup =====
p0 = struct();
p0.c = 3e8;
p0.fc = 28e9;
p0.df = 120e3;
p0.Tu = 8.33e-6;
p0.Tcp = 0.6e-6;
p0.T = 8.93e-6;
p0.lambda_c = p0.c / p0.fc;

p0.Ntx = 16;
p0.Mrx = 16;
p0.dt = p0.lambda_c / 2;
p0.dr = p0.lambda_c / 2;
p0.na_ratio = 8;
p0.Na = p0.na_ratio * p0.Mrx;

p0.Ns = 256;
p0.L = 32;

p0.num_targets = 5;
p0.eps_div = 1e-10;

% Peak-selection settings for DFT-family methods.
p0.enable_cfar = true;
p0.cfar_num_train = 16;
p0.cfar_num_guard = 4;
p0.cfar_pfa = 1e-3;
p0.selection_guard_bins = 4;

truth = struct();
truth.theta_deg = [-36, -18, 0, 18.4, 36];
truth.R = [34, 50, 66, 82, 98];
truth.v = [-12, -6, 0, 6, 12];
truth.beta = [ ...
    1.00 * exp(1j * pi / 9), ...
    0.96 * exp(1j * 2 * pi / 7), ...
    0.92 * exp(1j * 5 * pi / 13), ...
    0.94 * exp(1j * 3 * pi / 8), ...
    0.90 * exp(1j * 4 * pi / 11)];

target_idx_list = 3:5;     % average over three targets
snr_db = 10;               % fixed SNR for the beam-scan figure
mc_trials = 100;
desired_workers = 8;
seed_base = 2026041300;

algorithms = struct( ...
    'name', { ...
        '1-bit + DFT', ...
        '1-bit + Improved DFT', ...
        'DFT', ...
        'Improved DFT'}, ...
    'tag', { ...
        'onebit_dft', ...
        'onebit_dft_improved', ...
        'full_dft', ...
        'full_dft_improved'});

num_alg = numel(algorithms);

%% ===== 2) Parallel pool =====
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
    warning('parpool(%d) failed, fallback to serial mode.\n%s', desired_workers, ME.message);
    use_parallel = false;
end

%% ===== 3) Monte Carlo beam-scan accumulation =====
beam_spectrum_accum = [];
beam_theta_axis = [];
num_targets_eval = numel(target_idx_list);

fprintf('===== Beam-scan averaging over targets %s at SNR = %+d dB =====\n', mat2str(target_idx_list), snr_db);
progress_fig = waitbar(0, 'Preparing beam-scan trials...', 'Name', '1-bit DFT beam-scan progress');
progress_cleanup = onCleanup(@() safe_close_waitbar(progress_fig));

for it = 1:mc_trials
    trial_seed = seed_base + it;
    rng(trial_seed, 'twister');
    [y, x] = gen_multi_target_frame(p0, truth, snr_db);

    trial_spec = local_run_beamscan_trial(y, x, p0, algorithms);

    if isempty(beam_spectrum_accum)
        beam_spectrum_accum = zeros(num_alg, numel(trial_spec.theta_axis_deg));
        beam_theta_axis = trial_spec.theta_axis_deg;
    end

    beam_spectrum_accum = beam_spectrum_accum + trial_spec.spectrum_avg_targets;

    if mod(it, max(1, round(mc_trials / 10))) == 0 || it == mc_trials
        fprintf('Trial %d/%d finished.\n', it, mc_trials);
    end
    waitbar(it / mc_trials, progress_fig, sprintf('Beam-scan trial %d/%d', it, mc_trials));
end

beam_spectrum_mean = beam_spectrum_accum / mc_trials;

%% ===== 4) Plot =====
style = {
    '--', 'o', [0.00, 0.45, 0.74];
    '--', 's', [0.85, 0.33, 0.10];
    '-',  'o', [0.00, 0.45, 0.74];
    '-',  's', [0.85, 0.33, 0.10]};

fig = figure('Color', 'w', 'Position', [120, 120, 1040, 620]);
hold on;
grid on;
box on;

for ia = 1:num_alg
    plot_vals = max(beam_spectrum_mean(ia, :), 1e-10);
    semilogy(beam_theta_axis, plot_vals, ...
        'LineStyle', style{ia, 1}, ...
        'Marker', style{ia, 2}, ...
        'Color', style{ia, 3}, ...
        'MarkerFaceColor', style{ia, 3}, ...
        'LineWidth', 1.9, ...
        'MarkerSize', 5, ...
        'DisplayName', algorithms(ia).name);
end

xlabel('Angle (deg)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Averaged beam-scan power', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Multi-Target Beam-Scan Comparison (Targets %d-%d averaged, SNR = %+d dB)', ...
    target_idx_list(1), target_idx_list(end), snr_db), 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'northeastoutside');
set(gca, 'YScale', 'log', 'FontName', 'Times New Roman', 'FontSize', 11, 'LineWidth', 1.1);

%% ===== 5) Save outputs =====
out_png = fullfile(pwd, sprintf('beamscan_targets_%d_%d_%d_snr_%+d_1bit_compare.png', ...
    target_idx_list(1), target_idx_list(2), target_idx_list(3), snr_db));

exportgraphics(fig, out_png, 'Resolution', 300);

fprintf('\n===== Beam-scan experiment finished =====\n');
fprintf('Targets under test: %s\n', mat2str(target_idx_list));
fprintf('Truth angles = %s deg\n', mat2str(truth.theta_deg(target_idx_list)));
fprintf('Output file:\n');
fprintf('- %s\n', out_png);

%% ===== Local functions =====
function trial_spec = local_run_beamscan_trial(y, x, p, algorithms)
num_alg = numel(algorithms);
accum = [];
axis_deg = [];

for ia = 1:num_alg
    switch algorithms(ia).tag
        case 'onebit_dft'
            p_tmp = p;
            p_tmp.enable_1bit_quantization = true;
            p_tmp.use_bussgang = false;
            p_tmp.enable_peak_search = false;
            p_tmp.enable_interp = false;
            [~, debug] = angle_1bit_dft_multi_estimator(y, x, p_tmp);
        case 'onebit_dft_improved'
            p_tmp = p;
            p_tmp.enable_1bit_quantization = true;
            p_tmp.use_bussgang = true;
            p_tmp.enable_peak_search = false;
            p_tmp.enable_interp = false;
            [~, debug] = angle_1bit_dft_multi_estimator(y, x, p_tmp);
        case 'full_dft'
            p_tmp = p;
            p_tmp.enable_1bit_quantization = false;
            p_tmp.use_bussgang = false;
            p_tmp.enable_peak_search = false;
            p_tmp.enable_interp = false;
            [~, debug] = angle_1bit_dft_multi_estimator(y, x, p_tmp);
        case 'full_dft_improved'
            p_tmp = p;
            p_tmp.enable_1bit_quantization = false;
            p_tmp.use_bussgang = false;
            p_tmp.enable_peak_search = false;
            p_tmp.enable_interp = false;
            [~, debug] = angle_1bit_dft_multi_estimator(y, x, p_tmp);
        otherwise
            error('Unknown algorithm tag: %s', algorithms(ia).tag);
    end

    if isempty(axis_deg)
        axis_deg = debug.angle_axis_deg(:).';
        accum = zeros(num_alg, numel(axis_deg));
    end

    spec = debug.angle_spectrum(:).';
    accum(ia, :) = spec;
end

trial_spec = struct();
trial_spec.theta_axis_deg = axis_deg;
trial_spec.spectrum_avg_targets = accum;
end

function safe_close_waitbar(h)
if ~isempty(h) && isgraphics(h)
    close(h);
end
end

function [y, x] = gen_multi_target_frame(p, truth, snr_db)
Ntx = p.Ntx;
Mrx = p.Mrx;
Ns = p.Ns;
L = p.L;
Q = p.num_targets;

const = [1+1j, 1-1j, -1+1j, -1-1j] / sqrt(2 * Ntx);
idx = randi(4, [Ntx, Ns, L]);
x = const(idx);

m = (0:Mrx-1).';
i = 0:(Ns-1);
l = 0:(L-1);

y_clean = zeros(Mrx, Ns, L);
for q = 1:Q
    theta = deg2rad(truth.theta_deg(q));
    R = truth.R(q);
    v = truth.v(q);
    beta = truth.beta(q);

    n_tx = (0:Ntx-1).';
    a_tx = exp(1j * 2 * pi * n_tx * (p.dt * sin(theta) / p.lambda_c));

    wa = -2 * pi * p.dr / p.lambda_c * sin(theta);
    wr = -4 * pi * p.df * R / p.c;
    wv =  4 * pi * p.T * v / p.lambda_c;

    phase_m = exp(1j * m * wa);
    phase_i = exp(1j * i * wr);
    phase_l = exp(1j * l * wv);

    s = squeeze(sum(conj(a_tx) .* x, 1));
    for ll = 1:L
        y_clean(:, :, ll) = y_clean(:, :, ll) + beta * (phase_m * (phase_i .* (s(:, ll).' * phase_l(ll))));
    end
end

sig_pow = mean(abs(y_clean(:)).^2);
noise_pow = sig_pow / (10^(snr_db / 10));
noise_sigma = sqrt(noise_pow / 2);
z = noise_sigma * (randn(Mrx, Ns, L) + 1j * randn(Mrx, Ns, L));
y = y_clean + z;
end
