%% run_multitarget_threefig_compare_1bit.m
% Multi-target 1-bit angle-RMSE comparison with three x-axes.
% 1) SNR
% 2) antenna number
% 3) subcarrier number
%
% Curves:
% - 1-bit + ESPRIT
% - 1-bit + MUSIC
% - 1-bit + DFT
% - 1-bit + improved DFT in the paper (scaling factor + interpolation)

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
truth.theta_deg = [-36, -18, 0, 18, 36];
truth.R = [34, 50, 66, 82, 98];
truth.v = [-12, -6, 0, 6, 12];
truth.beta = [ ...
    1.00 * exp(1j * pi / 9), ...
    0.96 * exp(1j * 2 * pi / 7), ...
    0.92 * exp(1j * 5 * pi / 13), ...
    0.94 * exp(1j * 3 * pi / 8), ...
    0.90 * exp(1j * 4 * pi / 11)];

target_idx = 4;                  % Evaluate the 4th target only.
target_match_mode = 'nearest_true_angle';
mc_trials = 100;
desired_workers = 8;

snr_db_list = -20:5:20;
snr_db_fixed = 0;
antenna_list = [8, 16, 24, 32, 64, 128, 192, 256];
subcarrier_list = [32, 64, 128, 256, 512];

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
checkpoint_file = fullfile(pwd, sprintf('multitarget_threefig_target_%d_1bit_compare_checkpoint.mat', target_idx));

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

%% ===== 3) Progress bar =====
run_snr_sweep = true;
run_antenna_sweep = false;      % turn on later if needed
run_subcarrier_sweep = false;   % turn on later if needed

progress_total = numel(snr_db_list) * run_snr_sweep + numel(antenna_list) * run_antenna_sweep + numel(subcarrier_list) * run_subcarrier_sweep;
progress_done = 0;
progress_fig = waitbar(0, 'Preparing sweeps...', 'Name', '1-bit DFT experiment progress');
progress_cleanup = onCleanup(@() safe_close_waitbar(progress_fig));

%% ===== 4) Three sweeps =====
rmse_vs_snr = zeros(num_alg, numel(snr_db_list));
rmse_vs_ant = nan(num_alg, numel(antenna_list));
rmse_vs_ns = nan(num_alg, numel(subcarrier_list));

seed_base = 2026041300;

if run_snr_sweep
    fprintf('===== Sweep 1/3: RMSE vs SNR =====\n');
    for is = 1:numel(snr_db_list)
        snr_db = snr_db_list(is);
        p_cur = configure_dft_grid_and_peak_params(p0);
        rmse_vs_snr(:, is) = run_mc_block(p_cur, truth, algorithms, target_idx, snr_db, mc_trials, use_parallel, seed_base + 10000 * is);
        fprintf('SNR = %+3d dB finished.\n', snr_db);
        progress_done = progress_done + 1;
        waitbar(progress_done / max(progress_total, 1), progress_fig, sprintf('Sweep 1/3: SNR = %+3d dB (%d/%d)', snr_db, progress_done, progress_total));
        save(checkpoint_file, 'rmse_vs_snr', 'rmse_vs_ant', 'rmse_vs_ns', 'snr_db_list', 'antenna_list', 'subcarrier_list', 'mc_trials', 'target_idx');
    end
end

if run_antenna_sweep
    fprintf('\n===== Sweep 2/3: RMSE vs antenna number =====\n');
    for ia = 1:numel(antenna_list)
        p_cur = p0;
        p_cur.Mrx = antenna_list(ia);
        % Sweep only the receive-array size while keeping the transmit side fixed.
        p_cur.Ntx = p0.Ntx;
        p_cur = configure_dft_grid_and_peak_params(p_cur);
        rmse_vs_ant(:, ia) = run_mc_block(p_cur, truth, algorithms, target_idx, snr_db_fixed, mc_trials, use_parallel, seed_base + 20000 * ia);
        fprintf('Mrx = %4d finished.\n', antenna_list(ia));
        progress_done = progress_done + 1;
        waitbar(progress_done / max(progress_total, 1), progress_fig, sprintf('Sweep 2/3: Mrx = %4d (%d/%d)', antenna_list(ia), progress_done, progress_total));
        save(checkpoint_file, 'rmse_vs_snr', 'rmse_vs_ant', 'rmse_vs_ns', 'snr_db_list', 'antenna_list', 'subcarrier_list', 'mc_trials', 'target_idx');
    end
else
    fprintf('\n===== Sweep 2/3: RMSE vs antenna number skipped =====\n');
end

if run_subcarrier_sweep
    fprintf('\n===== Sweep 3/3: RMSE vs subcarrier number =====\n');
    for in = 1:numel(subcarrier_list)
        p_cur = p0;
        p_cur.Ns = subcarrier_list(in);
        p_cur = configure_dft_grid_and_peak_params(p_cur);
        rmse_vs_ns(:, in) = run_mc_block(p_cur, truth, algorithms, target_idx, snr_db_fixed, mc_trials, use_parallel, seed_base + 30000 * in);
        fprintf('Ns = %3d finished.\n', subcarrier_list(in));
        progress_done = progress_done + 1;
        waitbar(progress_done / max(progress_total, 1), progress_fig, sprintf('Sweep 3/3: Ns = %3d (%d/%d)', subcarrier_list(in), progress_done, progress_total));
        save(checkpoint_file, 'rmse_vs_snr', 'rmse_vs_ant', 'rmse_vs_ns', 'snr_db_list', 'antenna_list', 'subcarrier_list', 'mc_trials', 'target_idx');
    end
else
    fprintf('\n===== Sweep 3/3: RMSE vs subcarrier number skipped =====\n');
end

%% ===== 4) Plot and save =====
style = {
    '-',  'o', [0.10, 0.35, 0.75];   % DFT: blue solid
    '--', 'o', [0.10, 0.35, 0.75];   % 1-bit + DFT: blue dashed
    '-',  's', [0.85, 0.33, 0.10];   % Improved DFT: orange solid
    '--', 's', [0.85, 0.33, 0.10]};  % 1-bit + Improved DFT: orange dashed

fig1 = plot_error_curve(snr_db_list, rmse_vs_snr, algorithms, style, ...
    'SNR (dB)', sprintf('Target %d Angle RMSE (deg)', target_idx), ...
    sprintf('Multi-Target 1-bit Angle RMSE vs SNR (Target %d at %.1f^\\circ)', target_idx, truth.theta_deg(target_idx)));

if run_antenna_sweep
    fig2 = plot_error_curve(antenna_list, rmse_vs_ant, algorithms, style, ...
        'Receive Antenna Number M_{rx}', sprintf('Target %d Angle RMSE (deg)', target_idx), ...
        sprintf('Multi-Target 1-bit Angle RMSE vs Receive Antenna Number (SNR = %+d dB, N_{tx} = %d)', snr_db_fixed, p0.Ntx));
else
    fig2 = [];
end

if run_subcarrier_sweep
    fig3 = plot_error_curve(subcarrier_list, rmse_vs_ns, algorithms, style, ...
        'Subcarrier Number N_s', sprintf('Target %d Angle RMSE (deg)', target_idx), ...
        sprintf('Multi-Target 1-bit Angle RMSE vs Subcarrier Number (SNR = %+d dB)', snr_db_fixed));
else
    fig3 = [];
end

out_png_1 = fullfile(pwd, sprintf('rmse_vs_snr_target_%d_1bit_esprit_music_dft_improved.png', target_idx));
out_pdf_1 = fullfile(pwd, sprintf('rmse_vs_snr_target_%d_1bit_esprit_music_dft_improved.pdf', target_idx));
out_png_2 = fullfile(pwd, sprintf('rmse_vs_antenna_target_%d_1bit_esprit_music_dft_improved.png', target_idx));
out_pdf_2 = fullfile(pwd, sprintf('rmse_vs_antenna_target_%d_1bit_esprit_music_dft_improved.pdf', target_idx));
out_png_3 = fullfile(pwd, sprintf('rmse_vs_subcarrier_target_%d_1bit_esprit_music_dft_improved.png', target_idx));
out_pdf_3 = fullfile(pwd, sprintf('rmse_vs_subcarrier_target_%d_1bit_esprit_music_dft_improved.pdf', target_idx));
out_mat = fullfile(pwd, sprintf('multitarget_threefig_target_%d_1bit_compare.mat', target_idx));

exportgraphics(fig1, out_png_1, 'Resolution', 300);
exportgraphics(fig1, out_pdf_1, 'ContentType', 'vector');

if run_antenna_sweep
    exportgraphics(fig2, out_png_2, 'Resolution', 300);
    exportgraphics(fig2, out_pdf_2, 'ContentType', 'vector');
end

if run_subcarrier_sweep
    exportgraphics(fig3, out_png_3, 'Resolution', 300);
    exportgraphics(fig3, out_pdf_3, 'ContentType', 'vector');
end

save(out_mat, ...
    'p0', 'truth', 'algorithms', 'target_idx', 'mc_trials', 'desired_workers', ...
    'target_match_mode', 'run_snr_sweep', 'run_antenna_sweep', 'run_subcarrier_sweep', ...
    'snr_db_list', 'snr_db_fixed', 'antenna_list', 'subcarrier_list', ...
    'rmse_vs_snr', 'rmse_vs_ant', 'rmse_vs_ns');

fprintf('\n===== Three-figure experiment finished =====\n');
fprintf('Target under test: #%d, truth angle = %.2f deg\n', target_idx, truth.theta_deg(target_idx));
fprintf('Output files:\n');
fprintf('- %s\n', out_png_1);
fprintf('- %s\n', out_pdf_1);
fprintf('- %s\n', out_png_2);
fprintf('- %s\n', out_pdf_2);
fprintf('- %s\n', out_png_3);
fprintf('- %s\n', out_pdf_3);
fprintf('- %s\n', out_mat);

disp(' ');
disp('RMSE vs SNR:');
disp(array2table([snr_db_list(:), rmse_vs_snr.'], ...
    'VariableNames', [{'SNR_dB'}, matlab.lang.makeValidName({algorithms.name})]));

if run_antenna_sweep
    disp('RMSE vs Antenna Number:');
    disp(array2table([antenna_list(:), rmse_vs_ant.'], ...
        'VariableNames', [{'ReceiveAntennaNumber'}, matlab.lang.makeValidName({algorithms.name})]));
end

if run_subcarrier_sweep
    disp('RMSE vs Subcarrier Number:');
    disp(array2table([subcarrier_list(:), rmse_vs_ns.'], ...
        'VariableNames', [{'SubcarrierNumber'}, matlab.lang.makeValidName({algorithms.name})]));
end

%% ===== Local functions =====
function rmse_vec = run_mc_block(p, truth, algorithms, target_idx, snr_db, mc_trials, use_parallel, seed_offset)
num_alg = numel(algorithms);
err_sq = zeros(num_alg, mc_trials);

if use_parallel
    parfor it = 1:mc_trials
        err_sq(:, it) = run_one_trial(p, truth, algorithms, target_idx, snr_db, seed_offset + it);
    end
else
    for it = 1:mc_trials
        err_sq(:, it) = run_one_trial(p, truth, algorithms, target_idx, snr_db, seed_offset + it);
    end
end

rmse_vec = sqrt(mean(err_sq, 2));
end

function safe_close_waitbar(h)
if ~isempty(h) && isgraphics(h)
    close(h);
end
end

function err_sq_vec = run_one_trial(p, truth, algorithms, target_idx, snr_db, trial_seed)
rng(trial_seed, 'twister');
[y, x] = gen_multi_target_frame(p, truth, snr_db);

num_alg = numel(algorithms);
err_sq_vec = zeros(num_alg, 1);

for ia = 1:num_alg
    switch algorithms(ia).tag
        case 'onebit_dft'
            theta_hat_all = estimate_angles_dft_1bit(y, p);
        case 'onebit_dft_improved'
            p_imp = p;
            p_imp.enable_1bit_quantization = true;
            p_imp.use_bussgang = true;
            p_imp.enable_peak_search = true;
            p_imp.enable_interp = true;
            est = angle_1bit_dft_multi_estimator(y, x, p_imp);
            theta_hat_all = est.theta_deg(:).';
        case 'full_dft'
            theta_hat_all = estimate_angles_dft(y, p);
        case 'full_dft_improved'
            p_full = p;
            p_full.enable_1bit_quantization = false;
            p_full.use_bussgang = false;
            p_full.enable_peak_search = true;
            p_full.enable_interp = true;
            est = angle_1bit_dft_multi_estimator(y, x, p_full);
            theta_hat_all = est.theta_deg(:).';
        otherwise
            error('Unknown algorithm tag: %s', algorithms(ia).tag);
    end

    theta_true = truth.theta_deg(target_idx);
    theta_hat = select_estimate_for_target(theta_hat_all, theta_true);
    err_sq_vec(ia) = wrap_to_180(theta_hat - theta_true)^2;
end
end

function [y, x] = gen_multi_target_frame(p, truth, snr_db)
Ntx = p.Ntx;
Mrx = p.Mrx;
Ns = p.Ns;
L = p.L;
Q = p.num_targets;

% Normalize per-antenna symbols by sqrt(Ntx) so total transmit power stays fixed.
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

function theta_hat_deg = estimate_angles_esprit_1bit(y, p)
    Yq = sign(real(y)) + 1j * sign(imag(y));
    Ysnap = reshape(Yq, p.Mrx, []);
    R = (Ysnap * Ysnap') / size(Ysnap, 2);
    R = forward_backward_average(R);
    num_sig = min(p.num_targets, max(1, p.Mrx - 1));
    Es = dominant_signal_subspace(R, num_sig);

    Es1 = Es(1:end-1, :);
    Es2 = Es(2:end, :);
Psi = pinv(Es1) * Es2;
lambda_est = eig(Psi);

wa_hat = angle(lambda_est);
sin_theta_hat = -(wa_hat * p.lambda_c) / (2 * pi * p.dr);
sin_theta_hat = max(-1, min(1, real(sin_theta_hat)));
theta_hat_deg = sort(rad2deg(asin(sin_theta_hat)), 'ascend').';
theta_hat_deg = complete_target_list(theta_hat_deg, p.num_targets);
end

function theta_hat_deg = estimate_angles_music_1bit(y, p)
    Yq = sign(real(y)) + 1j * sign(imag(y));
    Ysnap = reshape(Yq, p.Mrx, []);
    R = (Ysnap * Ysnap') / size(Ysnap, 2);
    R = forward_backward_average(R);
    num_sig = min(p.num_targets, max(1, p.Mrx - 1));
    Es = dominant_signal_subspace(R, num_sig);

    theta_grid_deg = -80:0.1:80;
    n = (0:p.Mrx-1).';
    steering = exp(-1j * 2 * pi * p.dr / p.lambda_c * n * sind(theta_grid_deg));
    residual = steering - Es * (Es' * steering);
    den = sum(abs(residual).^2, 1);
    pseudo = 1 ./ max(den, p.eps_div);

peak_idx = select_topk_from_spectrum(pseudo, p.num_targets, 8);
theta_hat_deg = sort(theta_grid_deg(peak_idx), 'ascend');
theta_hat_deg = complete_target_list(theta_hat_deg, p.num_targets);
end

function theta_hat_deg = estimate_angles_dft_1bit(y, p)
Yq = sign(real(y)) + 1j * sign(imag(y));
Ysp = fftshift(fft(Yq, p.Na, 1), 1) / p.Mrx;
angle_spectrum = squeeze(mean(mean(abs(Ysp).^2, 3), 2));

peak_idx = select_topk_from_spectrum(angle_spectrum, p.num_targets, p.selection_guard_bins);
na_axis = (-floor(p.Na / 2)):(ceil(p.Na / 2) - 1);
na_hat = na_axis(peak_idx);
arg = -na_hat * p.lambda_c / (p.dr * p.Na);
arg = max(-1, min(1, arg));
theta_hat_deg = sort(rad2deg(asin(arg)), 'ascend');
theta_hat_deg = complete_target_list(theta_hat_deg, p.num_targets);
end

function theta_hat_deg = estimate_angles_dft(y, p)
Ysp = fftshift(fft(y, p.Na, 1), 1) / p.Mrx;
angle_spectrum = squeeze(mean(mean(abs(Ysp).^2, 3), 2));

peak_idx = select_topk_from_spectrum(angle_spectrum, p.num_targets, p.selection_guard_bins);
na_axis = (-floor(p.Na / 2)):(ceil(p.Na / 2) - 1);
na_hat = na_axis(peak_idx);
arg = -na_hat * p.lambda_c / (p.dr * p.Na);
arg = max(-1, min(1, arg));
theta_hat_deg = sort(rad2deg(asin(arg)), 'ascend');
theta_hat_deg = complete_target_list(theta_hat_deg, p.num_targets);
end

function peak_idx = select_topk_from_spectrum(spec, num_targets, guard_bins)
spec = spec(:);
N = numel(spec);
peak_candidates = [];

for i = 1:N
    il = mod(i - 2, N) + 1;
    ir = mod(i, N) + 1;
    if spec(i) >= spec(il) && spec(i) > spec(ir)
        peak_candidates(end + 1) = i; %#ok<AGROW>
    end
end

if isempty(peak_candidates)
    peak_candidates = 1:N;
end

blocked = false(N, 1);
peak_idx = zeros(1, num_targets);
filled = 0;

while filled < num_targets
    valid_idx = peak_candidates(~blocked(peak_candidates));
    if isempty(valid_idx)
        valid_idx = find(~blocked);
    end
    if isempty(valid_idx)
        break;
    end

    [~, imax] = max(spec(valid_idx));
    idx_pick = valid_idx(imax);

    filled = filled + 1;
    peak_idx(filled) = idx_pick;

    for offset = -guard_bins:guard_bins
        idx_block = mod(idx_pick - 1 + offset, N) + 1;
        blocked(idx_block) = true;
    end
end

peak_idx = peak_idx(1:filled);
if isempty(peak_idx)
    [~, idx_max] = max(spec);
    peak_idx = idx_max;
end
if numel(peak_idx) < num_targets
    peak_idx(end + 1:num_targets) = peak_idx(end);
end
end

function theta_hat_deg = complete_target_list(theta_hat_deg, num_targets)
theta_hat_deg = theta_hat_deg(:).';
if isempty(theta_hat_deg)
    theta_hat_deg = zeros(1, num_targets);
elseif numel(theta_hat_deg) < num_targets
    theta_hat_deg(end + 1:num_targets) = theta_hat_deg(end);
elseif numel(theta_hat_deg) > num_targets
    theta_hat_deg = theta_hat_deg(1:num_targets);
end
end

function theta_hat = select_estimate_for_target(theta_hat_all, theta_true)
theta_hat_all = theta_hat_all(:).';
if isempty(theta_hat_all)
    theta_hat = theta_true;
    return;
end

err_abs = abs(wrap_to_180(theta_hat_all - theta_true));
[~, idx_best] = min(err_abs);
theta_hat = theta_hat_all(idx_best);
end

function p = configure_dft_grid_and_peak_params(p)
% Keep angular-FFT and peak-search scales aligned with the receive aperture.
p.Na = max(64, p.na_ratio * p.Mrx);

mainlobe_bins = max(4, round(p.Na / p.Mrx));
p.cfar_num_guard = max(2, round(mainlobe_bins / 2));
p.selection_guard_bins = max(2, round(mainlobe_bins / 2));
p.cfar_num_train = max(8, 4 * p.cfar_num_guard);
end

function Rfb = forward_backward_average(R)
J = fliplr(eye(size(R, 1)));
Rfb = 0.5 * (R + J * conj(R) * J);
end

function Es = dominant_signal_subspace(R, num_targets)
R = (R + R') / 2;
N = size(R, 1);
num_targets = min(num_targets, N);

if N <= 256
    [U, D] = eig(R, 'vector');
    [~, idx] = sort(real(D), 'descend');
    Es = U(:, idx(1:num_targets));
    return;
end

opts = struct();
opts.issym = true;
opts.isreal = isreal(R);
opts.tol = 1e-3;
opts.maxit = 300;

try
    [U, D] = eigs(R, num_targets, 'largestabs', opts);
    [~, idx] = sort(real(diag(D)), 'descend');
    Es = U(:, idx);
catch
    [U, D] = eig(R, 'vector');
    [~, idx] = sort(real(D), 'descend');
    Es = U(:, idx(1:num_targets));
end
end

function fig = plot_error_curve(x_axis, error_mat, algorithms, style, x_label_text, y_label_text, title_text)
fig = figure('Color', 'w', 'Position', [120, 120, 980, 580]);
hold on;
grid on;
box on;

for ia = 1:numel(algorithms)
    % A tiny floor keeps exact-zero RMSE points visible on logarithmic axes.
    plot_vals = max(error_mat(ia, :), 1e-4);
    semilogy(x_axis, plot_vals, ...
        'LineStyle', style{ia, 1}, ...
        'Marker', style{ia, 2}, ...
        'Color', style{ia, 3}, ...
        'MarkerFaceColor', style{ia, 3}, ...
        'LineWidth', 1.9, ...
        'MarkerSize', 6, ...
        'DisplayName', algorithms(ia).name);
end

xlabel(x_label_text, 'FontSize', 12, 'FontWeight', 'bold');
ylabel(y_label_text, 'FontSize', 12, 'FontWeight', 'bold');
title(title_text, 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'northeastoutside');
set(gca, 'YScale', 'log', 'FontName', 'Times New Roman', 'FontSize', 11, 'LineWidth', 1.1);
end

function x = wrap_to_180(x)
x = mod(x + 180, 360) - 180;
end
