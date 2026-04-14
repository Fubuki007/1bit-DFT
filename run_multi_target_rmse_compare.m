%% run_multi_target_rmse_compare.m
% Multi-target angle RMSE comparison for the 1-bit spatial-DFT paper method.
% The experiment keeps 5 targets fixed and evaluates one selected target.

clear; clc; close all;
rng(20260413, 'twister');

%% ===== 1) System setup =====
p = struct();
p.c = 3e8;
p.fc = 28e9;
p.df = 120e3;
p.Tu = 8.33e-6;
p.Tcp = 0.6e-6;
p.T = 8.93e-6;

p.lambda_c = p.c / p.fc;
p.Ntx = 16;
p.Mrx = 16;
p.dt = p.lambda_c / 2;
p.dr = p.lambda_c / 2;
p.Na = 48;

p.Ns = 256;
p.L = 64;

p.num_targets = 5;
p.enable_cfar = true;
p.cfar_num_train = 8;
p.cfar_num_guard = 2;
p.cfar_pfa = 1e-3;
p.selection_guard_bins = 2;
p.eps_div = 1e-10;

truth = struct();
truth.theta_deg = [-28, -12, 4, 20, 36];
truth.R = [36, 50, 64, 78, 92];
truth.v = [-12, -6, 0, 6, 12];
truth.beta = [
    1.00 * exp(1j * pi / 9), ...
    0.95 * exp(1j * 2 * pi / 7), ...
    0.90 * exp(1j * 5 * pi / 13), ...
    0.92 * exp(1j * 3 * pi / 8), ...
    0.88 * exp(1j * 4 * pi / 11)];

target_idx = 4;
snr_db_list = -20:5:20;
mc_trials = 100;
desired_workers = 8;

algorithms = struct( ...
    'name', { ...
        'Full-Precision + Peak Search + Interp', ...
        '1-bit + No Peak Search + No Interp', ...
        '1-bit + Peak Search + No Interp', ...
        '1-bit + Peak Search + Interp'}, ...
    'tag', { ...
        'full_precision', ...
        'onebit_plain', ...
        'onebit_peak', ...
        'onebit_full'}, ...
    'enable_1bit_quantization', {false, true, true, true}, ...
    'use_bussgang', {false, true, true, true}, ...
    'enable_peak_search', {true, false, true, true}, ...
    'enable_interp', {true, false, false, true});

num_alg = numel(algorithms);
num_snr = numel(snr_db_list);
rmse_deg = zeros(num_alg, num_snr);

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

%% ===== 3) Monte Carlo RMSE =====
seed_base = 2026041300;

for is = 1:num_snr
    snr_db = snr_db_list(is);
    err_sq_this_snr = zeros(num_alg, mc_trials);

    if use_parallel
        parfor it = 1:mc_trials
            trial_seed = seed_base + 1000 * is + it;
            err_sq_this_snr(:, it) = run_one_trial(p, truth, algorithms, target_idx, snr_db, trial_seed);
        end
    else
        for it = 1:mc_trials
            trial_seed = seed_base + 1000 * is + it;
            err_sq_this_snr(:, it) = run_one_trial(p, truth, algorithms, target_idx, snr_db, trial_seed);
        end
    end

    rmse_deg(:, is) = sqrt(mean(err_sq_this_snr, 2));
    fprintf('SNR = %+3d dB finished.\n', snr_db);
end

%% ===== 4) Plot =====
fig = figure('Color', 'w', 'Position', [120, 120, 980, 580]);
hold on;
grid on;
box on;

style = {
    '-',  'o', [0.10, 0.35, 0.75];
    '--', 's', [0.85, 0.33, 0.10];
    '-.', '^', [0.10, 0.60, 0.25];
    '-',  'd', [0.55, 0.20, 0.65]};

for ia = 1:num_alg
    semilogy(snr_db_list, rmse_deg(ia, :), ...
        'LineStyle', style{ia, 1}, ...
        'Marker', style{ia, 2}, ...
        'Color', style{ia, 3}, ...
        'MarkerFaceColor', style{ia, 3}, ...
        'LineWidth', 1.9, ...
        'MarkerSize', 6, ...
        'DisplayName', algorithms(ia).name);
end

xlabel('SNR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(sprintf('Target %d Angle RMSE (deg)', target_idx), 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Multi-Target Angle RMSE vs SNR (Target %d at %.1f^\\circ)', target_idx, truth.theta_deg(target_idx)), ...
    'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'northeastoutside');
set(gca, 'YScale', 'log', 'FontName', 'Times New Roman', 'FontSize', 11, 'LineWidth', 1.1);

out_png = fullfile(pwd, sprintf('rmse_vs_snr_target_%d_multitarget_4curves.png', target_idx));
out_pdf = fullfile(pwd, sprintf('rmse_vs_snr_target_%d_multitarget_4curves.pdf', target_idx));
out_mat = fullfile(pwd, sprintf('rmse_vs_snr_target_%d_multitarget_4curves.mat', target_idx));

exportgraphics(fig, out_png, 'Resolution', 300);
exportgraphics(fig, out_pdf, 'ContentType', 'vector');
save(out_mat, 'p', 'truth', 'algorithms', 'target_idx', 'snr_db_list', 'mc_trials', 'desired_workers', 'rmse_deg');

fprintf('\n===== Experiment finished =====\n');
fprintf('Target under test: #%d, truth angle = %.2f deg\n', target_idx, truth.theta_deg(target_idx));
fprintf('Output files:\n- %s\n- %s\n- %s\n', out_png, out_pdf, out_mat);

result_table = table(snr_db_list(:), rmse_deg(1, :).', rmse_deg(2, :).', rmse_deg(3, :).', rmse_deg(4, :).', ...
    'VariableNames', {'SNR_dB', 'RMSE_FullPrecision', 'RMSE_1bit_NoPeak_NoInterp', 'RMSE_1bit_PeakOnly', 'RMSE_1bit_PeakInterp'});
disp(result_table);

%% ===== Local functions =====
function err_sq_vec = run_one_trial(p, truth, algorithms, target_idx, snr_db, trial_seed)
rng(trial_seed, 'twister');
[y, x] = gen_multi_target_frame(p, truth, snr_db);

num_alg = numel(algorithms);
err_sq_vec = zeros(num_alg, 1);

for ia = 1:num_alg
    p_alg = p;
    p_alg.enable_1bit_quantization = algorithms(ia).enable_1bit_quantization;
    p_alg.use_bussgang = algorithms(ia).use_bussgang;
    p_alg.enable_peak_search = algorithms(ia).enable_peak_search;
    p_alg.enable_interp = algorithms(ia).enable_interp;

    est = angle_1bit_dft_multi_estimator(y, x, p_alg);
    theta_hat = est.theta_deg(target_idx);
    err_sq_vec(ia) = wrap_to_180(theta_hat - truth.theta_deg(target_idx))^2;
end
end

function [y, x] = gen_multi_target_frame(p, truth, snr_db)
Ntx = p.Ntx;
Mrx = p.Mrx;
Ns = p.Ns;
L = p.L;
Q = p.num_targets;

const = [1+1j, 1-1j, -1+1j, -1-1j] / sqrt(2);
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

function x = wrap_to_180(x)
x = mod(x + 180, 360) - 180;
end
