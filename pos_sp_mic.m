# スピーカーとマイクの配置座標を計算する関数

function [pos_sp, pos_mic, num_mic, num_bz] = pos_sp_mic(num_sp, y_center, dist_zone, bz_size, dz_size, itv_mic, room_size, pltPos)
    
    % スピーカーの配置形状を切り替えるフラグ（false: 直線状 / true: 円弧状）
    isArc = false; 

    %% ---------------------------------------------------------------------
    %% 制御ゾーンの座標計算
    %% ---------------------------------------------------------------------

    % ブライトゾーンの計算
    bz_x = -bz_size(1)/2 : itv_mic(1) : bz_size(1)/2;
    bz_y = y_center - bz_size(2)/2 : itv_mic(2) : y_center + bz_size(2)/2;
    
    pos_bz = zeros(length(bz_x) * length(bz_y), 2);

    n=0;
    for x_idx = 1:length(bz_x)
        for y_idx = 1:length(bz_y)
            n = n + 1;
            pos_bz(n,:) = [bz_x(x_idx) - dist_zone/2, bz_y(y_idx)];
        end
    end
    num_bz = n; % BZのマイク数を保存
    
    % ダークゾーンの計算
    dz_x = -dz_size(1)/2 : itv_mic(1) : dz_size(1)/2;
    dz_y = y_center - dz_size(2)/2 : itv_mic(2) : y_center + dz_size(2)/2;
    
    pos_dz = zeros(length(dz_x) * length(dz_y), 2);
    n = 0;
    for x_idx = 1:length(dz_x)
        for y_idx = 1:length(dz_y)
            n = n + 1;
            pos_dz(n,:) = [dz_x(x_idx) + dist_zone/2, dz_y(y_idx)];
        end
    end
    
    % BZとDZを結合し、総マイク数を算出
    pos_mic = [pos_bz; pos_dz];
    num_mic = size(pos_mic, 1);

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
        h1 = scatter(pos_sp(:,1), pos_sp(:,2), 50, 'k', '^', 'filled'); hold on;
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