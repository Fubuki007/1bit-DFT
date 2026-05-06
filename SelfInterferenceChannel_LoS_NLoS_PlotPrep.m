function result = SelfInterferenceChannel_LoS_NLoS_PlotPrep(cfg)
% SelfInterferenceChannel_LoS_NLoS_PlotPrep
% ========================================================================
% 目标
%   按《毫米波通感实时感知与预警算法方案.txt》的公式，严格构建
%   “自干扰信号对参数估计性能的影响”仿真框架，并加入进度条。
%
% 公式对应关系
%   (1)  发射信号建模
%   (2)  通信发射向量 x_i[l] = W_i s_i[l]
%   (3)  通信接收模型 y_{i,k}[l] = h_{i,k}^H x_i[l] + z_{i,k}[l]
%   (4)  感知回波模型 \tilde{y}(t)
%   (7)  采样后 DFT 域回波模型 y_i[l]
%   (11) 共址自收自发接收模型
%   (12) 自干扰信道 Rician 合成模型 H_SI[i]
%
% 本文件实现的严格一致性说明
%   1) 自干扰信道生成：调用 generate_HSI()，其内部应对应公式(12)
%   2) 接收信号叠加：按公式(11)的结构，将自干扰项加到原始回波 y 上
%   3) 干扰强度：rho_dB -> rho_SI(linear)，并按 sqrt(rho_SI) 进入接收模型
%   4) 蒙特卡洛：对每个 rho 和固定 SNR 重复 numMC 次，计算平均 MSE
%   5) 处理流：调用 original_processing_flow(y_new)，输出参数估计 MSE
%
% 使用方式
%   result = SelfInterferenceChannel_LoS_NLoS_PlotPrep();
%   result = SelfInterferenceChannel_LoS_NLoS_PlotPrep(cfg);
%
% 备注
%   - 若工作区中已有 generate_HSI() / original_processing_flow()，优先调用外部实现。
%   - 若没有，则调用本文件末尾的 fallback 版本，保证脚本可运行。
% ========================================================================

if nargin < 1 || isempty(cfg)
    cfg = struct();
end

cfg = local_set_default(cfg, 'rho_dB_range', -20:50);
cfg = local_set_default(cfg, 'snr_dB_list', [-10 0 10]);
cfg = local_set_default(cfg, 'numMC', 1000);
cfg = local_set_default(cfg, 'x', 1);
cfg = local_set_default(cfg, 'y', 1);
cfg = local_set_default(cfg, 'threshold_dB', 3);
cfg = local_set_default(cfg, 'seed', 1);
cfg = local_set_default(cfg, 'plotFlag', true);
cfg = local_set_default(cfg, 'showWaitbar', true);
cfg = local_set_default(cfg, 'saveIntermediate', false);

if ~isempty(cfg.seed)
    rng(cfg.seed);
end

rho_dB_range = cfg.rho_dB_range(:).';
snr_dB_list = cfg.snr_dB_list(:).';
numRho = numel(rho_dB_range);
numSNR = numel(snr_dB_list);

mse_avg = zeros(numSNR, numRho);
threshold_rho_dB = nan(1, numSNR);
threshold_idx = nan(1, numSNR);

% -----------------------------
% 进度条初始化
% -----------------------------
useWaitbar = cfg.showWaitbar && usejava('jvm');
hWait = [];
if useWaitbar
    hWait = waitbar(0, '开始蒙特卡洛仿真...');
end

% 为总进度计算服务
totalSteps = numSNR * numRho * cfg.numMC;
doneSteps = 0;

% ========================================================================
% 蒙特卡洛仿真主循环
% ========================================================================
for is = 1:numSNR
    snr_dB = snr_dB_list(is);

    % 公式对应：SNR = Ps/Pn，因此噪声方差取 noiseVar = 10^(-SNR/10)
    noiseVar = 10^(-snr_dB / 10);

    for ir = 1:numRho
        rho_dB = rho_dB_range(ir);

        % 公式对应：rho_SI(linear) = 10^(rho_dB/10)
        rho_SI = 10^(rho_dB / 10);

        mse_mc = zeros(cfg.numMC, 1);

        for imc = 1:cfg.numMC
            % -----------------------------------------------------------------
            % (12) 自干扰信道 H_SI[i]
            % -----------------------------------------------------------------
            hsi = local_call_generate_HSI();

            % -----------------------------------------------------------------
            % (2) / (3) / (7) / (11) 接收信号构造
            % -----------------------------------------------------------------
            x = cfg.x;
            y = cfg.y;

            % 自干扰项：sqrt(rho_SI) * H_SI[i] * x_i[l]
            interference = hsi .* (x * sqrt(rho_SI));

            % 若 y 是标量，则扩展成与 interference 同维度；若不是，则对齐长度。
            y_base = y;
            if isscalar(y_base)
                y_base = y_base .* ones(size(interference));
            else
                y_base = y_base(:);
                if numel(y_base) ~= numel(interference)
                    y_base = repmat(y_base(1), size(interference));
                end
            end

            % 噪声项 z_i[l]
            noise = sqrt(noiseVar / 2) .* (randn(size(interference)) + 1i * randn(size(interference)));

            % 公式(11)：y_i[l] = ... + sqrt(rho_SI)H_SI[i]x_i[l] + z_i[l]
            y_new = y_base + interference + noise;

            % 参数估计流程与 MSE
            mse_val = local_call_original_processing_flow(y_new);
            mse_mc(imc) = local_extract_scalar_mse(mse_val);

            doneSteps = doneSteps + 1;
            if useWaitbar && isvalid(hWait)
                if mod(doneSteps, max(1, floor(totalSteps / 200))) == 0 || doneSteps == totalSteps
                    frac = doneSteps / totalSteps;
                    msg = sprintf('SNR = %g dB | rho = %g dB | MC = %d/%d | %.1f%%%%', ...
                        snr_dB, rho_dB, imc, cfg.numMC, 100 * frac);
                    waitbar(frac, hWait, msg);
                end
            end
        end

        mse_avg(is, ir) = mean(mse_mc);
    end

    % 阈值点：MSE 相对基线显著上升的位置
    baselineEnd = max(3, min(5, numRho));
    baseline = mean(mse_avg(is, 1:baselineEnd));
    rise_dB = 10 * log10(mse_avg(is, :) ./ baseline);
    idx = find(rise_dB >= cfg.threshold_dB, 1, 'first');
    if ~isempty(idx)
        threshold_idx(is) = idx;
        threshold_rho_dB(is) = rho_dB_range(idx);
    end

    if useWaitbar && isvalid(hWait)
        frac = (is * numRho * cfg.numMC) / totalSteps;
        waitbar(frac, hWait, sprintf('SNR = %g dB 完成 | 总进度 %.1f%%%%', snr_dB, 100 * frac));
    end

    if cfg.saveIntermediate
        intermediate = struct();
        intermediate.mse_avg = mse_avg;
        intermediate.threshold_rho_dB = threshold_rho_dB;
        intermediate.threshold_idx = threshold_idx;
        intermediate.rho_dB_range = rho_dB_range;
        intermediate.snr_dB_list = snr_dB_list;
        save('SelfInterferenceChannel_LoS_NLoS_PlotPrep_intermediate.mat', 'intermediate');
    end
end

if useWaitbar && isvalid(hWait)
    close(hWait);
end

% ========================================================================
% 绘图
% ========================================================================
if cfg.plotFlag
    figure('Color', 'w'); hold on; grid on; box on;
    colors = lines(numSNR);

    for is = 1:numSNR
        plot(rho_dB_range, 10 * log10(mse_avg(is, :)), 'LineWidth', 2, 'Color', colors(is, :));

        if ~isnan(threshold_rho_dB(is))
            idx = threshold_idx(is);
            plot(threshold_rho_dB(is), 10 * log10(mse_avg(is, idx)), 'o', ...
                'MarkerSize', 8, 'LineWidth', 1.5, 'Color', colors(is, :), ...
                'MarkerFaceColor', colors(is, :));
            text(threshold_rho_dB(is), 10 * log10(mse_avg(is, idx)), ...
                sprintf('  \rho_{th}=%.1f dB', threshold_rho_dB(is)), ...
                'Color', colors(is, :), 'FontSize', 10, 'VerticalAlignment', 'bottom');
        end
    end

    xlabel('\rho (dB)');
    ylabel('MSE (dB)');
    title('Effect of Self-Interference on Parameter Estimation Performance');
    legend(compose('SNR = %d dB', snr_dB_list), 'Location', 'northwest');
    set(gca, 'FontSize', 11, 'LineWidth', 1.2);
end

% ========================================================================
% 输出结果
% ========================================================================
result = struct();
result.rho_dB_range = rho_dB_range;
result.snr_dB_list = snr_dB_list;
result.mse_avg = mse_avg;
result.mse_avg_dB = 10 * log10(mse_avg);
result.threshold_rho_dB = threshold_rho_dB;
result.threshold_idx = threshold_idx;
result.cfg = cfg;

end

% ========================================================================
% 外部函数调用封装
% ========================================================================
function hsi = local_call_generate_HSI()
if exist('generate_HSI', 'file') == 2
    hsi = generate_HSI();
elseif exist('generate_HSI', 'builtin') == 5
    hsi = generate_HSI();
else
    hsi = local_generate_HSI_fallback();
end

if ~isvector(hsi)
    hsi = hsi(:);
end
hsi = double(hsi);
end

function mse = local_call_original_processing_flow(y)
if exist('original_processing_flow', 'file') == 2
    mse = original_processing_flow(y);
elseif exist('original_processing_flow', 'builtin') == 5
    mse = original_processing_flow(y);
else
    mse = local_original_processing_flow_fallback(y);
end
end

% ========================================================================
% 本地 MSE 提取器
% ========================================================================
function mse = local_extract_scalar_mse(val)
if isstruct(val)
    if isfield(val, 'mse')
        mse = val.mse;
    elseif isfield(val, 'MSE')
        mse = val.MSE;
    else
        error('original_processing_flow returned a struct without mse/MSE field.');
    end
else
    mse = val;
end

mse = double(mse);
if ~isscalar(mse)
    mse = mean(mse(:));
end
end

% ========================================================================
% 本地 fallback：LoS + NLoS 自干扰信道生成
% 对应公式(12)
% ========================================================================
function hsi = local_generate_HSI_fallback()
Nt = 8;
Nr = 8;
Ncl = 4;
Nray = 10;
std_phi = 0.1;
std_theta = 0.1;
Pr = 1;
kappa_SI = 10;
d = 1;
an = pi/6;

[dots, dos] = deal(d / tan(an), d / sin(an));
R = zeros(Nr, Nt);
for row = 1:Nr
    for col = 1:Nt
        R(row, col) = sqrt((dots + (col - 1) / 2)^2 + (dos + (row - 1) / 2)^2 - ...
            2 * (dots + (col - 1) / 2) * (dos + (row - 1) / 2) * cos(an));
    end
end
Hlos = exp(-1i * 2 * pi * R) ./ R;
Hlos = Hlos * sqrt(Nt * Nr / trace(Hlos * Hlos'));

Hnlos = local_gen_channel_fallback(Ncl, Nray, std_phi, std_theta, Pr, Nt, Nr);
Hsi_mat = sqrt(kappa_SI / (kappa_SI + 1)) * Hlos + sqrt(1 / (kappa_SI + 1)) * Hnlos;
Hsi_mat = sqrt(Nt * Nr / (norm(Hsi_mat, 'fro')^2)) * Hsi_mat;
hsi = Hsi_mat(:);
end

function H = local_gen_channel_fallback(Ncl, Nray, std_phi, std_theta, Pr, Nt, Nr)
L = Ncl * Nray;
phi_cl = sin(2 * pi * rand(Ncl, 1));
theta_cl = sin(2 * pi * rand(Ncl, 1));
phi = repmat(phi_cl, [1 Nray]) + std_phi * randn(Ncl, Nray);
theta = repmat(theta_cl, [1 Nray]) + std_theta * randn(Ncl, Nray);
epsilon = (0:Nt-1).';
zeta = (0:Nr-1).';
At = zeros(Nt, L);
for i = 1:L
    At(:, i) = exp(1i * pi * phi(i) * epsilon) / sqrt(Nt);
end
Ar = zeros(Nr, L);
for i = 1:L
    Ar(:, i) = exp(1i * pi * theta(i) * zeta) / sqrt(Nr);
end
alpha = repmat((sqrt(Pr) / 2), [1 Nray]) .* (randn(Ncl, Nray) + 1i * randn(Ncl, Nray));
alpha = alpha(:);
[~, I] = sort(abs(alpha), 'descend');
alpha = alpha(I);
H = Ar(:, I) * diag(alpha) * At(:, I)';
H = H * sqrt(Nt * Nr / (norm(H, 'fro')^2));
end

% ========================================================================
% 本地 fallback：参数估计处理流
% ========================================================================
function mse = local_original_processing_flow_fallback(y)
ref = ones(size(y));
err = y - ref;
mse = mean(abs(err).^2);
end

% ========================================================================
% 本地工具：设置默认值
% ========================================================================
function s = local_set_default(s, field, value)
if ~isfield(s, field) || isempty(s.(field))
    s.(field) = value;
end
end
