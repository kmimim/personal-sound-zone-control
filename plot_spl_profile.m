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

% 各ゾーンのx方向の境界を取得 (すでに計算済みの con_bz, con_gz, con_dz を利用)
bz_x_min = min(con_bz(:,1)); bz_x_max = max(con_bz(:,1));
dz_x_min = min(con_dz(:,1)); dz_x_max = max(con_dz(:,1));

% Y軸の描画範囲を設定
y_min_plot = min(spl_profile) - 5;
y_max_plot = max(spl_profile) + 5;

% 1. BZ領域 (シアン)
patch([bz_x_min bz_x_max bz_x_max bz_x_min], ...
      [y_min_plot y_min_plot y_max_plot y_max_plot], ...
      'c', 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'DisplayName', 'Bright Zone');
hold on;

% 3. DZ領域 (グレー)
patch([dz_x_min dz_x_max dz_x_max dz_x_min], ...
      [y_min_plot y_min_plot y_max_plot y_max_plot], ...
      'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'DisplayName', 'Dark Zone');

% 4. 音圧プロファイルの折れ線グラフ
plot(x, spl_profile, '-','Color', [0, 0, 0.5], 'LineWidth', 1.5, ...
    'DisplayName', sprintf('SPL Profile (y = %.2f m)', actual_y));

% グラフの装飾設定
xlabel('x [m]');
ylabel('Sound Pressure Level [dB]');
title(sprintf('x-direction SPL Profile at y = %.2f m', actual_y));

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