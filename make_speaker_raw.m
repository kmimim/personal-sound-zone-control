%% 実機用: 各スピーカーに流す信号を、条件ごとに fs_out の16 bit raw（リトルエンディアン）で出力する
% main.m から run される（export_raw = true）。出力: out_dir/C{条件番号}_{名前}/spk01.raw ... spk32.raw
% 番号は左から（spk01 が最も左 = x が最小のスピーカー）。必要な変数は main.m で定義済み。
if ~use_dual
    error('make_speaker_raw:needDual', '二重音声(dual_mode=true, geometry_mode="zones")のときだけ使えます。');
end
raw_peak    = 0.9;    % 全スピーカー・全サンプルの最大値（条件ごと）
match_level = true;   % true: 音Aと音Bの、それぞれのBZ中心でのRMSをそろえる
plot_cond   = true;   % true: 条件ごとの制御点マップ・音圧マップ・折れ線グラフを out_dir/figs に保存（plot_conditions.m）
plot_show   = false;  % true: 図を画面にも表示する（false: ファイル保存のみ）
itv_map     = 0.04;   % 音圧マップの格子間隔 [m]（小さいほど細かいが遅い）
map_clim    = [-30 15]; % 音圧マップのカラーバーの範囲 [dB]（spl_distribution.m と同じ。深い抑圧を見るなら [-50 5] など）

% 条件: {名前, 種類, floor_dB}
rw_conds = {"nocontrol",   "front", 0;
            "conventional","nogz",  0;
            "gz_fl-20",    "gz",   -20;
            "gz_fl-30",    "gz",   -30};
rw_n = size(rw_conds, 1);

rw_df = fs_audio / L_fir;                  % 設計周波数の刻み [Hz]（main.m と同じ）
rw_L  = round(fs_out / rw_df);             % 出力側のFIR長
rw_idx_bz = 1:num_bz;
rw_idx_dz = num_bz+num_gz+1 : num_mic;
rw_xrA = -dist_zone/2 + [-1, 1] * bz_size(1)/2;
rw_xrB =  dist_zone/2 + [-1, 1] * dz_size(1)/2;
rw_refA = mean(pos_mic(rw_idx_bz, :), 1);  % 音量の基準点（音Aの明るい側の中心）
rw_refB = mean(pos_mic(rw_idx_dz, :), 1);  % 音量の基準点（音Bの明るい側の中心）
rw_Gref = IR_freefield([rw_refA; rw_refB], pos_sp, k_list);
rw_xl = (room_size(1):itv_room:room_size(2))';
rw_Gline = IR_freefield([rw_xl, zone_h * ones(numel(rw_xl), 1)], pos_sp, k_list);
rw_pts = [rw_refA(1), 0, rw_refB(1)];

rw_drvA = cell(rw_n, 1);  rw_drvB = cell(rw_n, 1);
rw_ctrlA = cell(rw_n, 1); rw_ctrlB = cell(rw_n, 1);
fprintf("\n予測値（自由空間、BZ平均エネルギーを0 dBとした広帯域レベル）\n");
fprintf("%-15s | 台数 | AC[dB] | 音A: 左BZ中心 / 中央 / 右ゾーン中心 [dB] | 音B: 左 / 中央 / 右BZ中心 [dB] | GZ内の最大傾き[dB/m] | BZ内の波打ち[dB] | 最大|drv|\n", "条件");
for q = 1:rw_n
    [rw_drvA{q}, rw_drvB{q}, rw_ctrlA{q}, rw_ctrlB{q}] = design_drive(rw_conds{q,2}, rw_conds{q,3}, pos_sp, pos_mic, num_bz, num_gz, G_ctrl, ...
        freq_list, ang_wave, amp_src, Nsrc, c, tau_model, rw_xrA, rw_xrB);
    pA = zeros(num_mic, f_len);  pB = pA;  pLA = zeros(numel(rw_xl), f_len);  pLB = pLA;
    for n = 1:f_len
        pA(:,n) = G_ctrl(:,:,n) * rw_drvA{q}(:,n);  pB(:,n) = G_ctrl(:,:,n) * rw_drvB{q}(:,n);
        pLA(:,n) = rw_Gline(:,:,n) * rw_drvA{q}(:,n);  pLB(:,n) = rw_Gline(:,:,n) * rw_drvB{q}(:,n);
    end
    rw_pb = pA(rw_idx_bz,:);  rw_pd = pA(rw_idx_dz,:);
    rw_AC = 10*log10(mean(abs(rw_pb(:)).^2) / mean(abs(rw_pd(:)).^2));
    rw_LA = 10*log10(sum(abs(pLA).^2, 2) / mean(sum(abs(pA(rw_idx_bz,:)).^2, 2)));
    rw_LB = 10*log10(sum(abs(pLB).^2, 2) / mean(sum(abs(pB(rw_idx_dz,:)).^2, 2)));
    rw_ingz = rw_xl >= -gz_size(1)/2 & rw_xl <= gz_size(1)/2;
    rw_slope = max(abs(diff(rw_LA(rw_ingz)))) / itv_room;
    rw_inbz = rw_xl >= rw_xrA(1) + 0.05 & rw_xl <= rw_xrA(2) - 0.05;
    rw_rip = max(rw_LA(rw_inbz)) - min(rw_LA(rw_inbz));
    rw_used = nnz(any(abs(rw_drvA{q}) > 0, 2) | any(abs(rw_drvB{q}) > 0, 2));
    fprintf("%-15s | %3d  | %6.2f | %7.2f / %7.2f / %7.2f | %7.2f / %7.2f / %7.2f | %9.1f | %8.2f | %7.1f\n", ...
        sprintf("C%d_%s", q, rw_conds{q,1}), rw_used, rw_AC, interp1(rw_xl, rw_LA, rw_pts), interp1(rw_xl, rw_LB, rw_pts), ...
        rw_slope, rw_rip, max(abs(rw_drvA{q}(:))));
end

% 入力音声を fs_out に変換（main.m で読み込み済みの x_A, x_B）
rw_xA = resample_fft(x_A, fs_audio, fs_out);
rw_xB = resample_fft(x_B, fs_audio, fs_out);
rw_N = max(numel(rw_xA), numel(rw_xB));
rw_xA(end+1:rw_N, 1) = 0;  rw_xB(end+1:rw_N, 1) = 0;
rw_pad = zeros(rw_L - 1, 1);
rw_rms = @(v) sqrt(mean(v.^2));

fprintf("\nBZ中心での主役音のRMS（予測）\n%-15s | 整合前: A / B / B-A [dB] | 整合後: B-A [dB]\n", "条件");
rw_S = cell(rw_n, 1);  rw_peak = zeros(rw_n, 1);  rw_rmsA = zeros(rw_n, 1);  rw_gB = ones(rw_n, 1);
for q = 1:rw_n
    rw_HrA = zeros(1, f_len);  rw_HrB = zeros(1, f_len);
    for n = 1:f_len
        rw_HrA(n) = rw_Gref(1,:,n) * rw_drvA{q}(:,n);
        rw_HrB(n) = rw_Gref(2,:,n) * rw_drvB{q}(:,n);
    end
    rw_yA = fftfilt(spec_to_fir(rw_HrA, bin_idx, rw_L), [rw_xA; rw_pad]);
    rw_yB = fftfilt(spec_to_fir(rw_HrB, bin_idx, rw_L), [rw_xB; rw_pad]);
    rw_rA = rw_rms(rw_yA);  rw_rB = rw_rms(rw_yB);
    if match_level && rw_rA > 0 && rw_rB > 0, rw_gB(q) = rw_rA / rw_rB; end   % 音Bを音Aに合わせる
    fprintf("%-15s | %7.4f / %7.4f / %+6.2f   | %+6.2f\n", sprintf("C%d_%s", q, rw_conds{q,1}), rw_rA, rw_rB, 20*log10(rw_rB/rw_rA), 20*log10(rw_rB*rw_gB(q)/rw_rA));
    rw_rmsA(q) = rw_rA;
    rw_S{q} = zeros(rw_N + rw_L - 1, num_sp);
    for n = 1:num_sp
        rw_hA = spec_to_fir(rw_drvA{q}(n,:), bin_idx, rw_L);
        rw_hB = spec_to_fir(rw_drvB{q}(n,:), bin_idx, rw_L);
        rw_S{q}(:,n) = fftfilt(rw_hA, [rw_xA; rw_pad]) + rw_gB(q) * fftfilt(rw_hB, [rw_xB; rw_pad]);
    end
    rw_peak(q) = max(abs(rw_S{q}(:)));
end

% 条件ごとに、最大値を raw_peak にそろえる（ビット深度を最大限に使う）。
% 条件間でBZ中心の音量(RMS、予測)をそろえるための再生ゲイン [dB] も求める（0 dB が最も大きな出力が必要な条件）。
rw_gain = raw_peak ./ rw_peak;
rw_bz_level = rw_gain .* rw_rmsA;
rw_rel_gain_dB = 20*log10(min(rw_bz_level) ./ rw_bz_level);

if ~exist(out_dir, 'dir'), mkdir(out_dir); end
rw_fid = fopen(fullfile(out_dir, "speaker_positions.csv"), 'w');
fprintf(rw_fid, "speaker,x_m,y_m\n");
for n = 1:num_sp, fprintf(rw_fid, "%d,%.4f,%.4f\n", n, pos_sp(n,1), pos_sp(n,2)); end
fclose(rw_fid);
rw_fid = fopen(fullfile(out_dir, "conditions_summary.csv"), 'w');
fprintf(rw_fid, "condition,type,floor_dB,digital_gain,level_match_gain_B,max_abs,samples,fs_out,relative_playback_gain_dB_to_equalize_BZ_level\n");
for q = 1:rw_n
    rw_d = fullfile(out_dir, sprintf("C%d_%s", q, rw_conds{q,1}));
    if ~exist(rw_d, 'dir'), mkdir(rw_d); end
    rw_Sq = rw_S{q} * rw_gain(q);
    for n = 1:num_sp
        rw_f = fopen(fullfile(rw_d, sprintf("spk%02d.raw", n)), 'wb');
        fwrite(rw_f, round(rw_Sq(:,n) * 32767), 'int16', 0, 'ieee-le');
        fclose(rw_f);
    end
    fprintf(rw_fid, "C%d_%s,%s,%g,%.6g,%.6g,%.4f,%d,%d,%.2f\n", q, rw_conds{q,1}, rw_conds{q,2}, rw_conds{q,3}, rw_gain(q), rw_gB(q), max(abs(rw_Sq(:))), size(rw_Sq,1), fs_out, rw_rel_gain_dB(q));
    fprintf("C%d_%s: 32ファイルを %s に出力（最大値 %.3f、BZ中心の音量をそろえる再生ゲイン %.1f dB）\n", q, rw_conds{q,1}, rw_d, max(abs(rw_Sq(:))), rw_rel_gain_dB(q));
end
fclose(rw_fid);

% 条件ごとの制御点マップ・音圧マップ・折れ線グラフ
if plot_cond
    run plot_conditions.m
end