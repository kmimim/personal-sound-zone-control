function drv_ls = filter_pm(mic_geo, G, f, ang_wave, amp_src, Nsrc, c, num_bz, num_gz)

    % この実装は p_des(i) への線形インデックス代入をしているため、
    % Nsrc > 1 (複数の目標音源/波を同時に与える場合) では正しく動作しない。
    % 誤った結果やエラーを黙って出すのを防ぐため、ここで明示的にチェックする。
    if Nsrc ~= 1
        error('filter_pm:unsupportedNsrc', ...
            'filter_pm は現在 Nsrc = 1 (単一の目標音場) のみに対応しています。');
    end

    % Gのサイズ取得 (2次元でも3次元でも f_len を自動取得)
    % n_mic : 制御点(マイク)数
    % n_sp  : スピーカ数
    % f_len : 周波数ビン数
    [n_mic, n_sp, f_len] = size(G);

    % 出力用行列
    drv_ls = zeros(n_sp, f_len);

    for kk = 1:f_len
        g = G(:,:,kk);

        % 正則化パラメータの計算
        % 最大固有値の10^-7倍（行列が悪条件になるのを防ぐ）
        gg = g' * g;
        gg = (gg + gg') / 2;
        reg_para = 10^(-7) * max(real(eig(gg)));

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
        
        min_x_gz = min(mic_geo(gz_idx_start:gz_idx_end, 1));
        max_x_gz = max(mic_geo(gz_idx_start:gz_idx_end, 1));

        % 減衰の急峻さを制御するパラメータ
        alpha = 5.0; 

        for i = gz_idx_start:gz_idx_end
            x_m = mic_geo(i,1);
            y_m = mic_geo(i,2);

            % 0 (BZ側) ～ 1 (DZ側) に正規化した位置パラメータ t
            t = (x_m - min_x_gz) / (max_x_gz - min_x_gz);

            % 1. 目標音圧をGZ全体で指数的に減衰
            amp_g = amp_src * exp(-2 * alpha * t);
            p_des(i) = amp_g * exp(1i * (2*pi*f(kk)/c) * (x_m*cos(ang_wave) + y_m*sin(ang_wave)));

            % 2. 重みをGZ全体で対数スケールで単調増加: 1.0 -> 100.0
            log_w = log10(1.0) + t * (log10(100.0) - log10(1.0));
            w_vec(i) = 10^(log_w);
        end

        %--------------------------------------------------
        % 3. Dark Zone (DZ) の目標音圧と重み
        %--------------------------------------------------
        dz_idx_start = num_bz + num_gz + 1;
        for i = dz_idx_start:n_mic
            p_des(i) = 0;
            w_vec(i) = 100.0;
        end

        %--------------------------------------------------
        % 重み付き最小二乗最適化 (Weighted PM)
        %--------------------------------------------------
        Gw = g .* w_vec;
        drv_single = (g' * Gw + reg_para * eye(n_sp)) \ (g' * (w_vec .* p_des));

        drv_ls(:,kk) = drv_single;
    end
end