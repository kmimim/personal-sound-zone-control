function drv_ls = filter_pm(mic_geo, G, f, ang_wave, amp_src, Nsrc, c, num_bz, num_gz)

    % この実装は p_des(i) への線形インデックス代入をしているため、
    % Nsrc > 1 (複数の目標音源/波を同時に与える場合) では正しく動作しない。
    % 誤った結果やエラーを黙って出すのを防ぐため、ここで明示的にチェックする。
    if Nsrc ~= 1
        error('filter_pm:unsupportedNsrc', ...
            'filter_pm は現在 Nsrc = 1 (単一の目標音場) のみに対応しています。');
    end

    % Gのサイズ取得
    % n_mic : 制御点(マイク)数
    % n_sp  : スピーカ数
    [n_mic, n_sp, ~] = size(G); % size(G,1:2) は環境によって非対応の場合があるため書き換え

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
        % 最大固有値の10^-7倍
        % 行列が悪条件になるのを防ぐ
        % g'*g はスピーカ数×スピーカ数の小さな密行列なので、
        % 反復法のeigsではなくeigで直接計算する（より高速・確実）。
        % 丸め誤差による非エルミート性をわずかに除去してから固有値を取る。
        %--------------------------------------------------
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
        % 3. Dark Zone (DZ) の目標音圧と重み
        %--------------------------------------------------
        dz_idx_start = num_bz + 1;
        for i = dz_idx_start:n_mic
            p_des(i) = 0;
            w_vec(i) = 100.0;
        end

        %--------------------------------------------------
        % 重み付き最小二乗最適化 (Weighted PM)
        % d = (GᴴWG + λI)^(-1) GᴴW p_des
        %
        % W = diag(w_vec) をそのまま作ると n_mic×n_mic (数千×数千) の
        % 密行列になり無駄が大きいため、要素積で数学的に等価な計算を行う。
        %--------------------------------------------------
        Gw = g .* w_vec;
        drv_single = (g' * Gw + reg_para * eye(n_sp)) \ (g' * (w_vec .* p_des));

        drv_ls(:,kk) = drv_single;
    end
end