function [est, debug] = angle_1bit_dft_multi_estimator(y, x, p)
%ANGLE_1BIT_DFT_MULTI_ESTIMATOR 多目标空间维 DFT 角度估计器。
%   本函数遵循如下处理流程：
%   1) 可选的 1-bit 量化
%   2) 空间维 DFT
%   3) 用于通信符号消除的自适应缩放因子估计
%   4) 角度功率谱累积
%   5) 可选的峰值搜索
%   6) 可选的抛物线插值
%
%   标志位说明：
%   - enable_interp = true  -> 启用抛物线插值
%
%   输入
%   ----
%   y : [M_rx, N_s, L] 复数接收数据立方体
%   x : [N_tx, N_s, L] 已知发射符号
%   p : 参数结构体
%       必需字段：
%         c, fc, dr, dt, Na, num_targets
%       可选字段：
%         enable_1bit_quantization (默认 false)
%         enable_peak_search      (默认 true)
%         enable_cfar             (默认值 = enable_peak_search)
%         cfar_num_train          (默认 8)
%         cfar_num_guard          (默认 2)
%         cfar_pfa                (默认 1e-3)
%         enable_interp           (默认 false)
%         selection_guard_bins    (默认 2)
%         eps_div                 (默认 1e-10)
%
%   输出
%   ----
%   est.theta_deg      : 按升序排列的角度估计值，[1, K]
%   est.theta_rad      : 按升序排列的弧度制角度估计值，[1, K]
%   est.na_hat         : 选中的 na 轴 DFT bin 索引
%   est.na_hat_refined : 插值后的精化 bin 索引
%   est.peak_power     : 所选峰值对应的角度谱功率
%   est.peak_indices   : FFT 平移后谱上的峰值索引
%   debug              : 中间变量

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

% 第 1 步：可选的 1-bit 量化。
if p.enable_1bit_quantization
    y_proc = sign(real(y)) + 1j * sign(imag(y));
else
    y_proc = y;
end

% 第 2 步：空间维 DFT。
Y_spatial = fftshift(fft(y_proc, Na, 1), 1) / M_rx;
na_axis = (-floor(Na / 2)):(ceil(Na / 2) - 1);

% 第 3 步：自适应缩放与通信符号消除。
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

% 第 5 步：可选峰值搜索。
% 第 6 步：可选抛物线插值。
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

% 从候选峰中选取前 num_targets 个目标峰，并使用保护窗避免重复选峰。

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

% 将精化后的 bin 索引映射回目标入射角。

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
    debug.na_axis = na_axis;                                      % na 轴索引
    debug.angle_axis_deg = rad2deg(asin(max(-1, min(1, -na_axis * lambda_c / (p.dr * Na))))); % 对应角度轴
    debug.alpha = alpha;                                          % 自适应缩放因子
    debug.angle_spectrum = angle_spectrum;                        % 角度功率谱
    debug.local_peak_idx = local_peak_idx;                        % 局部峰索引
    debug.candidate_idx = candidate_idx;                          % 候选峰索引
    debug.cfar_threshold = cfar_threshold;                        % CFAR 门限
    debug.cfar_detect = cfar_detect;                              % CFAR 检测结果

    if keep_debug_cubes
        debug.Y_spatial = Y_spatial;                              % 空间域变换结果
        debug.Y_clean = Y_clean;                                  % 清理后的角度域数据立方体
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
    threshold(i) = alpha_cfar * noise_est;   % CFAR 检测门限
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
        peak_idx(end + 1) = i; %#ok<AGROW> % 记录局部极大值点
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
        blocked(idx_block) = true; % 将当前峰附近的保护窗屏蔽掉
    end
end

selected_idx = selected_idx(1:filled);
selected_power = angle_spectrum(selected_idx);

if filled < num_targets
    selected_idx(end + 1:num_targets) = selected_idx(end);
    selected_power(end + 1:num_targets) = selected_power(end);
end
end
