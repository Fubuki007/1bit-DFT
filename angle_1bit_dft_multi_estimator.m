function [est, debug] = angle_1bit_dft_multi_estimator(y, x, p)
%ANGLE_1BIT_DFT_MULTI_ESTIMATOR Multi-target spatial-DFT angle estimator.
%   This function follows the paper pipeline:
%   1) optional 1-bit quantization + Bussgang amplitude recovery
%   2) spatial DFT
%   3) adaptive scaling factor for communication-symbol removal
%   4) angle-spectrum accumulation
%   5) optional peak search and optional parabolic interpolation
%
%   Inputs
%   ------
%   y : [M_rx, N_s, L] complex receive cube
%   x : [N_tx, N_s, L] known transmit symbols
%   p : parameter struct
%       Required fields:
%         c, fc, dr, dt, Na, num_targets
%       Optional fields:
%         enable_1bit_quantization (default false)
%         use_bussgang            (default = enable_1bit_quantization)
%         enable_peak_search      (default true)
%         enable_cfar             (default = enable_peak_search)
%         cfar_num_train          (default 8)
%         cfar_num_guard          (default 2)
%         cfar_pfa                (default 1e-3)
%         enable_interp           (default false)
%         selection_guard_bins    (default 2)
%         eps_div                 (default 1e-10)
%
%   Outputs
%   -------
%   est.theta_deg      : estimated angles in ascending order, [1, K]
%   est.theta_rad      : estimated angles in ascending order, [1, K]
%   est.na_hat         : selected DFT-bin indices on na axis
%   est.na_hat_refined : refined bin indices after interpolation
%   est.peak_power     : angle-spectrum values at selected peaks
%   est.peak_indices   : selected indices on the FFT-shifted spectrum
%   debug              : intermediate variables

required_fields = {'c', 'fc', 'dr', 'dt', 'Na', 'num_targets'};
for kf = 1:numel(required_fields)
    assert(isfield(p, required_fields{kf}), 'Missing parameter p.%s', required_fields{kf});
end

if ~isfield(p, 'eps_div') || isempty(p.eps_div)
    p.eps_div = 1e-10;
end
if ~isfield(p, 'enable_1bit_quantization') || isempty(p.enable_1bit_quantization)
    p.enable_1bit_quantization = false;
end
if ~isfield(p, 'use_bussgang') || isempty(p.use_bussgang)
    p.use_bussgang = p.enable_1bit_quantization;
end
if ~isfield(p, 'enable_peak_search') || isempty(p.enable_peak_search)
    p.enable_peak_search = true;
end
if ~isfield(p, 'enable_cfar') || isempty(p.enable_cfar)
    p.enable_cfar = p.enable_peak_search;
end
if ~isfield(p, 'cfar_num_train') || isempty(p.cfar_num_train)
    p.cfar_num_train = 8;
end
if ~isfield(p, 'cfar_num_guard') || isempty(p.cfar_num_guard)
    p.cfar_num_guard = 2;
end
if ~isfield(p, 'cfar_pfa') || isempty(p.cfar_pfa)
    p.cfar_pfa = 1e-3;
end
if ~isfield(p, 'enable_interp') || isempty(p.enable_interp)
    p.enable_interp = false;
end
if ~isfield(p, 'selection_guard_bins') || isempty(p.selection_guard_bins)
    p.selection_guard_bins = 2;
end

[M_rx, N_s, L] = size(y);
[N_tx, N_s_x, L_x] = size(x);
assert(N_s_x == N_s && L_x == L, 'x and y must share the same N_s and L.');

lambda_c = p.c / p.fc;
Na = p.Na;

% Step 1: optional 1-bit quantization and Bussgang amplitude recovery.
if p.enable_1bit_quantization
    y_proc = sign(real(y)) + 1j * sign(imag(y));
else
    y_proc = y;
end

if p.use_bussgang
    k_bg = 2 / sqrt(pi);
    y_proc = y_proc / k_bg;
else
    k_bg = 1;
end

% Step 2: spatial DFT.
Y_spatial = fftshift(fft(y_proc, Na, 1), 1) / M_rx;
na_axis = (-floor(Na / 2)):(ceil(Na / 2) - 1);

% Step 3: adaptive scaling and communication-symbol removal.
debug = [];
keep_debug_cubes = (nargout > 1) && isfield(p, 'return_debug_cubes') && p.return_debug_cubes;
if keep_debug_cubes
    Y_clean = zeros(Na, N_s, L, 'like', Y_spatial);
else
    Y_clean = [];
end
alpha = ones(Na, 1, 'like', real(Y_spatial(:, 1, 1)));
angle_spectrum = zeros(Na, 1, 'like', real(Y_spatial(:, 1, 1)));

for ia = 1:Na
    na = na_axis(ia);
    arg = -na * lambda_c / (p.dr * Na);
    arg = max(-1, min(1, arg));
    theta_na = asin(arg);

    n = (0:N_tx-1).';
    a_tx = exp(1j * 2 * pi * n * (p.dt * sin(theta_na) / lambda_c));

    denom = squeeze(sum(conj(a_tx) .* x, 1));
    Y_bin = squeeze(Y_spatial(ia, :, :));

    mask = abs(denom) > p.eps_div;
    if any(mask(:))
        num = sum(abs(Y_bin(mask) ./ denom(mask)).^2);
        den = sum(abs(Y_bin(mask)).^2);
        if num > p.eps_div && den > p.eps_div
            alpha(ia) = sqrt(num / den);
        end

        Y_tmp = Y_bin;
        Y_tmp(mask) = Y_bin(mask) ./ (alpha(ia) * denom(mask));
        if keep_debug_cubes
            Y_clean(ia, :, :) = reshape(Y_tmp, [1, N_s, L]);
        end
        angle_spectrum(ia) = mean(abs(Y_tmp(:)).^2);
    else
        if keep_debug_cubes
            Y_clean(ia, :, :) = reshape(Y_bin, [1, N_s, L]);
        end
        angle_spectrum(ia) = mean(abs(Y_bin(:)).^2);
    end
end

% Step 5: optional peak search, then optional interpolation.
cfar_threshold = zeros(Na, 1);
cfar_detect = false(Na, 1);
if p.enable_cfar
    [cfar_threshold, cfar_detect] = local_cfar(angle_spectrum, p);
end

local_peak_idx = local_find_peaks(angle_spectrum);
if isempty(local_peak_idx)
    local_peak_idx = 1:Na;
end

if p.enable_peak_search
    candidate_idx = local_peak_idx;
    if p.enable_cfar
        cfar_peak_idx = candidate_idx(cfar_detect(candidate_idx));
        if numel(cfar_peak_idx) >= p.num_targets
            candidate_idx = cfar_peak_idx;
        end
    end
else
    candidate_idx = 1:Na;
end

[peak_idx, peak_power] = local_select_topk(angle_spectrum, candidate_idx, p.num_targets, p.selection_guard_bins);

na_hat = na_axis(peak_idx);
na_hat_refined = na_hat;

if p.enable_interp
    for kp = 1:numel(peak_idx)
        ic = peak_idx(kp);
        il = mod(ic - 2, Na) + 1;
        ir = mod(ic, Na) + 1;

        y1 = angle_spectrum(il);
        y2 = angle_spectrum(ic);
        y3 = angle_spectrum(ir);

        den = (y1 - 2 * y2 + y3);
        if abs(den) > p.eps_div
            delta = 0.5 * (y1 - y3) / den;
            delta = max(-0.5, min(0.5, delta));
            na_hat_refined(kp) = na_hat(kp) + delta;
        end
    end
end

arg_theta = -na_hat_refined * lambda_c / (p.dr * Na);
arg_theta = max(-1, min(1, arg_theta));
theta_hat_rad = asin(arg_theta);
theta_hat_deg = rad2deg(theta_hat_rad);

[theta_hat_deg, order] = sort(theta_hat_deg, 'ascend');
theta_hat_rad = theta_hat_rad(order);
na_hat = na_hat(order);
na_hat_refined = na_hat_refined(order);
peak_power = peak_power(order);
peak_idx = peak_idx(order);

est = struct();
est.theta_deg = theta_hat_deg(:).';
est.theta_rad = theta_hat_rad(:).';
est.na_hat = na_hat(:).';
est.na_hat_refined = na_hat_refined(:).';
est.peak_power = peak_power(:).';
est.peak_indices = peak_idx(:).';
est.used_peak_search = logical(p.enable_peak_search);
est.used_cfar = logical(p.enable_peak_search && p.enable_cfar);
est.used_interp = logical(p.enable_interp);

if nargout > 1
    debug = struct();
    debug.k_bussgang = k_bg;
    debug.na_axis = na_axis;
    debug.angle_axis_deg = rad2deg(asin(max(-1, min(1, -na_axis * lambda_c / (p.dr * Na)))));
    debug.alpha = alpha;
    debug.angle_spectrum = angle_spectrum;
    debug.local_peak_idx = local_peak_idx;
    debug.candidate_idx = candidate_idx;
    debug.cfar_threshold = cfar_threshold;
    debug.cfar_detect = cfar_detect;

    if keep_debug_cubes
        debug.Y_spatial = Y_spatial;
        debug.Y_clean = Y_clean;
    end
end

end

function [threshold, detect] = local_cfar(angle_spectrum, p)
Na = numel(angle_spectrum);
Nt = p.cfar_num_train;
Ng = p.cfar_num_guard;
pfa = p.cfar_pfa;

assert(Nt >= 1, 'cfar_num_train must be >= 1.');
assert(Ng >= 0, 'cfar_num_guard must be >= 0.');
assert(pfa > 0 && pfa < 1, 'cfar_pfa must be inside (0,1).');

n_train_total = 2 * Nt;
alpha_cfar = n_train_total * (pfa^(-1 / n_train_total) - 1);

threshold = zeros(Na, 1);
detect = false(Na, 1);

for i = 1:Na
    idx_train = zeros(n_train_total, 1);
    cnt = 0;
    for k = (Ng + 1):(Ng + Nt)
        il = mod(i - 1 - k, Na) + 1;
        ir = mod(i - 1 + k, Na) + 1;
        cnt = cnt + 1;
        idx_train(cnt) = il;
        cnt = cnt + 1;
        idx_train(cnt) = ir;
    end

    noise_est = mean(angle_spectrum(idx_train));
    threshold(i) = alpha_cfar * noise_est;
    detect(i) = angle_spectrum(i) > threshold(i);
end
end

function peak_idx = local_find_peaks(angle_spectrum)
Na = numel(angle_spectrum);
peak_idx = [];

for i = 1:Na
    il = mod(i - 2, Na) + 1;
    ir = mod(i, Na) + 1;
    if angle_spectrum(i) >= angle_spectrum(il) && angle_spectrum(i) > angle_spectrum(ir)
        peak_idx(end + 1) = i; %#ok<AGROW>
    end
end
end

function [selected_idx, selected_power] = local_select_topk(angle_spectrum, candidate_idx, num_targets, guard_bins)
Na = numel(angle_spectrum);
blocked = false(Na, 1);
selected_idx = zeros(1, num_targets);
filled = 0;

candidate_idx = unique(candidate_idx(:).', 'stable');
if isempty(candidate_idx)
    candidate_idx = 1:Na;
end

while filled < num_targets
    valid_idx = candidate_idx(~blocked(candidate_idx));
    if isempty(valid_idx)
        valid_idx = find(~blocked);
    end
    if isempty(valid_idx)
        break;
    end

    [~, imax] = max(angle_spectrum(valid_idx));
    idx_pick = valid_idx(imax);

    filled = filled + 1;
    selected_idx(filled) = idx_pick;

    for offset = -guard_bins:guard_bins
        idx_block = mod(idx_pick - 1 + offset, Na) + 1;
        blocked(idx_block) = true;
    end
end

selected_idx = selected_idx(1:filled);
selected_power = angle_spectrum(selected_idx);

if filled < num_targets
    selected_idx(end + 1:num_targets) = selected_idx(end);
    selected_power(end + 1:num_targets) = selected_power(end);
end
end
