# スピーカーとマイクの配置座標を計算する関数

function [pos_sp, pos_mic, num_mic, num_bz] = pos_sp_mic(num_sp, y_center, dist_zone, bz_size, dz_size, itv_mic, room_size, pltPos)
    
    % スピーカーの配置形状を切り替えるフラグ（false: 直線状 / true: 円弧状）
    isArc = false; 

    %% ---------------------------------------------------------------------
    %% 制御ゾーンの座標計算
    %% ---------------------------------------------------------------------
    % bz_size と itv_mic から格子点の数と幅を計算
    n_x = round(bz_size(1) / itv_mic(1)) + 1;  % x方向の点数
    n_y = round(bz_size(2) / itv_mic(2)) + 1;  % y方向の点数
    d1 = bz_size(1);  % BZのx方向の幅
    d2 = bz_size(2);  % BZのy方向の幅

    % main.m から渡された点数と範囲を基に、正確な格子座標の配列を生成
    bz_x = linspace(-d1/2, d1/2, n_x);
    bz_y = linspace(-d2/2, d2/2, n_y);

    % -----------------------
    % シフト後の中心
    % -----------------------
    bz_center = [-1.0, y_center];
    dz_center = [ 1.0, y_center];
    % dist_zone = dz_center(1) - bz_center(1); % BZとDZの中心間距離（2.0m）

    % -----------------------
    % 点格納
    % -----------------------
    pos_bz = zeros(n_x*n_y,2);
    pos_dz = zeros(n_x*n_y,2);

    n = 0;
    for x_idx = 1:length(bz_x)
        for y_idx = 1:length(bz_y)
            n = n + 1;

            % BZ（左）
            pos_bz(n,:) = [bz_x(x_idx) + bz_center(1), ...
                        bz_y(y_idx) + bz_center(2)];

            % DZ（右）
            pos_dz(n,:) = [bz_x(x_idx) + dz_center(1), ...
                        bz_y(y_idx) + dz_center(2)];
        end
    end
    
    % BZとDZを結合し、総マイク数を算出
    pos_mic = [pos_bz; pos_dz];
    % 実際に生成された総点数を main.m 側へ返す
    num_mic = size(pos_mic, 1);
    num_bz = size(pos_bz, 1);  % BZのマイク数を返す

    %% ---------------------------------------------------------------------
    %% スピーカーアレイ（音源）の座標計算
    %% ---------------------------------------------------------------------

    %% 円弧状にスピーカーを配置する場合
    if isArc
        itv_ang = pi/40;  % スピーカー間の角度間隔 [rad]（180度/40 = 4.5度間隔）
        % 各スピーカーの配置角度を、中心（0度）から左右対称になるよう計算
        ang_sp = itv_ang * ((0.5 - num_sp/2) : (num_sp/2 - 0.5));
        
        % 三角関数を使って、円弧上の (x, y) 座標へ変換
        x_sp = y_center * sin(ang_sp);
        y_sp = y_center - y_center * cos(ang_sp);
        pos_sp = [x_sp', y_sp'];
        
    %% 直線状にスピーカーを配置する場合（デフォルト）
    else
        itv_sp = 0.085;   % スピーカー同士の間隔 [m]（8.5cm間隔）
        % ※この間隔から計算される空間サンプリング周波数は約2000Hzになります
        
        x_sp_1 = -(num_sp-1)/2 * itv_sp;
        y_sp_1 = 0;       % スピーカーアレイの基準高さ（y=0、つまり床面に設置するイメージ）
        
        pos_sp = zeros(num_sp, 2);    % スピーカー座標の格納行列を初期化 [32行 × 2列]
        pos_sp(1,:) = [x_sp_1, y_sp_1]; % 1台目の座標を代入
        
        % 2台目以降のスピーカーの x 座標を等間隔（itv_spずつ足していく）で計算
        pos_sp(2:end, 1) = x_sp_1 + (1:num_sp-1) * itv_sp;
        % （y座標は初期化時の0のまま固定）
    end

    %% ---------------------------------------------------------------------
    %% 配置図の描画と画像保存
    %% ---------------------------------------------------------------------
    if pltPos
        figure % 新しいグラフウィンドウを開く
        
        % スピーカーとマイクの配置を散布図で描画
        h1 = scatter(pos_sp(:,1), pos_sp(:,2), 15, 'k', '^', 'filled'); hold on;
        h2 = scatter(pos_mic(:,1), pos_mic(:,2), 10, 'filled');

        daspect([1 1 1])    % グラフの縦横比（アスペクト比）を 1:1 に固定（空間の歪みをなくす）
        xlim([room_size(1), room_size(2)])   % x軸の表示範囲
        ylim([room_size(3), room_size(4)])        % y軸の表示範囲
        grid on;            % グリッド線を表示
        
        xlabel("x[m]"); ylabel("y[m]"); % 軸ラベルの設定
        legend({"sp", "mic"});           % 凡例の表示（sp = スピーカー, mic = マイク）
        
        % 設定条件を自動的に組み込んだ保存用ファイル名を作成
        filename = sprintf("plc_sp_%d_mic_%d_zone-h_%.2fm_zone-dis_%.2fm.png", ...
                           num_sp, num_mic, y_center, dist_zone);
        % グラフのタイトルを設定
        title(sprintf("sp=%d, mic=%d, height=%.2f, dis=%.2f", num_sp, num_mic, y_center, dist_zone));
        
        set(gca, 'fontsize', 15)       % 文字サイズを大きくして見やすくする
        saveas(gcf, filename, 'png');  % 描画したグラフをPNG画像として保存
    end
end