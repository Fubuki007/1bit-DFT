function [est, debug] = angle_1bit_dft_estimator(y, x, p, truth)
%ANGLE_1BIT_DFT_ESTIMATOR 单比特空间维DFT角度估计（方案A）
% 输入:
%   y     : [M_rx, N_s, L] 复数回波（可为全精度或量化前信号）
%   x     : [N_tx, N_s, L] 已知发射符号
%   p     : 参数结构体
%           必需字段: fc, c, dr, dt, Na
%           可选字段: enable_1bit_quantization (default=false)
%                    use_bussgang (default=true when 1-bit enabled)
%                    eps_div (default=1e-10)
%                    enable_cfar (default=false)
%                    cfar_num_train (default=8)
%                    cfar_num_guard (default=2)
%                    cfar_pfa (default=1e-3)
%                    enable_interp (default=false)
%   truth : (可选) 结构体，含 truth.theta_deg，用于打印误差
%
% 输出:
%   est.theta_deg       : 估计角度（度）
%   est.theta_rad       : 估计角度（弧度）
%   est.na_hat          : 峰值角度bin索引（整数）
%   est.na_hat_refined  : 插值后角度bin索引（可为小数）
%   est.peak_power      : 峰值功率
%   est.used_cfar       : 是否由CFAR候选峰确定
%   debug               : 中间量（角度谱、轴、缩放因子、CFAR信息）

if nargin < 4
    truth = [];
end

[M_rx, N_s, L] = size(y);
[N_tx, N_s_x, L_x] = size(x);
assert(N_s_x == N_s && L_x == L, 'x 与 y 的 N_s/L 维度不一致');

required_fields = {'c','fc','dr','dt','Na'};
for kf = 1:numel(required_fields)
    assert(isfield(p, required_fields{kf}), '缺少参数 p.%s', required_fields{kf});
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
if ~isfield(p, 'enable_cfar') || isempty(p.enable_cfar)
    p.enable_cfar = false;
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

lambda_c = p.c / p.fc;
Na = p.Na;

% Step 1: 可选1-bit量化 + 可选幅度补偿
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

% Step 2: 空间维DFT
Y_spatial = fftshift(fft(y_proc, Na, 1), 1) / M_rx;   % [Na, N_s, L]
na_axis = (-floor(Na/2)):(ceil(Na/2)-1);

% Step 3: 自适应缩放因子 + 去通信符号
Y_clean = zeros(Na, N_s, L);
alpha = ones(Na, 1);

for ia = 1:Na
    na = na_axis(ia);

    % theta_na from spatial bin
    arg = -na * lambda_c / (p.dr * Na);
    arg = max(-1, min(1, arg));
    theta_na = asin(arg);

    % a_tx(theta_na)
    n = (0:N_tx-1).';
    a_tx = exp(1j * 2*pi * n * (p.dt * sin(theta_na) / lambda_c));

    % denom(i,l) = a^H x(:,i,l)
    denom = squeeze(sum(conj(a_tx) .* x, 1));  % [N_s,L]
    Y_bin = squeeze(Y_spatial(ia, :, :));      % [N_s,L]

    mask = abs(denom) > p.eps_div;
    if any(mask(:))
        num = sum(abs(Y_bin(mask) ./ denom(mask)).^2);
        den = sum(abs(Y_bin(mask)).^2);
        if num > p.eps_div && den > p.eps_div
            alpha(ia) = sqrt(num / den);
        else
            alpha(ia) = 1;
        end

        Y_tmp = Y_bin;
        Y_tmp(mask) = Y_bin(mask) ./ (alpha(ia) * denom(mask));
        Y_clean(ia, :, :) = reshape(Y_tmp, [1, N_s, L]);
    else
        Y_clean(ia, :, :) = reshape(Y_bin, [1, N_s, L]);
    end
end

% Step 4: 角度谱构造（仅对 i,l 维做功率累积）
angle_spectrum = squeeze(mean(mean(abs(Y_clean).^2, 3), 2));   % [Na,1]

% Step 5: 峰值检测（可选CA-CFAR）
used_cfar = false;
cfar_threshold = zeros(Na, 1);
cfar_detect = false(Na, 1);

if p.enable_cfar
    Nt = p.cfar_num_train;
    Ng = p.cfar_num_guard;
    pfa = p.cfar_pfa;

    assert(Nt >= 1, 'cfar_num_train 必须>=1');
    assert(Ng >= 0, 'cfar_num_guard 必须>=0');
    assert(pfa > 0 && pfa < 1, 'cfar_pfa 必须在(0,1)');

    n_train_total = 2 * Nt;
    alpha_cfar = n_train_total * (pfa^(-1 / n_train_total) - 1);

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
        cfar_threshold(i) = alpha_cfar * noise_est;
        cfar_detect(i) = angle_spectrum(i) > cfar_threshold(i);
    end

    candidate_idx = find(cfar_detect);
    if ~isempty(candidate_idx)
        [peak_power, kmax] = max(angle_spectrum(candidate_idx));
        ia_hat = candidate_idx(kmax);
        used_cfar = true;
    else
        [peak_power, ia_hat] = max(angle_spectrum);
    end
else
    [peak_power, ia_hat] = max(angle_spectrum);
end

na_hat = na_axis(ia_hat);
na_hat_refined = na_hat;

% Step 6: 可选抛物线插值（在角度bin轴上）
if p.enable_interp
    il = mod(ia_hat - 2, Na) + 1;
    ir = mod(ia_hat, Na) + 1;

    y1 = angle_spectrum(il);
    y2 = angle_spectrum(ia_hat);
    y3 = angle_spectrum(ir);

    den = (y1 - 2 * y2 + y3);
    if abs(den) > p.eps_div
        delta = 0.5 * (y1 - y3) / den;
        delta = max(-0.5, min(0.5, delta));
        na_hat_refined = na_hat + delta;
    end
end

% Step 7: 角度反演
arg_theta = -na_hat_refined * lambda_c / (p.dr * Na);
arg_theta = max(-1, min(1, arg_theta));
theta_hat = asin(arg_theta);

est = struct();
est.theta_rad = theta_hat;
est.theta_deg = rad2deg(theta_hat);
est.na_hat = na_hat;
est.na_hat_refined = na_hat_refined;
est.peak_power = peak_power;
est.used_cfar = used_cfar;

debug = struct();
debug.k_bussgang = k_bg;
debug.na_axis = na_axis;
debug.angle_axis_deg = rad2deg(asin(max(-1, min(1, -na_axis * lambda_c / (p.dr * Na)))));
debug.Y_spatial = Y_spatial;
debug.alpha = alpha;
debug.Y_clean = Y_clean;
debug.angle_spectrum = angle_spectrum;
debug.cfar_threshold = cfar_threshold;
debug.cfar_detect = cfar_detect;

if ~isempty(truth) && isfield(truth, 'theta_deg')
    fprintf('\n===== 方案A: 单比特空间DFT角度估计 =====\n');
    fprintf('theta_hat = %8.3f deg | theta_true = %8.3f deg | err = %+8.3f deg\n', ...
        est.theta_deg, truth.theta_deg, est.theta_deg - truth.theta_deg);
    fprintf('na_hat    = %8d       | na_refined = %8.3f\n', est.na_hat, est.na_hat_refined);
    fprintf('peak_power= %.4e      | used_cfar = %d\n', est.peak_power, est.used_cfar);
end

end
