function drv_ls = filter_pm(mic_geo, G, f, ang_wave, amp_src, Nsrc, c, num_bz, num_gz)

    % Gのサイズ取得
    s = size(G);
    n_mic = s(1);
    n_sp  = s(2);

    % 周波数ビン数
    if numel(s) >= 3
        f_len = s(3);
    else
        f_len = 1;
    end

    % 出力用行列
    drv_ls = zeros(n_sp, f_len);

    for kk = 1:f_len
        g = G(:,:,kk);

        % 正則化パラメータの計算
        %
        % 最大固有値の10^-5倍
        % 行列が悪条件になるのを防ぐ
        %--------------------------------------------------
        reg_para = 10^(-7) * eigs((g' * g), 1);

        p_des = zeros(n_mic, Nsrc);
        w_vec = ones(n_mic, 1); % 重みベクトルの初期化

        %--------------------------------------------------
        % 1. Bright Zone (BZ) の目標音圧と重み
        %--------------------------------------------------
        for i = 1:num_bz
            x_m = mic_geo(i,1);
            y_m = mic_geo(i,2);
            p_des(i) = amp_src * exp(1i * (2*pi*f(kk)/c) * (x_m*cos(ang_wave) + y_m*sin(ang_wave)));
            w_vec(i) = 1.0;
        end

        %--------------------------------------------------
        % 2. Gradation Zone (GZ) の目標音圧と重み
        %--------------------------------------------------
        gz_idx_start = num_bz + 1;
        gz_idx_end = num_bz + num_gz;
        
        % GZのx座標の範囲を取得し、中間点を算出
        min_x_gz = min(mic_geo(gz_idx_start:gz_idx_end, 1));
        max_x_gz = max(mic_geo(gz_idx_start:gz_idx_end, 1));
        mid_x_gz = (min_x_gz + max_x_gz) / 2;

        for i = gz_idx_start:gz_idx_end
            x_m = mic_geo(i,1);
            y_m = mic_geo(i,2);

            if x_m <= mid_x_gz
                % GZ前半: 重み 1.0 -> 0.01 / 振幅 1.0 -> 0.0
                t = (x_m - min_x_gz) / (mid_x_gz - min_x_gz);
                w_vec(i) = 1.0 - t * 0.99;
                amp_g = amp_src * (1.0 - t);
                p_des(i) = amp_g * exp(1i * (2*pi*f(kk)/c) * (x_m*cos(ang_wave) + y_m*sin(ang_wave)));
            else
                % GZ後半: 無音、重み 0.01 固定
                w_vec(i) = 0.1;
                p_des(i) = 0;
            end
        end

        %--------------------------------------------------
        % 3. Dark Zone (DZ) の目標音圧と重み
        %--------------------------------------------------
        dz_idx_start = num_bz + num_gz + 1;
        for i = dz_idx_start:n_mic
            p_des(i) = 0;
            w_vec(i) = 100.0;
        end

        % 重み行列 W (対角行列)
        W = diag(w_vec);

        %--------------------------------------------------
        % 重み付き最小二乗最適化 (Weighted PM)
        % d = (GᴴWG + λI)^(-1) GᴴW p_des
        %--------------------------------------------------
        drv_single = (g' * W * g + reg_para * eye(n_sp)) \ (g' * W * p_des);

        drv_ls(:,kk) = drv_single;
    end
end