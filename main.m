% ワークスペースの初期化
clear; clc; close all;

Nsrc = 1;         % 制御目標とする仮想的な音源の数（ここでは1つの平面波を想定）
ang_wave = pi/2;  % 音波が進んでくる方向 [rad]（pi/2 = 90度：真下から真上へ進む平面波）
amp_src = ones(1,Nsrc); % 仮想音源の振幅（1 = 基準振幅として設定）

freq_list = 500:100:2000;
c = 340;% 音速 [m/s]
k_list = 2*pi*freq_list/c;
f_len = length(freq_list);

% グラフ描画のフラグ
pltPos = true;    % pltPos = スピーカーとマイクの配置図
pltSPL = true;    % pltSPL = 空間全体の音圧レベル分布図

mthd_ctrl = "wpm"; % 音場制御の手法 = PM法

%% -------------------------------------------------------------------------
%% 空間および制御ゾーンの設定
%% -------------------------------------------------------------------------
% 部屋の大きさ [xの最小値, xの最大値, yの最小値, yの最大値]
room_size = [-1.5, 1.5, 0, 2.0];
itv_room = 0.02;          % 空間全体の計算用格子点の間隔 [m]

%% スピーカーとマイクの配置
num_sp = 32;      % 使用するスピーカー数
% 制御ゾーン（Bz, Gz, Dz）の設定
zone_h = 1.0;             % 制御ゾーンの中心高さ(y座標) [m]
dist_zone = 2.0;          % BzとDzの中心間距離 [m] (現在は各ゾーンの絶対座標で配置)
bz_size = [1.0, 2.0];     % Bzの大きさ [幅(x), 奥行き(y)] [m]
gz_size = [1.0, 2.0];     % Gzの大きさ [幅(x), 奥行き(y)] [m] (新規追加)
dz_size = [1.0, 2.0];     % Dzの大きさ [幅(x), 奥行き(y)] [m]

% 制御点（マイク）の配置間隔 [x方向, y方向]
itv_mic = [0.04, 0.08];

[pos_sp, pos_mic, num_mic, num_bz, num_gz] = pos_sp_mic(num_sp, zone_h, dist_zone, bz_size, gz_size, dz_size, itv_mic, room_size, pltPos);

%% -------------------------------------------------------------------------
%% 自由空間の伝達関数計算
%% -------------------------------------------------------------------------
% 外部関数 IR_freefield.m を呼び出し、各スピーカーから各マイクへの音の伝わり方を計算

%% -------------------------------------------------------------------------
%% フィルターの算出と音場制御
%% -------------------------------------------------------------------------
% G_ctrl : 伝達関数行列[64マイク × 32スピーカー × 1周波数]
G_ctrl = IR_freefield(pos_mic, pos_sp, k_list);
drv = filter_pm(pos_mic, G_ctrl, freq_list, ang_wave, amp_src, Nsrc, c, num_bz, num_gz);

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

% 広帯域全体のAC (空間と周波数のすべてのエネルギーを合算)
% p_bz(:) とすることで、行列内の全要素を1つの列ベクトルにして一気に計算します
AC_total = 10 * log10( sum(abs(p_bz(:)).^2) / sum(abs(p_dz(:)).^2) );

fprintf("Broadband: %d-%dHz, AC=%.3fdB\n", freq_list(1), freq_list(end), AC_total);

% 各マイク位置における音圧レベル（SPL）をdBスケールに変換
SPL_ctrl = 10 * log10(abs(p_ctrl).^2);

%% -------------------------------------------------------------------------
%% 空間全体の音圧分布図の作成と結果表示
%% -------------------------------------------------------------------------
% 保存する画像ファイル名の生成
% 画像ファイル名の設定
map_name = sprintf("SPL_Broadband_%d-%dHz_AC=%.2f.png", freq_list(1), freq_list(end), AC_total);
y_center = zone_h;

% pltSPL フラグが宣言のみで未使用だったため、ここで実際にON/OFFを反映させる
if pltSPL
    spl_distribution;
end

% コマンドウィンドウに結果（周波数、スピーカー数、マイク数、ACの計算値）をテキスト表示
fprintf("f=%d-%dHz, num_sp=%d, num_mic=%d, AC=%.3fdB\n", freq_list(1), freq_list(end), num_sp, num_mic, AC_total);

% plot_spl_profile.m は spl_distribution.m が作る P_matrix/x/y/con_bz等に依存するため、
% 同じ pltSPL フラグで連動させる（pltSPL=falseのときに未定義変数エラーになるのを防ぐ）
if pltSPL
    run plot_spl_profile.m
end

%% =====================================================================
%% 追加機能: 任意座標での聴取音声の生成・再生・保存
%% (既存の音場制御・AC・SPL計算には一切手を加えない独立処理)
%% =====================================================================

%% 1. 聴取点座標をユーザーに入力させる
% input()を引数なし(数値モード)で使うと入力文字列がevalされてしまい、
% 空白や不正な文字列があるとスクリプト呼び出しエラーになるため、
% 文字列として受け取りstr2doubleで数値化する（evalを回避）。
x_target = str2double(input('聴取点の x 座標 [m] を入力してください: ', 's'));
y_target = str2double(input('聴取点の y 座標 [m] を入力してください: ', 's'));
if isnan(x_target) || isnan(y_target)
    error('main:invalidInput', '座標には数値を入力してください。');
end

%% 2. 指定座標がBZ/GZ/DZのどこにあるか判定
pos_bz_pt = pos_mic(1:num_bz, :);
pos_gz_pt = pos_mic(num_bz+1 : num_bz+num_gz, :);
pos_dz_pt = pos_mic(num_bz+num_gz+1 : end, :);

in_zone = @(p, pt) (pt(1) >= min(p(:,1)) && pt(1) <= max(p(:,1)) && ...
                     pt(2) >= min(p(:,2)) && pt(2) <= max(p(:,2)));

if in_zone(pos_bz_pt, [x_target, y_target])
    zone_label = "Bright Zone (BZ)";
elseif in_zone(pos_gz_pt, [x_target, y_target])
    zone_label = "Gradation Zone (GZ)";
elseif in_zone(pos_dz_pt, [x_target, y_target])
    zone_label = "Dark Zone (DZ)";
else
    zone_label = "制御ゾーン外 (BZ/GZ/DZいずれにも属さない)";
end
fprintf("指定座標 (x=%.3f, y=%.3f) は [%s] に位置します。\n", x_target, y_target, zone_label);

%% 3. 指定座標-各スピーカー間の伝達関数を計算し、既存drvと組み合わせて
%%    その座標での周波数応答 H_sys(f) を求める (freq_listの各点のみ)
G_point = IR_freefield([x_target, y_target], pos_sp, k_list); % [1 x num_sp x f_len]

H_sys_design = zeros(1, f_len);
for n = 1:f_len
    H_sys_design(n) = G_point(:,:,n) * drv(:,n);
end

%% 4. 入力音声(RAW音声)の読み込み
% .raw はヘッダを持たないPCM生データのため audioread では読めない。
% サンプリングレート・ビット深度・チャンネル数は毎回入力させず、
% 以下の固定値を使用する（録音環境に合わせてここを書き換えてください）。
fs_audio    = 8000;   % サンプリングレート [Hz]
bit_depth   = 16;     % ビット深度 (16bit固定)
n_channels  = 2;       % チャンネル数 (1: モノラル, 2: ステレオ)

raw_type = 'int16';   % bit_depth=16 に対応する読み込み型
max_val  = 2^15;       % 16bit符号付き整数のフルスケール値

in_wav_path = input('入力音声ファイル(.raw)のパスを入力してください: ', 's');

fid = fopen(in_wav_path, 'rb');
if fid == -1
    error('main:fileOpenFailed', 'ファイルを開けませんでした: %s', in_wav_path);
end
raw_data = fread(fid, Inf, raw_type);
fclose(fid);

% チャンネル数に応じてインターリーブを分離し、多チャンネルはモノラル化
if n_channels > 1
    n_frames = floor(numel(raw_data) / n_channels);
    raw_data = reshape(raw_data(1:n_frames*n_channels), n_channels, n_frames).';
    x_audio = mean(raw_data, 2);
else
    x_audio = raw_data;
end
x_audio = double(x_audio) / max_val;

%% 5. FFT -> 指定座標の周波数応答H_sysを畳み込み -> 逆FFTで時間波形に戻す
N_audio = length(x_audio);
Xf = fft(x_audio);

% 各FFTビンの周波数(正負を考慮)
freq_bins = (0:N_audio-1)' * (fs_audio / N_audio);
freq_signed = freq_bins;
neg_idx = freq_bins > fs_audio/2;
freq_signed(neg_idx) = freq_bins(neg_idx) - fs_audio;

% freq_list(500-2000Hz)の範囲外は音場制御が行われていないため0とする(帯域制限)。
% 正の周波数側はH_sys_designを線形補間、負の周波数側は複素共役で埋め実信号を保証する。
H_full = zeros(N_audio, 1);
pos_f_idx = freq_signed >= 0;
H_full(pos_f_idx)  = interp1(freq_list, H_sys_design, freq_signed(pos_f_idx), 'linear', 0);
H_full(~pos_f_idx) = conj(interp1(freq_list, H_sys_design, -freq_signed(~pos_f_idx), 'linear', 0));

Yf = Xf .* H_full;
y_out = real(ifft(Yf));

% 出力(y_out)自身のピークで正規化すると、座標ごとに異なるはずの
% 音量(BZ/GZ/DZのコントラスト)が毎回0.95に均されて消えてしまう。
% 入力音声(x_audio)側のピークを基準にした固定スケールを使うことで、
% 座標間の相対的な音量差を保持したまま保存する。
norm_scale = 0.95 / (max(abs(x_audio)) + eps);
y_out = y_out * norm_scale;
if max(abs(y_out)) > 1
    warning('main:possibleClipping', '出力振幅が1を超えています。クリッピングに注意してください。');
end

%% 6. WAV保存 (自動再生はしない)
out_wav_path = sprintf("listen_at_x%.2f_y%.2f.wav", x_target, y_target);
audiowrite(out_wav_path, y_out, fs_audio);
fprintf("聴取点 (x=%.3f, y=%.3f) の音声を '%s' として保存しました。\n", x_target, y_target, out_wav_path);