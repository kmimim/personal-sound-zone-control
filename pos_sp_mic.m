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
    % -----------------------
    bz_center = [-dist_zone/2, y_center];
    gz_center = [0, y_center];
    dz_center = [ dist_zone/2,  y_center];

    % -----------------------
    % 点格納（配置ロジックはそのまま維持）
    % -----------------------
    pos_bz = zeros(n_x_bz * n_y_bz, 2);
    pos_dz = zeros(n_x_dz * n_y_dz, 2);

    n = 0;
    for x_idx = 1:length(bz_x)
        for y_idx = 1:length(bz_y)
            n = n + 1;
            pos_bz(n,:) = [bz_x(x_idx) + bz_center(1), bz_y(y_idx) + bz_center(2)];
        end
    end

    pos_gz = zeros(n_x_gz*n_y_gz, 2);
    n = 0;
    for x_idx = 1:length(gz_x)
        for y_idx = 1:length(gz_y)
            n = n + 1;
            pos_gz(n,:) = [gz_x(x_idx) + gz_center(1), gz_y(y_idx) + gz_center(2)];
        end
    end

    pos_dz = zeros(n_x_dz*n_y_dz, 2);
    n = 0;
    for x_idx = 1:length(dz_x)
        for y_idx = 1:length(dz_y)
            n = n + 1;
            pos_dz(n,:) = [dz_x(x_idx) + dz_center(1), dz_y(y_idx) + dz_center(2)];
        end
    end

    % BZ, GZ, DZを結合し、総マイク数を算出
    pos_mic = [pos_bz; pos_dz];
    num_mic = size(pos_mic, 1);
    num_bz = size(pos_bz, 1);
    num_gz = 0; % GZは未使用のため0に設定

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
        figure;
        hold on; % 【修正】最背面にpatchを描画するため、最初にhold onを設定
        
        % 各ゾーンのx方向の境界を取得（patch用）
        bz_x_min = min(pos_bz(:,1)); bz_x_max = max(pos_bz(:,1));
        dz_x_min = min(pos_dz(:,1)); dz_x_max = max(pos_dz(:,1));
        
        % Y軸の塗りつぶし範囲（マイクの上下に適度な余白を持たせる）
        y_min_plot = min(pos_mic(:,2)) - 0.2;
        y_max_plot = max(pos_mic(:,2)) + 0.2;
        
        % 【修正】1つ目のコードを参考に、各領域をpatchで薄く塗りつぶす
        % （凡例の重複を防ぐため 'HandleVisibility', 'off' を設定）
        patch([bz_x_min bz_x_max bz_x_max bz_x_min], [y_min_plot y_min_plot y_max_plot y_max_plot], ...
              [0.25, 0.60, 0.75], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        patch([dz_x_min dz_x_max dz_x_max dz_x_min], [y_min_plot y_min_plot y_max_plot y_max_plot], ...
              [0.60, 0.60, 0.60], 'FaceAlpha', 0.10, 'EdgeColor', 'none', 'HandleVisibility', 'off');

        % スピーカーと各ゾーンのマイク配置を色分けして散布図で描画（ハンドルを取得）
        h_sp = scatter(pos_sp(:,1), pos_sp(:,2), 15, 'k', '^', 'filled');        
        h_bz = scatter(pos_bz(:,1), pos_bz(:,2), 3, [0.25, 0.60, 0.75], 'filled'); % BZ: シアン系
        h_dz = scatter(pos_dz(:,1), pos_dz(:,2), 3, [0.60, 0.60, 0.60], 'filled'); % DZ: グレー系

        daspect([1 1 1]);
        xlim([room_size(1), room_size(2)]);
        ylim([room_size(3), room_size(4)]);
        grid on;
        
        xlabel("x[m]"); ylabel("y[m]");
        
        % 取得したハンドルを用いて凡例をすっきりと整理
        legend([h_sp, h_bz, h_dz], {"Speaker", "Bright Zone", "Dark Zone"});

        % ファイル名とタイトルに dist_zone (dis) を正しく反映
        filename = sprintf("plc_sp_%d_mic_%d_zone-h_%.2fm_zone-dis_%.2fm.png", ...
                            num_sp, num_mic, y_center, dist_zone);
        title(sprintf("sp=%d, mic=%d, height=%.2f, dis=%.2f", num_sp, num_mic, y_center, dist_zone));
        
        set(gca, 'fontsize', 15);
        saveas(gcf, filename, 'png');
    end
end