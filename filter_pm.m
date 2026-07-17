function drv_ls = filter_pm(mic_geo, G, f, ang_wave, amp_src, Nsrc, c, num_bz, num_gz)

    % Gのサイズ取得
    % n_mic : 制御点(マイク)数
    % n_sp  : スピーカ数
    [n_mic, n_sp] = size(G,1:2);

    % 周波数ビン数
    f_len = length(f);

    % 出力用行列
    % 行：スピーカ
    % 列：周波数
    drv_ls = zeros(n_sp, f_len);

    for kk = 1:f_len
        g = G(:,:,kk);

        % 正則化パラメータの計算
        %
        % 最大固有値の10^-5倍
        % 行列が悪条件になるのを防ぐ
        %--------------------------------------------------
        reg_para = 10^(-5) * eigs((g' * g), 1);

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
        % 3. Dark Zone (DZ) の目標音圧と重み
        %--------------------------------------------------
        dz_idx_start = num_bz + 1;
        for i = dz_idx_start:n_mic
            p_des(i) = 0;
            w_vec(i) = 1.0;
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