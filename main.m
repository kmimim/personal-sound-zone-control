% ワークスペースの初期化
clear; clc; close all;

Nsrc = 1;         % 制御目標とする仮想的な音源の数（ここでは1つの平面波を想定）
ang_wave = pi/2;  % 音波が進んでくる方向 [rad]（pi/2 = 90度：真下から真上へ進む平面波）
amp_src = ones(1,Nsrc); % 仮想音源の振幅（1 = 基準振幅として設定）

% 時間領域化で使うFFTと設計周波数を同じビンに合わせる。
fs_audio  = 16000;  % 入力音声(RAW)のサンプリングレート [Hz]
L_fir     = 1024;   % FIR長。周波数ビン間隔 fs_audio/L_fir = 15.625 Hz（以前の8kHz・L=512と同じ設計周波数ビン）
tau_model = 0.008;  % 因果化のためのモデリング遅延 [s] (16kHzで128サンプル)
floor_dB = -20.0;    % BZ目標振幅(amp_src)基準のGZ/DZ floor目標 [dB]
dz_mode = "floor";  % DZ目標: "zero" または "floor"
f_low     = 500;
f_high    = 2000;
bin_idx   = ceil(f_low*L_fir/fs_audio - 1e-9) : floor(f_high*L_fir/fs_audio + 1e-9);
freq_list = bin_idx * fs_audio / L_fir;
c = 340;% 音速 [m/s]
k_list = 2*pi*freq_list/c;
f_len = length(freq_list);

% グラフ描画のフラグ
pltPos = true;    % pltPos = スピーカーとマイクの配置図
pltSPL = true;    % pltSPL = 空間全体の音圧レベル分布図

% 二重音声と聴取音声の入出力設定（空 [] / "" の場合は実行時に対話入力）
dual_mode  = true;    % true: 二重音声(音A:BZ左 + 音B:BZ右) / false: 音Aのみ
listen_pts = [];      % 聴取点 [x, y] を行ごとに並べる。例: [-1.75 1.2; 0 1.2; 1.75 1.2]
rawA_path  = "";      % 音声A(.raw)のパス
rawB_path  = "";      % 音声B(.raw)のパス（dual_mode=true のとき使用）
n_channels = 1;       % RAWのチャンネル数 (1: モノラル, 2: ステレオ→平均してモノ化)

%% -------------------------------------------------------------------------
%% 空間および制御ゾーンの設定
%% -------------------------------------------------------------------------
% 部屋の大きさ [xの最小値, xの最大値, yの最小値, yの最大値]
% ゾーン合計幅(BZ+GZ+DZ=1.5+2.0+1.5=5.0m)を余裕を持って収めるため、
% x方向を左右に0.5mずつ広げてある（詳細は下のゾーン設定コメントを参照）。
room_size = [-3.0, 3.0, 0, 2.0];
itv_room = 0.02;          % 空間全体の計算用格子点の間隔 [m]

%% スピーカーとマイクの配置
% ゾーン幅を拡張(旧: 各1.0m -> 新: BZ/DZ=1.5m, GZ=2.0m)したことに伴い、
% ゾーン全体のx方向スパンが旧来の3.0mから5.0mへと広がった。
% スピーカー間隔(itv_sp=0.085m, pos_sp_mic.m内)を変えずに台数のみ増やすことで、
% 高域(2000Hz)での空間エイリアシング条件を悪化させずにアレイ開口を拡大している。
% num_sp=32(旧設定のまま)で試したところ、BZ端がアレイ開口(約2.64m幅)の外に
% はみ出し、BZ内でSPLが最大16dB近くも波打つ（フラットにならない）ことを
% 実測で確認したため、num_sp=64(開口幅 約5.36m、ゾーン全幅5.0mを両端で
% 覆う)に変更した。台数を増やせない場合は、BZ/GZ/DZ幅を狭めるか、
% itv_sp を大きくする(ただしエイリアシングのリスクが増す)必要がある。
num_sp = 64;      % 使用するスピーカー数
% 制御ゾーン（Bz, Gz, Dz）の設定
% zone_h : スピーカー列からゾーン中心までの距離[m]。ここでは「ポスターを見る
%          際の想定鑑賞距離」として暫定的に1.2mとしている（大型の縦型ポス
%          ターは概ね1.0〜1.5m程度の距離で見られることが多いという一般的な
%          目安に基づく仮値）。具体的な想定距離が決まったらこの1行を書き換える。
zone_h = 1.2;
% BZ幅1.5m・GZ幅2.0m・DZ幅1.5mを隙間なく隣接させるため、
% dist_zone(BZ-DZ中心間距離) = BZ半幅0.75 + GZ幅2.0 + DZ半幅0.75 = 3.5m とする。
dist_zone = 3.5;          % BzとDzの中心間距離 [m]
% ゾーンの奥行き(y方向)も、鑑賞距離の許容範囲として暫定的に1.0m
% (zone_h=1.2m を中心に y=0.7〜1.7m の範囲)とした。具体的な鑑賞距離レンジが
% 決まったら bz_size(2)/gz_size(2)/dz_size(2) を合わせて調整する。
bz_size = [1.5, 1.0];     % Bzの大きさ [幅(x), 奥行き(y)] [m]
gz_size = [2.0, 1.0];     % Gzの大きさ [幅(x), 奥行き(y)] [m]
dz_size = [1.5, 1.0];     % Dzの大きさ [幅(x), 奥行き(y)] [m]

% 制御点（マイク）の配置間隔 [x方向, y方向]
itv_mic = [0.04, 0.08];
itv_sp = 0.085;           % スピーカー間隔 [m]

% "zones": 現行のBZ/GZ/DZ配置
% "referenceL": placement.pdf と同じ部屋・再生点・L字抑圧点・スピーカー配置
geometry_mode = "zones";
if strcmp(geometry_mode, "referenceL")
    room_size = [-1.5, 1.5, 0, 3.0];
    num_sp = 32;
    zone_h = 1.0;
    dist_zone = 2.0;
    itv_sp = 0.05;
end

[pos_sp, pos_mic, num_mic, num_bz, num_gz] = pos_sp_mic( ...
    num_sp, zone_h, dist_zone, bz_size, gz_size, dz_size, itv_mic, room_size, pltPos, geometry_mode, itv_sp);

% 境界(x=±1m)の重複制御点は、pos_sp_mic.m の中で除去済み（GZ所属で1回だけ使う）。
fprintf("制御点数: %d 点（BZ=%d, GZ=%d, DZ=%d）\n", num_mic, num_bz, num_gz, num_mic - num_bz - num_gz);

% 二重音声は、BZ/DZを入れ替えた2つ目の音場が必要。GZが無い配置(referenceL)では使えない。
use_dual = dual_mode && num_gz > 0 && strcmp(geometry_mode, "zones");
if dual_mode && ~use_dual
    warning('main:dualUnavailable', '現在の配置(geometry_mode=%s)では二重音声を作れないため、音Aのみで進めます。', geometry_mode);
end

%% -------------------------------------------------------------------------
%% 自由空間の伝達関数計算
%% -------------------------------------------------------------------------
% 外部関数 IR_freefield.m を呼び出し、各スピーカーから各マイクへの音の伝わり方を計算

%% -------------------------------------------------------------------------
%% フィルターの算出と音場制御
%% -------------------------------------------------------------------------
% G_ctrl : 伝達関数行列[マイク数 × スピーカー数 × 周波数数]
G_ctrl = IR_freefield(pos_mic, pos_sp, k_list);
drv = filter_pm(pos_mic, G_ctrl, freq_list, ang_wave, amp_src, Nsrc, c, ...
    num_bz, num_gz, tau_model, floor_dB, dz_mode);

% 音B: BZ点群とDZ点群を入れ替え、GZの遷移方向も反転して設計する（右に音を届け、左を抑圧）
if use_dual
    idx_bz = 1:num_bz;
    idx_gz = num_bz+1 : num_bz+num_gz;
    idx_dz = num_bz+num_gz+1 : num_mic;
    idx_B  = [idx_dz, idx_gz, idx_bz];
    num_bzB = numel(idx_dz);
    G_ctrlB = G_ctrl(idx_B, :, :);
    drvB = filter_pm(pos_mic(idx_B,:), G_ctrlB, freq_list, ang_wave, amp_src, Nsrc, c, num_bzB, num_gz, tau_model, floor_dB, dz_mode, true);
end

%% -------------------------------------------------------------------------
%% 制御結果の評価
%% -------------------------------------------------------------------------
p_ctrl = zeros(num_mic, f_len);

% 全周波数分のマイク位置での合成音圧を計算
for n = 1:f_len
    p_ctrl(:, n) = G_ctrl(:,:,n) * drv(:,n);
end

% マイク群を分割 (全周波数分のデータ)
p_bz = p_ctrl(1:num_bz, :);
p_gz = p_ctrl(num_bz + 1:num_bz + num_gz, :);
p_dz = p_ctrl(num_bz + num_gz + 1:end, :);

% BZ/DZそれぞれの平均エネルギー比。ゾーンの制御点数が異なる設定でも
% 点数の差がAC値に混入しないよう、合計ではなく平均を比較する。
AC_total = 10 * log10(mean(abs(p_bz(:)).^2) / mean(abs(p_dz(:)).^2));

fprintf("Broadband: %d-%dHz, AC=%.3fdB\n", freq_list(1), freq_list(end), AC_total);

% 音Aの基準エネルギー（BZ平均、広帯域）。聴取点のレベル表示に使う。
E_ref_A = mean(abs(p_bz(:)).^2) * f_len;

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

%% -------------------------------------------------------------------------
%% 空間全体の音圧分布図の作成と結果表示
%% -------------------------------------------------------------------------
% 保存する画像ファイル名の生成
% 画像ファイル名の設定
% 条件の違うファイルを上書きしないよう dz_mode と floor_dB も入れる。
map_name = sprintf("Relative_%s_%s_floor%g_Broadband_%d-%dHz_AC=%.2f.png", ...
    geometry_mode, dz_mode, floor_dB, freq_list(1), freq_list(end), AC_total);
y_center = zone_h;

% pltSPL フラグが宣言のみで未使用だったため、ここで実際にON/OFFを反映させる
if pltSPL
    spl_distribution;
end

% コマンドウィンドウに結果（周波数、スピーカー数、マイク数、ACの計算値）をテキスト表示
fprintf("f=%d-%dHz, num_sp=%d, num_mic=%d, AC=%.3fdB\n", freq_list(1), freq_list(end), num_sp, num_mic, AC_total);

% plot_spl_profile.m は spl_distribution.m が作る P_matrix/x/y/con_bz等に依存するため、
% 同じ pltSPL フラグで連動させる（pltSPL=falseのときに未定義変数エラーになるのを防ぐ）
if pltSPL && num_gz > 0
    run plot_spl_profile.m
end

%% =====================================================================
%% 追加機能: 指定した聴取点での聴取音声の生成・保存（二重音声 / 音Aのみ）
%% (既存の音場制御・AC・SPL計算には一切手を加えない独立処理)
%% =====================================================================

%% 1. 聴取点座標（listen_pts が空なら対話入力）
% input()を数値モードで使うと入力文字列がevalされてしまうため、
% 文字列として受け取りstr2doubleで数値化する（evalを回避）。
if isempty(listen_pts)
    x_target = str2double(input('聴取点の x 座標 [m] を入力してください: ', 's'));
    y_target = str2double(input('聴取点の y 座標 [m] を入力してください: ', 's'));
    listen_pts = [x_target, y_target];
end
if size(listen_pts, 2) ~= 2 || any(~isfinite(listen_pts(:)))
    error('main:invalidInput', '聴取点は有限の数値で [x, y] の行として指定してください。');
end

%% 2. 入力音声(RAW音声)の読み込み
% .raw はヘッダを持たないPCM生データのため audioread では読めない。
raw_type = 'int16';   % 16bit PCM
max_val  = 2^15;      % 16bit符号付き整数のフルスケール値

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

% 長さが違えば短い方を0で埋める
n_max = max(numel(x_A), numel(x_B));
x_A(end+1:n_max, 1) = 0;
x_B(end+1:n_max, 1) = 0;

% 出力自身のピークで正規化すると座標ごとの音量差(BZ/GZ/DZのコントラスト)が消えてしまう。
% そこで、指定した全聴取点の出力を一度すべて作り、その中の最大ピークが out_peak になるような
% 「全座標共通の1つのスケール」をかける（座標間の相対的な音量差は保たれ、クリッピングも起きない）。
% 二重音声では2つの音が足し合わさるため、入力のピークだけを基準にするとBZでも1を超えることがある。
% ただし最大ピークを数えるのは、制御ゾーン(BZ/GZ/DZ)内の聴取点だけにする。スピーカー付近などゾーン外の点は
% 音圧が大きくなりやすく、含めるとゾーン内のスケールが下がってしまうため。ゾーン外の点が1を超える場合は警告してクリップする。
out_peak = 0.95;
y_raw = cell(size(listen_pts, 1), 1);
in_area = true(size(listen_pts, 1), 1);   % 聴取点が制御ゾーン内にあるか

pos_bz_pt = pos_mic(1:num_bz, :);
pos_gz_pt = pos_mic(num_bz+1 : num_bz+num_gz, :);
pos_dz_pt = pos_mic(num_bz+num_gz+1 : end, :);
in_zone = @(p, pt) (~isempty(p) && pt(1) >= min(p(:,1)) && pt(1) <= max(p(:,1)) && ...
                     pt(2) >= min(p(:,2)) && pt(2) <= max(p(:,2)));
% ゾーン境界の点はGZ所属で1回だけ使っているため、BZ/DZ側の制御点の範囲はGZの手前で終わる。
% 隙間(例: BZ最端の点とGZ端の間)に入った聴取点を「ゾーン外」と誤判定しないよう、
% ゾーン判定用の矩形は隣のGZの端まで広げて取る。
if num_gz > 0
    gz_lo = min(pos_gz_pt(:,1));  gz_hi = max(pos_gz_pt(:,1));
    box_bz = [min(pos_bz_pt(:,1)), gz_lo, min(pos_bz_pt(:,2)), max(pos_bz_pt(:,2))];
    box_gz = [gz_lo, gz_hi, min(pos_gz_pt(:,2)), max(pos_gz_pt(:,2))];
    box_dz = [gz_hi, max(pos_dz_pt(:,1)), min(pos_dz_pt(:,2)), max(pos_dz_pt(:,2))];
    in_box = @(bx, pt) (pt(1) >= bx(1) && pt(1) <= bx(2) && pt(2) >= bx(3) && pt(2) <= bx(4));
end

if use_dual, tag = "dual"; else, tag = "single"; end

for ip = 1:size(listen_pts, 1)
    x_target = listen_pts(ip, 1);
    y_target = listen_pts(ip, 2);

    %% 3. 指定座標がBZ/GZ/DZのどこにあるか判定
    if use_dual
        % 二重音声ではBZ(音A)の領域とDZ(音B)の領域が、それぞれ「自分の音の明るい側」になる
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
    fprintf("指定座標 (x=%.3f, y=%.3f) は [%s] に位置します。\n", x_target, y_target, zone_label);
    in_area(ip) = isempty(strfind(char(zone_label), '制御ゾーン外'));

    %% 4. 指定座標-各スピーカー間の伝達関数と駆動信号から、その座標での周波数応答を求める
    G_point = IR_freefield([x_target, y_target], pos_sp, k_list); % [1 x num_sp x f_len]

    H_A = zeros(1, f_len);
    H_B = zeros(1, f_len);
    for n = 1:f_len
        H_A(n) = G_point(:,:,n) * drv(:,n);
        if use_dual
            H_B(n) = G_point(:,:,n) * drvB(:,n);
        end
    end

    % その点での各音のレベル（それぞれの明るい側のBZ平均を0 dBとした広帯域レベル）
    L_A = 10 * log10(sum(abs(H_A).^2) / E_ref_A);
    if use_dual
        L_B = 10 * log10(sum(abs(H_B).^2) / E_ref_B);
        fprintf("  レベル: 音A=%.1f dB, 音B=%.1f dB (差 %.1f dB)\n", L_A, L_B, L_A - L_B);
    else
        fprintf("  レベル: 音A=%.1f dB\n", L_A);
    end

    %% 5. 共通FFTビン上の応答から因果FIRを作り、入力と線形畳み込み
    % 設計帯域外はゼロ(500-2000Hzの帯域制限)。8msのモデリング遅延で応答を因果側へ移してある。
    h_A = spec_to_fir(H_A, bin_idx, L_fir);
    y_out = conv(x_A, h_A);
    if use_dual
        h_B = spec_to_fir(H_B, bin_idx, L_fir);
        y_out = y_out + conv(x_B, h_B);
    end
    y_raw{ip} = y_out;
end

%% 6. 共通スケールをかけてWAV保存 (自動再生はしない)
peak_pts = cellfun(@(v) max(abs(v)), y_raw);
peak_pts = peak_pts(:);
if any(in_area)
    peak_ref = max(peak_pts(in_area));      % ゾーン内の聴取点だけでスケールを決める
else
    peak_ref = max(peak_pts);
end
norm_scale = out_peak / (peak_ref + eps);
fprintf("全聴取点共通のスケール: %.4f (ゾーン内の最大ピーク %.4f -> %.2f)\n", norm_scale, peak_ref, out_peak);
for ip = 1:size(listen_pts, 1)
    x_target = listen_pts(ip, 1);
    y_target = listen_pts(ip, 2);
    y_w = y_raw{ip} * norm_scale;
    if max(abs(y_w)) > 1
        warning('main:possibleClipping', '(%.2f, %.2f) はゾーン外で出力が1を超えるため、クリップして保存します。', x_target, y_target);
        y_w = max(min(y_w, 1), -1);
    end
    out_wav_path = sprintf("listen_%s_at_x%.2f_y%.2f_floor%g.wav", tag, x_target, y_target, floor_dB);
    audiowrite(out_wav_path, y_w, fs_audio);
    fprintf("聴取点 (x=%.3f, y=%.3f) の音声を '%s' として保存しました。\n", x_target, y_target, out_wav_path);
end