% スピーカーとマイクの配置座標を計算する関数
function [pos_sp, pos_mic, num_mic] = pos_sp_mic(num_sp, y_center, n_x, n_y, d1, d2, pltPos)

    % スピーカーの配置形状を切り替えるフラグ（false: 直線状 / true: 円弧状）
    isArc = false; 

    %% ---------------------------------------------------------------------
    %% 制御ゾーンの座標計算
    %% ---------------------------------------------------------------------
    % main.m から渡された点数と範囲を基に、正確な格子座標の配列を生成
    bz_x = linspace(-d1/2, d1/2, n_x);
    bz_y = linspace(-d2/2, d2/2, n_y);

    % -----------------------
    % シフト後の中心
    % -----------------------
    bz_center = [-1.0, y_center];
    dz_center = [ 1.0, y_center];
    dist_zone = dz_center(1) - bz_center(1); % BZとDZの中心間距離（2.0m）

    % -----------------------
    % 点格納
    % -----------------------
    num_bz = n_x * n_y; % ブライトゾーンの総点数
    pos_bz = zeros(num_bz, 2);

    % BZ（左）：格子状に配置
    n = 0;
    for x_idx = 1:length(bz_x)
        for y_idx = 1:length(bz_y)
            n = n + 1;
            pos_bz(n,:) = [bz_x(x_idx) + bz_center(1), ...
                        bz_y(y_idx) + bz_center(2)];
        end
    end

    %GZ（中央：-0.5 ~ 0.5）：格子状に配置
    gz_center = [0.0, y_center]; % 中央に配置
    pos_gz = zeros(num_bz, 2);   % 点数はBZと完全に一致させる
    n = 0;
    for x_idx = 1:length(bz_x)
        for y_idx = 1:length(bz_y)
            n = n + 1;
            pos_gz(n,:) = [bz_x(x_idx) + gz_center(1), ...
                        bz_y(y_idx) + gz_center(2)];
        end
    end

    % DZ（右：0.5 ~ 1.5）：今までと同様にＬの字配列に配置
    L_total = d1 + d2; 
    s = linspace(0, L_total, num_bz)'; % 点数はBZと完全に一致させる

    pos_dz = zeros(num_bz, 2);
    for i = 1:num_bz
        if s(i) <= d2
            % 縦辺（Dz領域の左端：上から下へ向かう）
            pos_dz(i, 1) = dz_center(1) - d1/2;
            pos_dz(i, 2) = (dz_center(2) + d2/2) - s(i);
        else
            % 底辺（Dz領域の下端：左から右へ向かう）
            pos_dz(i, 1) = (dz_center(1) - d1/2) + (s(i) - d2);
            pos_dz(i, 2) = dz_center(2) - d2/2;
        end
    end
    
    % 前半＝BZ（格子）、中盤＝GZ（格子）、後半＝DZ（L字）となるよう1つの行列に結合
    pos_mic = [pos_bz; pos_gz; pos_dz];
    % 実際に生成された総点数（3 * num_bz）を main.m 側へ返す
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
        
        x_sp_1 = -(num_sp-1)/2 * itv_sp;
        y_sp_1 = 0;       % スピーカーアレイの基準高さ（y=0）
        
        pos_sp = zeros(num_sp, 2);    % スピーカー座標の格納行列を初期化
        pos_sp(1,:) = [x_sp_1, y_sp_1]; % 1台目の座標を代入
        
        % 2台目以降のスピーカーの x 座標を等間隔で計算
        pos_sp(2:end, 1) = x_sp_1 + (1:num_sp-1) * itv_sp;
    end

    %% ---------------------------------------------------------------------
    %% 配置図の描画と画像保存
    %% ---------------------------------------------------------------------
    if pltPos
        figure % 新しいグラフウィンドウを開く
        hold on; % 先に重ね描きを有効にします
        
        % 全マイク座標から各ゾーンの座標を正しく抽出
        p_bz = pos_mic(1:num_bz, :);
        p_gz = pos_mic(num_bz+1:2*num_bz, :);
        p_dz = pos_mic(2*num_bz+1:end, :);
        
        % 各ゾーンのx方向の境界を取得
        bz_x_min = min(p_bz(:,1)); bz_x_max = max(p_bz(:,1));
        gz_x_min = min(p_gz(:,1)); gz_x_max = max(p_gz(:,1));
        dz_x_min = min(p_dz(:,1)); dz_x_max = max(p_dz(:,1));
        
        % Y軸の塗りつぶし範囲（マイクの上下に適度な余白を持たせる）
        y_min_plot = min(pos_mic(:,2)) - 0.2;
        y_max_plot = max(pos_mic(:,2)) + 0.2;
        
        % 1. BZの領域をシアンで薄く塗りつぶす
        patch([bz_x_min bz_x_max bz_x_max bz_x_min], ...
              [y_min_plot y_min_plot y_max_plot y_max_plot], ...
              'c', 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'DisplayName', 'Bright Zone');
          
        % 2. GZの領域を緑で薄く塗りつぶす
        patch([gz_x_min gz_x_max gz_x_max gz_x_min], ...
              [y_min_plot y_min_plot y_max_plot y_max_plot], ...
              'g', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'DisplayName', 'Gradient Zone');
          
        % 3. DZの領域をグレーで薄く塗りつぶす
        patch([dz_x_min dz_x_max dz_x_max dz_x_min], ...
              [y_min_plot y_min_plot y_max_plot y_max_plot], ...
              'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'DisplayName', 'Dark Zone');
        
        % スピーカー位置を黒い「▲」でプロット
        h1 = plot(pos_sp(:,1), pos_sp(:,2), '^k', 'MarkerFaceColor', 'k' , 'MarkerSize', 4); hold on;
        % 制御点をサイズ10の「●」でプロット
        h2 = scatter(pos_mic(:,1), pos_mic(:,2), 4,[0, 0, 0.5], 'filled');
        
        daspect([1 1 1])    % グラフの縦横比を 1:1 に固定
        xlim([-1.5,1.5 ])   % x軸の表示範囲を -1.5m 〜 1.5m に設定
        ylim([0, 2])        % y軸の表示範囲を 0m 〜 2m に設定
        
        xlabel("x[m]"); ylabel("y[m]"); % 軸ラベルの設定
        legend([h1, h2], {"sp", "mic"});      % 凡例の表示
        
        % 設定条件を自動的に組み込んだ保存用ファイル名を作成
        filename = sprintf("plc_sp_%d_mic_%d_zone-h_%.2fm_zone-dis_%.2fm.png", ...
                            num_sp, num_mic, y_center, dist_zone);
        title(sprintf("sp=%d, mic=%d, height=%.2f, dis=%.2f", num_sp, num_mic, y_center, dist_zone));
        
        set(gca, 'fontsize', 15)       
        saveas(gcf, filename, 'png');  
    end
end