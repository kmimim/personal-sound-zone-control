% スピーカーとマイクの配置座標を計算する関数

function [pos_sp, pos_mic, num_mic, num_bz, num_dz] = pos_sp_mic(num_sp, y_center, dist_zone, bz_size, dz_size, itv_mic, room_size, pltPos)

    % スピーカーの配置形状を切り替えるフラグ（false: 直線状 / true: 円弧状）
    isArc = false;

    %% ---------------------------------------------------------------------
    %% ブライトゾーン（BZ）を格子状に配置
    %% ---------------------------------------------------------------------
    % bz_size: [幅_x, 高さ_y]
    n_bx = floor(bz_size(1) / itv_mic(1)) + 1;
    n_by = floor(bz_size(2) / itv_mic(2)) + 1;
    bx = linspace(-bz_size(1)/2, bz_size(1)/2, n_bx);
    by = linspace(y_center - bz_size(2)/2, y_center + bz_size(2)/2, n_by);

    % 格子点列を作成（BZは左側に配置：x を -dist_zone/2 だけシフト）
    [BX, BY] = meshgrid(bx, by);
    pos_bz = [BX(:), BY(:)];
    pos_bz(:,1) = pos_bz(:,1) - dist_zone/2; % BZ の中心を左にシフト
    num_bz = size(pos_bz, 1);

    %% ---------------------------------------------------------------------
    %% ダークゾーン（DZ）を L 字に配置（dz_size の範囲全部を沿って配置）
    %% ---------------------------------------------------------------------
    dz_w = dz_size(1);
    dz_h = dz_size(2);

    dz_left = -dz_w/2;
    dz_top  = y_center + dz_h/2;
    dz_bottom = y_center - dz_h/2;

    n_dy = floor(dz_size(2) / itv_mic(2)) + 1;
    n_dx = floor(dz_size(1) / itv_mic(1)) + 1;
    dz_y = linspace(dz_top, dz_bottom, n_dy);
    dz_x = linspace(dz_left, dz_left + dz_w, n_dx);

    % L字の角の重複を避けるため、底辺は左下角を除いて追加
    pos_dz_vert = [repmat(dz_left + dist_zone/2, numel(dz_y), 1), dz_y(:)];
    if numel(dz_x) > 1
        pos_dz_horz = [dz_x(2:end)' + dist_zone/2, repmat(dz_bottom, numel(dz_x)-1, 1)];
    else
        pos_dz_horz = zeros(0,2);
    end

    pos_dz = [pos_dz_vert; pos_dz_horz];
    num_dz = size(pos_dz, 1);

    %% ---------------------------------------------------------------------
    %% マイク位置を結合して出力
    %% ---------------------------------------------------------------------
    pos_mic = [pos_bz; pos_dz];
    num_mic = size(pos_mic, 1);

    %% ---------------------------------------------------------------------
    %% スピーカーアレイ（音源）の座標計算
    %% ---------------------------------------------------------------------
    if isArc
        itv_ang = pi/40;  % スピーカー間の角度間隔 [rad]
        ang_sp = itv_ang * ((0.5 - num_sp/2) : (num_sp/2 - 0.5));
        x_sp = y_center * sin(ang_sp);
        y_sp = y_center - y_center * cos(ang_sp);
        pos_sp = [x_sp', y_sp'];
    else
        itv_sp = 0.085;   % スピーカー間隔 [m]
        x_sp_1 = -(num_sp-1)/2 * itv_sp;
        y_sp_1 = 0;
        pos_sp = zeros(num_sp, 2);
        pos_sp(1,:) = [x_sp_1, y_sp_1];
        pos_sp(2:end, 1) = x_sp_1 + (1:num_sp-1) * itv_sp;
    end

    %% ---------------------------------------------------------------------
    %% 配置図の描画と画像保存（任意）
    %% ---------------------------------------------------------------------
    if pltPos
        figure
        scatter(pos_sp(:,1), pos_sp(:,2), 40, 'k', '^', 'filled'); hold on;
        scatter(pos_mic(:,1), pos_mic(:,2), 10, 'filled');
        daspect([1 1 1])
        xlim([room_size(1), room_size(2)])
        ylim([room_size(3), room_size(4)])
        grid on;
        xlabel("x[m]"); ylabel("y[m]");
        legend({"sp", "mic"});
        filename = sprintf("plc_sp_%d_mic_%d_zone-h_%.2fm_zone-dis_%.2fm.png", num_sp, num_mic, y_center, dist_zone);
        title(sprintf("sp=%d, mic=%d, height=%.2f, dis=%.2f", num_sp, num_mic, y_center, dist_zone));
        set(gca, 'fontsize', 15)
        saveas(gcf, filename, 'png');
    end
end