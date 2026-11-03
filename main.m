clear; clc; close all;

Nsrc = 1;  % 目標音場の数（平面波1つ）
ang_wave = pi/2;  % 平面波の進行方向 [rad]（y方向）
amp_src = ones(1,Nsrc);  % 目標振幅

fs_audio  = 16000;  % 入力音声(RAW)のサンプリングレート [Hz]
L_fir     = 1024;  % FIR長（fs_audio/L_fir = 15.625 Hz刻み）
tau_model = 0.008;  % 因果化の遅延 [s]
floor_dB = -20.0;  % GZ終端（floorモードではDZも）の目標 [dB]
dz_mode = "floor";  % "zero": DZ目標=0 / "floor": DZ目標=GZ終端と同じ値
f_low     = 500;
f_high    = 2000;
bin_idx   = ceil(f_low*L_fir/fs_audio - 1e-9) : floor(f_high*L_fir/fs_audio + 1e-9);
freq_list = bin_idx * fs_audio / L_fir;
c = 340;  % 音速 [m/s]
k_list = 2*pi*freq_list/c;
f_len = length(freq_list);

pltPos = true;  % 配置図
pltSPL = true;  % 音圧マップ・折れ線グラフ

dual_mode  = true;  % true: 二重音声 / false: 音Aのみ
listen_pts = [];  % [x, y] を行ごとに。空なら左BZ・GZ・右BZの中心
rawA_path  = "";  % 音声A(.raw)のパス
rawB_path  = "";  % 音声B(.raw)のパス（dual_mode=true のとき使用）
n_channels = 1;  % RAWのチャンネル数

%% ゾーンとスピーカーの配置
room_size = [-1.5, 1.5, 0, 3.0];
itv_room = 0.02;  % 空間全体の計算用格子点の間隔 [m]

num_sp = 32;  % スピーカー数（32台ではBZ端が開口外で波打つ）
zone_h = 1.0;  % スピーカー列からゾーン中心まで [m]（鑑賞距離の仮値）
bz_size = [0.4, 0.5];  % BZの大きさ [幅(x), 奥行き(y)] [m]（従来値の1/2）
gz_size = [0.75, 0.5];    % GZの大きさ [幅(x), 奥行き(y)] [m]（従来値の1/2）
dz_size = [0.4, 0.5];  % DZの大きさ [幅(x), 奥行き(y)] [m]（従来値の1/2）
dist_zone = bz_size(1)/2 + gz_size(1) + dz_size(1)/2;  % BZ-DZ中心間距離。ゾーン境界を隣接させる

itv_mic = [0.04, 0.08];  % 制御点の間隔 [x, y] [m]
itv_sp = 0.05;  % スピーカー間隔 [m]

geometry_mode = "zones";  % "zones" / "referenceL"
if strcmp(geometry_mode, "referenceL")
    room_size = [-1.5, 1.5, 0, 3.0];
    num_sp = 32;
    zone_h = 1.0;
    dist_zone = 2.0;
    itv_sp = 0.05;
end

[pos_sp, pos_mic, num_mic, num_bz, num_gz] = pos_sp_mic( ...
    num_sp, zone_h, dist_zone, bz_size, gz_size, dz_size, itv_mic, room_size, pltPos, geometry_mode, itv_sp);

fprintf("制御点数: %d 点（BZ=%d, GZ=%d, DZ=%d）\n", num_mic, num_bz, num_gz, num_mic - num_bz - num_gz);

use_dual = dual_mode && num_gz > 0 && strcmp(geometry_mode, "zones");
if dual_mode && ~use_dual
    warning('main:dualUnavailable', '現在の配置(geometry_mode=%s)では二重音声を作れないため、音Aのみで進めます。', geometry_mode);
end

%% 駆動信号の計算
G_ctrl = IR_freefield(pos_mic, pos_sp, k_list);
drv = filter_pm(pos_mic, G_ctrl, freq_list, ang_wave, amp_src, Nsrc, c, ...
    num_bz, num_gz, tau_model, floor_dB, dz_mode);

% 音B: BZ点群とDZ点群を入れ替え、GZの遷移方向を反転
if use_dual
    idx_bz = 1:num_bz;
    idx_gz = num_bz+1 : num_bz+num_gz;
    idx_dz = num_bz+num_gz+1 : num_mic;
    idx_B  = [idx_dz, idx_gz, idx_bz];
    num_bzB = numel(idx_dz);
    G_ctrlB = G_ctrl(idx_B, :, :);
    drvB = filter_pm(pos_mic(idx_B,:), G_ctrlB, freq_list, ang_wave, amp_src, Nsrc, c, num_bzB, num_gz, tau_model, floor_dB, dz_mode, true);
end

%% 制御結果の評価
p_ctrl = zeros(num_mic, f_len);

for n = 1:f_len
    p_ctrl(:, n) = G_ctrl(:,:,n) * drv(:,n);
end

p_bz = p_ctrl(1:num_bz, :);
p_dz = p_ctrl(num_bz + num_gz + 1:end, :);

AC_total = 10 * log10(mean(abs(p_bz(:)).^2) / mean(abs(p_dz(:)).^2));

fprintf("Broadband: %d-%dHz, AC=%.3fdB\n", freq_list(1), freq_list(end), AC_total);

E_ref_A = mean(abs(p_bz(:)).^2) * f_len;  % 0 dBの基準: BZ平均の広帯域エネルギー

if use_dual
    p_ctrlB = zeros(num_mic, f_len);
    for n = 1:f_len
        p_ctrlB(:, n) = G_ctrlB(:,:,n) * drvB(:,n);
    end
    p_bzB = p_ctrlB(1:num_bzB, :);
    p_dzB = p_ctrlB(num_bzB + num_gz + 1:end, :);
    AC_B = 10 * log10(mean(abs(p_bzB(:)).^2) / mean(abs(p_dzB(:)).^2));
    E_ref_B = mean(abs(p_bzB(:)).^2) * f_len;
    fprintf("二重音声: 音A AC=%.3fdB, 音B AC=%.3fdB (floor_dB=%g, dz_mode=%s)\n", AC_total, AC_B, floor_dB, dz_mode);
end

%% 音圧マップ・折れ線グラフ
map_name = sprintf("Relative_%s_%s_floor%g_Broadband_%d-%dHz_AC=%.2f.png", ...
    geometry_mode, dz_mode, floor_dB, freq_list(1), freq_list(end), AC_total);

if pltSPL
    spl_distribution;
end

fprintf("f=%d-%dHz, num_sp=%d, num_mic=%d, AC=%.3fdB\n", freq_list(1), freq_list(end), num_sp, num_mic, AC_total);

if pltSPL && num_gz > 0
    run plot_spl_profile.m
end

%% 聴取音声の生成・保存

%% 聴取点
if isempty(listen_pts)
    if use_dual
        x_bz = pos_mic(1:num_bz, 1);
        x_gz = pos_mic(num_bz+1:num_bz+num_gz, 1);
        x_dz = pos_mic(num_bz+num_gz+1:end, 1);
        x_bz_mid = (min(x_bz) + max(x_bz)) / 2;
        x_gz_mid = (min(x_gz) + max(x_gz)) / 2;
        x_dz_mid = (min(x_dz) + max(x_dz)) / 2;
        listen_pts = [x_bz_mid, zone_h; x_gz_mid, zone_h; x_dz_mid, zone_h];
    else
        x_target = str2double(input('聴取点の x 座標 [m] を入力してください: ', 's'));
        y_target = str2double(input('聴取点の y 座標 [m] を入力してください: ', 's'));
        listen_pts = [x_target, y_target];
    end
end
if size(listen_pts, 2) ~= 2 || any(~isfinite(listen_pts(:)))
    error('main:invalidInput', '聴取点は有限の数値で [x, y] の行として指定してください。');
end

%% 音声の読み込み
raw_type = 'int16';  % 16bit PCM
max_val  = 2^15;

if isempty(rawA_path)
    rawA_path = input('音声A(.raw)のパスを入力してください: ', 's');
end
x_A = read_raw_pcm(rawA_path, n_channels, raw_type, max_val);
if use_dual
    if isempty(rawB_path)
        rawB_path = input('音声B(.raw)のパスを入力してください: ', 's');
    end
    x_B = read_raw_pcm(rawB_path, n_channels, raw_type, max_val);
else
    x_B = zeros(size(x_A));
end

n_max = max(numel(x_A), numel(x_B));
x_A(end+1:n_max, 1) = 0;
x_B(end+1:n_max, 1) = 0;

% 全ファイル共通のスケール: 基準点（左BZ・右BZの中心）の主役音のピークを out_peak にそろえる。
% out_peak には、反対側の音の漏れが足されても1を超えない余裕を持たせる。
out_peak = 0.85;
ref_pts = mean(pos_mic(1:num_bz, :), 1);
if use_dual
    ref_pts = [ref_pts; mean(pos_mic(num_bz+num_gz+1:end, :), 1)];
end
n_listen = size(listen_pts, 1);
all_pts = [listen_pts; ref_pts];
y_raw = cell(size(all_pts, 1), 1);

pos_bz_pt = pos_mic(1:num_bz, :);
pos_gz_pt = pos_mic(num_bz+1 : num_bz+num_gz, :);
pos_dz_pt = pos_mic(num_bz+num_gz+1 : end, :);
in_zone = @(p, pt) (~isempty(p) && pt(1) >= min(p(:,1)) && pt(1) <= max(p(:,1)) && ...
                     pt(2) >= min(p(:,2)) && pt(2) <= max(p(:,2)));
if num_gz > 0
    gz_lo = min(pos_gz_pt(:,1));  gz_hi = max(pos_gz_pt(:,1));
    box_bz = [min(pos_bz_pt(:,1)), gz_lo, min(pos_bz_pt(:,2)), max(pos_bz_pt(:,2))];
    box_gz = [gz_lo, gz_hi, min(pos_gz_pt(:,2)), max(pos_gz_pt(:,2))];
    box_dz = [gz_hi, max(pos_dz_pt(:,1)), min(pos_dz_pt(:,2)), max(pos_dz_pt(:,2))];
    in_box = @(bx, pt) (pt(1) >= bx(1) && pt(1) <= bx(2) && pt(2) >= bx(3) && pt(2) <= bx(4));
end

if use_dual, tag = "dual"; else, tag = "single"; end

for ip = 1:size(all_pts, 1)
    is_listen = ip <= n_listen;
    x_target = all_pts(ip, 1);
    y_target = all_pts(ip, 2);

    %% ゾーン判定
    if use_dual
        if in_box(box_gz, [x_target, y_target])
            zone_label = "Gradation Zone (GZ: 両方の音が遷移)";
        elseif in_box(box_bz, [x_target, y_target])
            zone_label = "音Aの明るい側 (左ゾーン)";
        elseif in_box(box_dz, [x_target, y_target])
            zone_label = "音Bの明るい側 (右ゾーン)";
        else
            zone_label = "制御ゾーン外 (BZ/GZ/DZいずれにも属さない)";
        end
    elseif num_gz > 0
        if in_box(box_gz, [x_target, y_target])
            zone_label = "Gradation Zone (GZ)";
        elseif in_box(box_bz, [x_target, y_target])
            zone_label = "Bright Zone (BZ)";
        elseif in_box(box_dz, [x_target, y_target])
            zone_label = "Dark Zone (DZ)";
        else
            zone_label = "制御ゾーン外 (BZ/GZ/DZいずれにも属さない)";
        end
    elseif in_zone(pos_bz_pt, [x_target, y_target])
        zone_label = "Bright Zone (BZ)";
    elseif strcmp(geometry_mode, "referenceL") && ...
            ((abs(y_target - 0.10) <= 0.02 && x_target >= 0 && x_target <= 1.0) || ...
             (abs(x_target) <= 0.02 && y_target >= 0.14 && y_target <= 1.60))
        zone_label = "Dark control line (L)";
    elseif in_zone(pos_dz_pt, [x_target, y_target])
        zone_label = "Dark Zone (DZ)";
    else
        zone_label = "制御ゾーン外 (BZ/GZ/DZいずれにも属さない)";
    end
    if is_listen
        fprintf("指定座標 (x=%.3f, y=%.3f) は [%s] に位置します。\n", x_target, y_target, zone_label);
    end

    %% 聴取点の周波数応答
    G_point = IR_freefield([x_target, y_target], pos_sp, k_list);  % [1 x num_sp x f_len]

    H_A = zeros(1, f_len);
    H_B = zeros(1, f_len);
    for n = 1:f_len
        H_A(n) = G_point(:,:,n) * drv(:,n);
        if use_dual
            H_B(n) = G_point(:,:,n) * drvB(:,n);
        end
    end

    L_A = 10 * log10(sum(abs(H_A).^2) / E_ref_A);
    if is_listen && use_dual
        L_B = 10 * log10(sum(abs(H_B).^2) / E_ref_B);
        fprintf("  レベル: 音A=%.1f dB, 音B=%.1f dB (差 %.1f dB)\n", L_A, L_B, L_A - L_B);
    elseif is_listen
        fprintf("  レベル: 音A=%.1f dB\n", L_A);
    end

    %% FIR化と畳み込み
    h_A = spec_to_fir(H_A, bin_idx, L_fir);
    y_A = conv(x_A, h_A);
    y_out = y_A;
    if use_dual
        h_B = spec_to_fir(H_B, bin_idx, L_fir);
        y_B = conv(x_B, h_B);
        y_out = y_out + y_B;
    end
    if ~is_listen
        ref_idx = ip - n_listen;
        if use_dual && ref_idx == 2
            y_out = y_B;
        else
            y_out = y_A;
        end
    end
    y_raw{ip} = y_out;
end

%% スケールをかけてWAV保存
peak_pts = cellfun(@(v) max(abs(v)), y_raw);
peak_ref = max(peak_pts(n_listen+1:end));
norm_scale = out_peak / (peak_ref + eps);
fprintf("共通スケール: %.4f (基準点の主役音ピーク %.4f -> %.2f)\n", norm_scale, peak_ref, out_peak);
for ip = 1:n_listen
    x_target = listen_pts(ip, 1);
    y_target = listen_pts(ip, 2);
    y_w = y_raw{ip} * norm_scale;
    if max(abs(y_w)) > 1
        warning('main:possibleClipping', '(%.2f, %.2f) の合成出力が1を超えるため、クリップして保存します。', x_target, y_target);
        y_w = max(min(y_w, 1), -1);
    end
    out_wav_path = sprintf("listen_%s_dz-%s_fl%g_at_x%.2f_y%.2f.wav", ...
        tag, dz_mode, floor_dB, x_target, y_target);
    audiowrite(out_wav_path, y_w, fs_audio);
    fprintf("聴取点 (x=%.3f, y=%.3f) の音声を '%s' として保存しました。\n", x_target, y_target, out_wav_path);
end
