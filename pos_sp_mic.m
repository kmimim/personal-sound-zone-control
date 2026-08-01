function [pos_sp, pos_mic, num_mic, num_bz, num_gz] = pos_sp_mic(num_sp, y_center, dist_zone, bz_size, gz_size, dz_size, itv_mic, room_size, pltPos)
    
    % スピーカーの配置形状を切り替えるフラグ（false: 直線状 / true: 円弧状）
    isArc = false; 

    %% ---------------------------------------------------------------------
    %% 制御ゾーンの座標計算
    %% ---------------------------------------------------------------------
    % 各ゾーンごとに、それぞれのサイズ(bz_size/gz_size/dz_size)から
    % 独立して格子点数・格子座標を計算する
    n_x_bz = round(bz_size(1) / itv_mic(1)) + 1;
    n_y_bz = round(bz_size(2) / itv_mic(2)) + 1;
    bz_x = linspace(-bz_size(1)/2, bz_size(1)/2, n_x_bz);
    bz_y = linspace(-bz_size(2)/2, bz_size(2)/2, n_y_bz);

    n_x_gz = round(gz_size(1) / itv_mic(1)) + 1;
    n_y_gz = round(gz_size(2) / itv_mic(2)) + 1;
    gz_x = linspace(-gz_size(1)/2, gz_size(1)/2, n_x_gz);
    gz_y = linspace(-gz_size(2)/2, gz_size(2)/2, n_y_gz);

    n_x_dz = round(dz_size(1) / itv_mic(1)) + 1;
    n_y_dz = round(dz_size(2) / itv_mic(2)) + 1;
    dz_x = linspace(-dz_size(1)/2, dz_size(1)/2, n_x_dz);
    dz_y = linspace(-dz_size(2)/2, dz_size(2)/2, n_y_dz);

    % -----------------------
    % 各ゾーンのシフト後中心位置
    % BZを左、GZを中央、DZを右に配置
    % -----------------------
    bz_center = [-dist_zone/2, y_center];
    gz_center = [ 0.0,         y_center];
    dz_center = [ dist_zone/2, y_center];

    % -----------------------
    % 点格納（各ゾーンごとに独立して生成）
    % -----------------------
    
    % 1. Bright Zone (BZ) の生成
    pos_bz = zeros(n_x_bz * n_y_bz, 2);
    for x_idx = 1:n_x_bz
        for y_idx = 1:n_y_bz
            n = (x_idx - 1) * n_y_bz + y_idx;
            pos_bz(n, :) = [bz_x(x_idx) + bz_center(1), bz_y(y_idx) + bz_center(2)];
        end
    end

    % 2. Gradation Zone (GZ) の生成
    pos_gz = zeros(n_x_gz * n_y_gz, 2);
    for x_idx = 1:n_x_gz
        for y_idx = 1:n_y_gz
            n = (x_idx - 1) * n_y_gz + y_idx;
            pos_gz(n, :) = [gz_x(x_idx) + gz_center(1), gz_y(y_idx) + gz_center(2)];
        end
    end

    % 3. Dark Zone (DZ) の生成 (L字配置)
    pos_dz_list = [];
    for x_idx = 1:n_x_dz
        for y_idx = 1:n_y_dz
            if x_idx == 1 || y_idx == 1
                pt_dz = [dz_x(x_idx) + dz_center(1), dz_y(y_idx) + dz_center(2)];
                pos_dz_list = [pos_dz_list; pt_dz];
            end
        end
    end
    pos_dz = pos_dz_list;
    
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