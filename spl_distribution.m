# 音圧分布図生成

%% -------------------------------------------------------------------------
%% 1. 空間全体の計算用格子点の作成
%% -------------------------------------------------------------------------
% 部屋の空間を2cm間隔の細かい網の目状に分割します
x = room_size(1) : itv_room : room_size(2);
y = room_size(3) : itv_room : room_size(4);

% meshgrid関数により、2次元の格子点座標（行列）を生成
[X, Y] = meshgrid(x, y);

% 行列を縦一列のベクトルに変換し、空間内のすべての評価点の座標ペアを作成 [点数 × 2列(x,y)]
pos_target = [X(:), Y(:)];

% 外部関数 IR_freefield.m を再利用し、32台のスピーカーから「空間内のすべての評価点」への伝達関数を計算
G_target = IR_freefield(pos_target, pos_sp, k_list);

%% -------------------------------------------------------------------------
%% 2. 空間全体の音圧レベル（SPL [dB]）の計算
%% -------------------------------------------------------------------------
f_len = length(freq_list);

% 空間内のすべての点における複素音圧を格納する行列を初期化
p_t = zeros(length(pos_target), f_len);

for n = 1:f_len
    g_t = G_target(:,:,n);      % 空間の各点に対する伝達関数を取り出す
    p_t(:,n) = g_t * drv(:,n);  % 伝達関数にスピーカーの駆動信号（drv）を掛け合わせて、実際の合成音圧を算出
end

% 複素音圧の絶対値の二乗（音のエネルギー）を計算し、常用対数を用いてデシベル（dB）スケールに変換
% ※これにより、人間が耳で感じる音の大きさに近い音圧レベル（SPL）の分布が得られます
p_t_dB = 10 * log10(sum(abs(p_t).^2, 2));

%% -------------------------------------------------------------------------
%% 3. グラフに描画する各ゾーンの「四角い枠線」のコーナー座標計算
%% -------------------------------------------------------------------------
% マイクの座標から、ブライトゾーンとダークゾーンのそれぞれの位置を抽出
pos_bz = pos_mic(1:num_bz, :);
pos_gz = pos_mic(num_bz+1 : num_bz+num_gz, :);
pos_dz = pos_mic(num_bz+num_gz+1:end, :);

offset = 0.01;

% 各ゾーンの最小・最大座標を取得し、オフセットを適用してわずかに内側に縮める
bx_min = min(pos_bz(:,1)) + offset; bx_max = max(pos_bz(:,1)) - offset;
by_min = min(pos_bz(:,2)) + offset; by_max = max(pos_bz(:,2)) - offset;

gx_min = min(pos_gz(:,1)) + offset; gx_max = max(pos_gz(:,1)) - offset;
gy_min = min(pos_gz(:,2)) + offset; gy_max = max(pos_gz(:,2)) - offset;

dx_min = min(pos_dz(:,1)) + offset; dx_max = max(pos_dz(:,1)) - offset;
dy_min = min(pos_dz(:,2)) + offset; dy_max = max(pos_dz(:,2)) - offset;

% 補正した座標で、それぞれの四角形のコーナー座標を構築（5つの角で始点に戻る）
con_bz = [bx_min, by_min; bx_min, by_max; bx_max, by_max; bx_max, by_min; bx_min, by_min];
con_gz = [gx_min, gy_min; gx_min, gy_max; gx_max, gy_max; gx_max, gy_min; gx_min, gy_min];
con_dz = [dx_min, dy_min; dx_min, dy_max; dx_max, dy_max; dx_max, dy_min; dx_min, dy_min];

%% -------------------------------------------------------------------------
%% 4. 音圧分布図のプロットと画像保存
%% -------------------------------------------------------------------------
figure % 新しいグラフウィンドウを開く

% ② 黒 -> 紫 -> 赤 -> 黄 となるカスタムカラーマップの作成
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

% カラーマップの適用
colormap(custom_cmap);

% 1次元の音圧ベクトルを、2次元の格子サイズ（画像形状）に変形
P_matrix = reshape(p_t_dB, size(X)); 


% imagesc を使って音圧分布を画像としてプロット（これで枠線でスパッと切れます）
h1 = imagesc(x, y, P_matrix); hold on;
axis xy; % imagesc特有の上下反転を直し、座標の向きを正常化する

h2 = scatter(pos_sp(:,1), pos_sp(:,2), 15, 'k', '^', 'filled'); hold on;
% ③ エリアの点線を見やすい色（シアンと白）、細い破線（LineWidth: 0.8）に変更
h4 = plot(con_bz(:,1), con_bz(:,2), 'c--', 'LineWidth', 0.8); hold on;
h5 = plot(con_dz(:,1), con_dz(:,2), 'w--', 'LineWidth', 0.8); hold off;
% グラフの装飾設定
xlabel("x[m]"); ylabel("y[m]"); % 軸のラベル
colorbar                        % 画面右側に音圧の大きさと色の対応を示すカラーバーを表示
caxis([-60 15])                 % （コメントアウト：カラーバーの最小値・最大値を固定したい場合に使用）
daspect([1 1 1])                % 空間の縦横比（アスペクト比）を 1:1 に固定

% 表示範囲ををピクセルの「端」ぴったりに合わせる
xlim([room_size(1), room_size(2)])
ylim([room_size(3), room_size(4)])

grid on;                        % 背景に格子線を表示
ax = gca;                       % 現在の軸の設定を取得

% Octaveでもエラーが出ないように set 関数に書き換え
try
    set(ax, 'GridColor', [1, 1, 1]);
    set(ax, 'GridAlpha', 0.35);
    set(ax, 'GridLineStyle', ':');
catch
    % 万が一、古いOctaveでプロパティ自体が存在しない場合はスキップ
end

% 枠線を四方すべてに閉じ、最前面に持ってくる
box on;                         % 上と右にも黒い枠線を描画して閉じ込める
set(gca, 'Layer', 'top');       % 枠線とグリッド線をカラーマップの「上」に重ねる

% 画面で見えている通りのサイズ・余白のまま保存する設定
set(gcf, 'PaperPositionMode', 'auto'); 

% main.m であらかじめ生成されたファイル名（map_name）で、描画したグラフをPNG画像として保存
saveas(gcf, map_name, 'png');