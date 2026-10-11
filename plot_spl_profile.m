%% -------------------------------------------------------------------------
%% 5. 指定したy座標(1ライン)のx方向音圧プロファイルの描画
%% -------------------------------------------------------------------------
% 抽出するy座標の指定
y_target_line = zone_h;

% 指定したy座標に最も近い y 配列のインデックスを取得
[~, y_idx] = min(abs(y - y_target_line));
actual_y = y(y_idx); 

% 指定ラインの音圧レベル(SPL)を P_matrix から抽出
spl_profile = P_matrix(y_idx, :);

% 新しいグラフウィンドウを開く
figure;

% 評価には制御点の実座標を使う。con_*は図示用に内側へ縮めてあるため、
% そこから境界を取ると傾き・キンクの評価位置が物理境界からずれる。
pos_bz = pos_mic(1:num_bz, :);
pos_gz = pos_mic(num_bz+1:num_bz+num_gz, :);
pos_dz = pos_mic(num_bz+num_gz+1:end, :);
bz_x_min = min(pos_bz(:,1)); bz_x_max = max(pos_bz(:,1));
gz_x_min = min(pos_gz(:,1)); gz_x_max = max(pos_gz(:,1));
dz_x_min = min(pos_dz(:,1)); dz_x_max = max(pos_dz(:,1));

% Y軸の描画範囲を設定
y_min_plot = min(spl_profile) - 5;
y_max_plot = max(spl_profile) + 5;

% 1. BZ領域 (シアン)
patch([bz_x_min bz_x_max bz_x_max bz_x_min], ...
      [y_min_plot y_min_plot y_max_plot y_max_plot], ...
      'c', 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'DisplayName', 'Bright Zone');
hold on;

% 2. GZ領域 (グリーン) 
patch([gz_x_min gz_x_max gz_x_max gz_x_min], ...
      [y_min_plot y_min_plot y_max_plot y_max_plot], ...
      'g', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'DisplayName', 'Gradation Zone');

% 3. DZ領域 (グレー)
patch([dz_x_min dz_x_max dz_x_max dz_x_min], ...
      [y_min_plot y_min_plot y_max_plot y_max_plot], ...
      'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'DisplayName', 'Dark Zone');

% 4. 音圧プロファイルの折れ線グラフ
plot(x, spl_profile, '-','Color', [0, 0, 0.5], 'LineWidth', 1.5, ...
    'DisplayName', sprintf('Relative level (y = %.2f m)', actual_y));

% グラフの装飾設定
xlabel('x [m]');
ylabel('Relative broadband level [dB re mean BZ energy]');
title(sprintf('x-direction relative level at y = %.2f m', actual_y));

% 表示範囲とグリッドの設定
xlim([room_size(1), room_size(2)]);
ylim([y_min_plot, y_max_plot]);
grid on;

% 凡例の表示
legend('Location', 'best');

% プロファイルグラフも画像として保存する場合
profile_name = sprintf("SPL_Profile_y%.2fm.png", actual_y);
drawnow;
saveas(gcf, profile_name, 'png');

%% -------------------------------------------------------------------------
%% 6. 遷移の数値評価（快適性評価 軸①変化の速さ / 軸②不連続の有無）
%% -------------------------------------------------------------------------
% spl_profile (y=zone_h ラインのSPL) を x方向に数値微分し、
% 「どれだけ速く音圧が変化しているか」「境界で傾きが不連続に折れていないか」
% を dB/m 単位で定量化する。目視確認の補助であり、被験者評価と突き合わせる
% ための基準値としてCSVにも追記保存する。

% 空間微分 dSPL/dx [dB/m]。spl_profileはitv_room間隔の等間隔データなので単純差分でよい。
dSPL_dx = diff(spl_profile) / itv_room;
x_mid = (x(1:end-1) + x(2:end)) / 2; % 微分値に対応するx座標（区間の中点）

% --- 軸①: 変化の速さ（GZ内の傾きの大きさ）[dB/m] ---
gz_mask = (x_mid >= gz_x_min) & (x_mid <= gz_x_max);
slope_gz_max  = max(abs(dSPL_dx(gz_mask)));
slope_gz_mean = mean(abs(dSPL_dx(gz_mask)));

% --- 軸②: 不連続の有無（ゾーン境界での傾きのキンク量）[dB/m] ---
% 境界のすぐ内側・外側それぞれ数点分の平均傾きを比較し、その差(段差)を見る。
% 差が大きいほど「境界で急に変化の仕方が折れ曲がっている」ことを意味する。
edge_win = 3; % 境界から何グリッド点分の傾きを平均するか

% BZ-GZ境界（bz_x_max = gz_x_min 付近）
idx_b2g = find(x_mid >= bz_x_max, 1, 'first');
if isempty(idx_b2g), idx_b2g = length(dSPL_dx); end
i_lo = max(idx_b2g - edge_win, 1);
i_hi = min(idx_b2g + edge_win - 1, length(dSPL_dx));
slope_bz_side       = mean(dSPL_dx(i_lo:idx_b2g-1));
slope_gz_side_at_bz = mean(dSPL_dx(idx_b2g:i_hi));
kink_bz_gz = abs(slope_gz_side_at_bz - slope_bz_side);

% GZ-DZ境界（gz_x_max = dz_x_min 付近）
idx_g2d = find(x_mid >= gz_x_max, 1, 'first');
if isempty(idx_g2d), idx_g2d = length(dSPL_dx); end
i_lo = max(idx_g2d - edge_win, 1);
i_hi = min(idx_g2d + edge_win - 1, length(dSPL_dx));
slope_gz_side_at_dz = mean(dSPL_dx(i_lo:idx_g2d-1));
slope_dz_side       = mean(dSPL_dx(idx_g2d:i_hi));
kink_gz_dz = abs(slope_dz_side - slope_gz_side_at_dz);

% --- 補助指標: BZ/DZ内の平坦さ（リプル）[dB] ---
% 境界のキンク量だけでは「ゾーン内部で音圧が波打っている」状態を検知できない
% （スピーカー開口がゾーン幅に対して不足している場合などに発生）。
% そのため、BZ・DZそれぞれの区間内でのSPLの最大-最小(peak-to-peak)も併せて見る。
bz_line_mask = (x >= bz_x_min) & (x <= bz_x_max);
dz_line_mask = (x >= dz_x_min) & (x <= dz_x_max);
bz_ripple_pp = max(spl_profile(bz_line_mask)) - min(spl_profile(bz_line_mask));
dz_ripple_pp = max(spl_profile(dz_line_mask)) - min(spl_profile(dz_line_mask));

fprintf("\n--- 遷移の数値評価 (y = %.2f m) ---\n", actual_y);
fprintf("[軸1 変化の速さ] GZ内 傾き: 最大 %.2f dB/m, 平均 %.2f dB/m\n", slope_gz_max, slope_gz_mean);
fprintf("[軸2 不連続の有無] BZ-GZ境界キンク: %.2f dB/m,  GZ-DZ境界キンク: %.2f dB/m\n", kink_bz_gz, kink_gz_dz);
fprintf("[補助: ゾーン内リプル] BZ内 最大-最小: %.2f dB,  DZ内 最大-最小: %.2f dB\n", bz_ripple_pp, dz_ripple_pp);

% 実行のたびにCSVへ追記し、設定を変えた複数回の結果を後から比較できるようにする。
% (isfileはOctave環境によって未実装の場合があるため exist(...,'file') を使用)
log_file = "transition_metrics_log.csv";
write_header = (exist(log_file, 'file') ~= 2);
flog = fopen(log_file, 'a');
if flog ~= -1
    if write_header
        fprintf(flog, "timestamp,num_sp,bz_w,gz_w,dz_w,zone_h,dist_zone,AC_total,slope_gz_max_dB_per_m,slope_gz_mean_dB_per_m,kink_bz_gz_dB_per_m,kink_gz_dz_dB_per_m,bz_ripple_pp_dB,dz_ripple_pp_dB\n");
    end
    fprintf(flog, "%s,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f\n", ...
        datestr(now, 'yyyy-mm-dd HH:MM:SS'), num_sp, bz_size(1), gz_size(1), dz_size(1), zone_h, dist_zone, ...
        AC_total, slope_gz_max, slope_gz_mean, kink_bz_gz, kink_gz_dz, bz_ripple_pp, dz_ripple_pp);
    fclose(flog);
else
    warning('plot_spl_profile:logOpenFailed', 'transition_metrics_log.csv を開けなかったため、ログ追記をスキップしました。');
end
