function [pos_sp, pos_mic, num_mic, num_bz, num_gz] = pos_sp_mic(num_sp, y_center, dist_zone, bz_size, gz_size, dz_size, itv_mic, room_size, pltPos)
    
    % スピーカーの配置形状を切り替えるフラグ（false: 直線状 / true: 円弧状）
    isArc = false; 

    %% ---------------------------------------------------------------------
    %% 制御ゾーンの座標計算
    %% ---------------------------------------------------------------------
    % 各ゾーンの格子点の数と幅を計算 (すべてのゾーンが同じ間隔・サイズを前提)
    n_x = round(bz_size(1) / itv_mic(1)) + 1;
    n_y = round(bz_size(2) / itv_mic(2)) + 1;
    
    % 格子座標の配列を生成
    bz_x = linspace(-bz_size(1)/2, bz_size(1)/2, n_x);
    bz_y = linspace(-bz_size(2)/2, bz_size(2)/2, n_y);

    % -----------------------
    % 各ゾーンのシフト後中心位置
    % BZを左、GZを中央、DZを右に配置
    % -----------------------
    bz_center = [-1.0, y_center];
    gz_center = [ 0.0, y_center];
    dz_center = [ 1.0, y_center];

    % -----------------------
    % 点格納
    % -----------------------
    pos_bz = zeros(n_x*n_y, 2);
    pos_gz = zeros(n_x*n_y, 2);
    pos_dz = zeros(n_x*n_y, 2);

    n = 0;
    for x_idx = 1:length(bz_x)
        for y_idx = 1:length(bz_y)
            n = n + 1;
            % BZ（左）
            pos_bz(n,:) = [bz_x(x_idx) + bz_center(1), bz_y(y_idx) + bz_center(2)];
            % GZ（中央）
            pos_gz(n,:) = [bz_x(x_idx) + gz_center(1), bz_y(y_idx) + gz_center(2)];
            % DZ（右）
            pos_dz(n,:) = [bz_x(x_idx) + dz_center(1), bz_y(y_idx) + dz_center(2)];
        end
    end
    
    % BZ, GZ, DZを結合し、総マイク数を算出
    pos_mic = [pos_bz; pos_gz; pos_dz];
    num_mic = size(pos_mic, 1);
    num_bz = size(pos_bz, 1);
    num_gz = size(pos_gz, 1);

    %% ---------------------------------------------------------------------
    %% スピーカーアレイ（音源）の座標計算
    %% ---------------------------------------------------------------------
    if isArc
        itv_ang = pi/40;
        ang_sp = itv_ang * ((0.5 - num_sp/2) : (num_sp/2 - 0.5));
        x_sp = y_center * sin(ang_sp);
        y_sp = y_center - y_center * cos(ang_sp);
        pos_sp = [x_sp', y_sp'];
    else
        itv_sp = 0.085;   % スピーカー同士の間隔 [m]
        x_sp_1 = -(num_sp-1)/2 * itv_sp;
        y_sp_1 = 0;       
        
        pos_sp = zeros(num_sp, 2); 
        pos_sp(1,:) = [x_sp_1, y_sp_1]; 
        pos_sp(2:end, 1) = x_sp_1 + (1:num_sp-1) * itv_sp;
    end

    %% ---------------------------------------------------------------------
    %% 配置図の描画と画像保存
    %% ---------------------------------------------------------------------
    if pltPos
        figure 
        
        % スピーカーと各ゾーンのマイク配置を色分けして散布図で描画
        scatter(pos_sp(:,1), pos_sp(:,2), 15, 'k', '^', 'filled'); hold on;        
        scatter(pos_bz(:,1), pos_bz(:,2), 3, [0.25, 0.60, 0.75], 'filled'); % BZはシアン
        scatter(pos_gz(:,1), pos_gz(:,2), 3, [0.45, 0.70, 0.50], 'filled'); % GZはグリーン
        scatter(pos_dz(:,1), pos_dz(:,2), 3, [0.60, 0.60, 0.60], 'filled'); % DZはブラック


        daspect([1 1 1])
        xlim([room_size(1), room_size(2)])
        ylim([room_size(3), room_size(4)])
        grid on;
        
        xlabel("x[m]"); ylabel("y[m]");
        legend({"Speaker", "Bright Zone", "Gradation Zone", "Dark Zone"});
        
        filename = sprintf("plc_sp_%d_mic_%d_zone-h_%.2fm_zone-dis_%.2fm.png", ...
                           num_sp, num_mic, y_center, dist_zone);
        title(sprintf("sp=%d, mic=%d, height=%.2f", num_sp, num_mic, y_center));
        
        set(gca, 'fontsize', 15)
        saveas(gcf, filename, 'png');
    end
end