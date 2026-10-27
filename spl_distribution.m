# 音圧分布図生成

%% 空間全体の計算用格子点の作成
x = room_size(1) : itv_room : room_size(2);
y = room_size(3) : itv_room : room_size(4);

[X, Y] = meshgrid(x, y);

pos_target = [X(:), Y(:)];

G_target = IR_freefield(pos_target, pos_sp, k_list);

%% 空間全体の音圧レベル（SPL [dB]）の計算

p_t = zeros(length(pos_target), f_len);

for n = 1:f_len
    g_t = G_target(:,:,n);  % 空間の各点に対する伝達関数を取り出す
    p_t(:,n) = g_t * drv(:,n);
end

% BZ制御点の平均広帯域エネルギーを0 dBとした相対レベル
bz_ref_power = mean(sum(abs(p_ctrl(1:num_bz, :)).^2, 2));
if ~isfinite(bz_ref_power) || bz_ref_power <= 0
    error('spl_distribution:invalidReferencePower', ...
        'BZ制御点の基準エネルギーが有限の正値ではありません。音場計算を確認してください。');
end
p_t_dB = 10 * log10(sum(abs(p_t).^2, 2) / bz_ref_power);

%% グラフに描画する各ゾーンの「四角い枠線」のコーナー座標計算
pos_bz = pos_mic(1:num_bz, :);
pos_dz = pos_mic(num_bz+num_gz+1:end, :);

if strcmp(geometry_mode, "referenceL")
    con_bz = [];
    con_dz = [];
else
    offset = 0.01;
    bx_min = min(pos_bz(:,1)) + offset; bx_max = max(pos_bz(:,1)) - offset;
    by_min = min(pos_bz(:,2)) + offset; by_max = max(pos_bz(:,2)) - offset;
    dx_min = min(pos_dz(:,1)) + offset; dx_max = max(pos_dz(:,1)) - offset;
    dy_min = min(pos_dz(:,2)) + offset; dy_max = max(pos_dz(:,2)) - offset;
    con_bz = [bx_min, by_min; bx_min, by_max; bx_max, by_max; bx_max, by_min; bx_min, by_min];
    con_dz = [dx_min, dy_min; dx_min, dy_max; dx_max, dy_max; dx_max, dy_min; dx_min, dy_min];
end

%% 音圧分布図のプロットと画像保存
figure  % 新しいグラフウィンドウを開く

% 黒 → 紫 → 赤 → 黄のカラーマップ
c_black  = [0.05 0.05 0.05];
c_purple = [0.35 0.00 0.55];
c_red    = [0.90 0.15 0.15];
c_yellow = [1.00 0.95 0.20];

n_c = 256;
c1 = round(n_c / 3);
c2 = round(n_c * 2 / 3);
custom_cmap = zeros(n_c, 3);

custom_cmap(1:c1, 1) = linspace(c_black(1), c_purple(1), c1);
custom_cmap(1:c1, 2) = linspace(c_black(2), c_purple(2), c1);
custom_cmap(1:c1, 3) = linspace(c_black(3), c_purple(3), c1);

custom_cmap(c1+1:c2, 1) = linspace(c_purple(1), c_red(1), c2-c1);
custom_cmap(c1+1:c2, 2) = linspace(c_purple(2), c_red(2), c2-c1);
custom_cmap(c1+1:c2, 3) = linspace(c_purple(3), c_red(3), c2-c1);

custom_cmap(c2+1:end, 1) = linspace(c_red(1), c_yellow(1), n_c-c2);
custom_cmap(c2+1:end, 2) = linspace(c_red(2), c_yellow(2), n_c-c2);
custom_cmap(c2+1:end, 3) = linspace(c_red(3), c_yellow(3), n_c-c2);

colormap(custom_cmap);

P_matrix = reshape(p_t_dB, size(X));

imagesc(x, y, P_matrix); hold on;
axis xy;  % imagesc特有の上下反転を直し、座標の向きを正常化する

scatter(pos_sp(:,1), pos_sp(:,2), 15, 'k', '^', 'filled'); hold on;
if strcmp(geometry_mode, "referenceL")
    scatter(pos_bz(:,1), pos_bz(:,2), 50, 'r', 'filled');
    scatter(pos_dz(:,1), pos_dz(:,2), 20, 'w', 'filled', 'MarkerEdgeColor', 'k');
else
    plot(con_bz(:,1), con_bz(:,2), 'c--', 'LineWidth', 0.8); hold on;
    plot(con_dz(:,1), con_dz(:,2), 'w--', 'LineWidth', 0.8);
end
hold off;
xlabel("x[m]"); ylabel("y[m]");  % 軸のラベル
colorbar  % 画面右側に音圧の大きさと色の対応を示すカラーバーを表示
caxis([-30 15])
title('Relative broadband level (mean BZ control-point energy = 0 dB)');
daspect([1 1 1])  % 空間の縦横比（アスペクト比）を 1:1 に固定

xlim([room_size(1), room_size(2)])
ylim([room_size(3), room_size(4)])

grid on;  % 背景に格子線を表示
ax = gca;  % 現在の軸の設定を取得

try
    set(ax, 'GridColor', [1, 1, 1]);
    set(ax, 'GridAlpha', 0.35);
    set(ax, 'GridLineStyle', ':');
catch
end

box on;  % 上と右にも黒い枠線を描画して閉じ込める
set(gca, 'Layer', 'top');  % 枠線とグリッド線をカラーマップの「上」に重ねる

set(gcf, 'PaperPositionMode', 'auto');

saveas(gcf, map_name, 'png');