function [pos_sp, pos_mic, num_mic, num_bz, num_gz] = pos_sp_mic(num_sp, y_center, dist_zone, bz_size, gz_size, dz_size, itv_mic, room_size, pltPos, layout_mode, itv_sp)

    if nargin < 10 || isempty(layout_mode), layout_mode = "zones"; end
    if nargin < 11 || isempty(itv_sp), itv_sp = 0.085; end
    if ~any(strcmp(layout_mode, {"zones", "referenceL"}))
        error('pos_sp_mic:invalidLayout', 'layout_modeは"zones"または"referenceL"を指定してください。');
    end
    
    % スピーカーの配置形状を切り替えるフラグ（false: 直線状 / true: 円弧状）
    isArc = false; 

    %% ---------------------------------------------------------------------
    %% 制御点の座標計算
    %% ---------------------------------------------------------------------
    if strcmp(layout_mode, "referenceL")
        % placement.pdf と同じ配置: 再生点1点、L字抑圧点、32台×0.05m。
        pos_bz = [-1.0, 1.0];
        x_leg = (0:0.04:1.0)';
        pos_dz = [x_leg, 0.10 * ones(size(x_leg))];
        y_leg = (0.14:0.04:1.60)';
        pos_dz = [pos_dz; zeros(size(y_leg)), y_leg];
        pos_gz = zeros(0, 2);
        num_bz = size(pos_bz, 1);
        num_gz = 0;
    else
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

    % GZ幅(などゾーン幅)をitv_mic(1)に対して狭くしすぎると、x方向の
    % 格子点数が1点まで減り、filter_pm.m 内の正規化位置t計算が0/0=NaNに
    % なって全チャンネルが壊れる。エラーメッセージなしで壊れると原因が
    % わかりにくいため、ここで事前に検出する。
    % 2点未満は即エラー、5点未満(目安)は「遷移形状を表現するには粗い」
    % 警告のみ出して処理は続行する。
        min_pts_hard = 2;
        min_pts_soft = 5;
        zone_names = {'BZ', 'GZ', 'DZ'};
        n_x_list   = [n_x_bz, n_x_gz, n_x_dz];
        for zi = 1:3
            if n_x_list(zi) < min_pts_hard
            error('pos_sp_mic:degenerateZone', ...
                '%s のx方向格子点数が%dしかありません。zoneの幅をitv_mic(1)に対して広げるか、itv_mic(1)を細かくしてください。', ...
                zone_names{zi}, n_x_list(zi));
            elseif n_x_list(zi) < min_pts_soft
            warning('pos_sp_mic:coarseZone', ...
                '%s のx方向格子点数が%d点しかありません(目安: %d点以上)。遷移形状を細かく表現できていない可能性があります。', ...
                zone_names{zi}, n_x_list(zi), min_pts_soft);
            end
        end

    % -----------------------
    % 各ゾーンのシフト後中心位置
    % BZを左、GZを中央、DZを右に配置。
    % dist_zoneでBZ-DZ間の中心間距離を制御する
    % -----------------------
        bz_center = [-dist_zone/2, y_center];
        gz_center = [ 0.0,         y_center];
        dz_center = [ dist_zone/2, y_center];

    % -----------------------
    % 点格納（各ゾーンをそれぞれの格子サイズで独立に生成）
    % -----------------------
        pos_bz = zeros(n_x_bz*n_y_bz, 2);
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

        % ゾーン境界(BZ-GZ, GZ-DZ)では、隣り合うゾーンの端の制御点が同じ座標に重なる。
        % 同じ点にBZ側とGZ側など別々の目標を重ねて与えると目標が食い違うため、
        % 境界の点はGZ所属で1回だけ使い、BZ/DZ側の重複点を取り除く。
        % (既定の配置では制御点が 1806点 -> 1778点 になる)
        tol_dup = 1e-9;
        keep_bz = true(size(pos_bz, 1), 1);
        for i = 1:size(pos_bz, 1)
            keep_bz(i) = ~any(abs(pos_gz(:,1) - pos_bz(i,1)) < tol_dup & abs(pos_gz(:,2) - pos_bz(i,2)) < tol_dup);
        end
        pos_bz = pos_bz(keep_bz, :);
        keep_dz = true(size(pos_dz, 1), 1);
        for i = 1:size(pos_dz, 1)
            keep_dz(i) = ~any(abs(pos_gz(:,1) - pos_dz(i,1)) < tol_dup & abs(pos_gz(:,2) - pos_dz(i,2)) < tol_dup);
        end
        pos_dz = pos_dz(keep_dz, :);

        num_bz = size(pos_bz, 1);
        num_gz = size(pos_gz, 1);
    end
    pos_mic = [pos_bz; pos_gz; pos_dz];
    num_mic = size(pos_mic, 1);

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
        set(gcf, 'Position', [100, 100, 900, 700]);

        if strcmp(layout_mode, "referenceL")
            h_sp = scatter(pos_sp(:,1), pos_sp(:,2), 42, 'k', '^'); hold on;
            h_bz = scatter(pos_bz(:,1), pos_bz(:,2), 48, 'r', 'filled');
            h_gz = [];
            h_dz = scatter(pos_dz(:,1), pos_dz(:,2), 18, [0.10, 0.60, 0.55], 'filled');
        else
            h_sp = scatter(pos_sp(:,1), pos_sp(:,2), 24, 'k', '^', 'filled'); hold on;
            h_bz = scatter(pos_bz(:,1), pos_bz(:,2), 12, [0.25, 0.60, 0.75], 'filled');
            if ~isempty(pos_gz)
                h_gz = scatter(pos_gz(:,1), pos_gz(:,2), 8, [0.20, 0.60, 0.35], 'filled');
            else
                h_gz = [];
            end
            h_dz = scatter(pos_dz(:,1), pos_dz(:,2), 8, [0.45, 0.45, 0.45], 'filled');
        end

        daspect([1 1 1]);
        xlim([room_size(1), room_size(2)])
        ylim([room_size(3), room_size(4)])
        grid on;

        xlabel("x[m]"); ylabel("y[m]");
        set(gca, 'Position', [0.08, 0.12, 0.63, 0.80]);
        if strcmp(layout_mode, "referenceL")
            legend([h_sp, h_bz, h_dz], {"Speaker", "Bright point", "Dark control points (L)"}, ...
                'Location', 'eastoutside');
            title(sprintf("Reference L layout: sp=%d, control points=%d", num_sp, num_mic));
            filename = sprintf("plc_referenceL_sp_%d_mic_%d.png", num_sp, num_mic);
        else
            legend([h_sp, h_bz, h_gz, h_dz], {"Speaker", "Bright Zone", "Gradation Zone", "Dark Zone"}, ...
                'Location', 'eastoutside');
            title(sprintf("sp=%d, mic=%d, height=%.2f", num_sp, num_mic, y_center));
            filename = sprintf("plc_sp_%d_mic_%d_zone-h_%.2fm_zone-dis_%.2fm.png", ...
                num_sp, num_mic, y_center, dist_zone);
        end
        set(gca, 'fontsize', 15)
        saveas(gcf, filename, 'png');
    end
end