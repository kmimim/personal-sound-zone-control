% ワークスペースの初期化
clear; clc; close all;

Nsrc = 1;         % 制御目標とする仮想的な音源の数（ここでは1つの平面波を想定）
ang_wave = pi/2;  % 音波が進んでくる方向 [rad]（pi/2 = 90度：真下から真上へ進む平面波）
amp_src = ones(1,Nsrc); % 仮想音源の振幅（1 = 基準振幅として設定）

freq_list = 500:100:2000;
c = 340;% 音速 [m/s]
k_list = 2*pi*freq_list/c;
f_len = length(freq_list);

%% -------------------------------------------------------------------------
%% 心理音響閾値パラメータ (Phase 2)
%% -------------------------------------------------------------------------
% GZの「なめらかさ」を文献値から定量的に定義するための3つの仮定。
% ここを書き換えるだけで感度分析ができるよう、main.mの先頭にまとめている。
delta_JND = 1.0;    % 音圧レベル弁別閾 [dB]
                     % (Jesteadt, Wier, & Green, 1977, JASA; Stellmack, Viemeister,
                     %  & Byrne, 2004, JASA により、広帯域信号ではレベル非依存の
                     %  一定値として扱ってよいとの根拠あり)
tau = 0.050;         % ラウドネスの時間積分定数 [s] (release/BZ->DZ方向を採用)
                     % (Moore, 2014, Trends in Hearing; Glasberg & Moore, 2002)
v_walk = 1.31;       % 想定歩行速度 [m/s] (usual pace)
                     % (Outdoor walking speeds of apparently healthy adults:
                     %  A systematic review and meta-analysis, Sports Medicine, 2020)

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

%% -------------------------------------------------------------------------
%% 心理音響閾値からfloor_dBを算出 (Phase 2)
%% -------------------------------------------------------------------------
% slope_max_dBps : 許容される音圧変化率 [dB/s]。歩行速度に依存しない
%                  (耳の時間積分特性そのもの)。
% slope_max_space: それを歩行速度で空間側 [dB/m] に変換したもの。
%                  歩くのが速いほど、同じ滑らかさを保つための許容勾配は厳しくなる。
% floor_dB_max   : 現在のGZ幅(gz_size(1))で、心理音響的に正当化できる
%                  最大減衰量 [dB]。1.5はスムーズステップのピーク勾配/平均勾配比
%                  (境界だけでなくGZ内のどの点でも閾値を超えないようにするための補正)。
slope_max_dBps  = delta_JND / tau;
slope_max_space = slope_max_dBps / v_walk;
floor_dB_max    = -slope_max_space * gz_size(1) / 1.5;

fprintf("JND設計: slope_max=%.1fdB/s, GZ幅=%.2fm -> floor_dB_max=%.2fdB\n", ...
    slope_max_dBps, gz_size(1), floor_dB_max);

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
drv = filter_pm(pos_mic, G_ctrl, freq_list, ang_wave, amp_src, Nsrc, c, num_bz, num_gz, floor_dB_max);

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

    % 心理音響閾値による滑らかさの検証 (Phase 2)
    % 設計目標(floor_dB_max)通りに実現されているとは限らない(PMは最小二乗解のため)。
    % 実際に計算された spl_profile / x に対して、同じ delta_JND, tau, v_walk で
    % 事後チェックする。
    r = eval_jnd_smoothness(spl_profile, x, v_walk, delta_JND, tau);
    fprintf("JND評価: 最大変化率=%.1fdB/s (閾値%.1fdB/s), 違反区間=%.1f%%, 違反指数=%.2f\n", ...
        max(abs(r.slope_dBps)), r.slope_max_dBps, r.viol_ratio*100, r.viol_index);
end