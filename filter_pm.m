function drv_ls = filter_pm(mic_geo, G, f, ang_wave, amp_src, Nsrc, c, num_bz, num_gz, floor_dB)

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
        % 2. Gradation Zone (GZ) の目標音圧と重み
        %--------------------------------------------------
        gz_idx_start = num_bz + 1;
        gz_idx_end = num_bz + num_gz;
        
        min_x_gz = min(mic_geo(gz_idx_start:gz_idx_end, 1));
        max_x_gz = max(mic_geo(gz_idx_start:gz_idx_end, 1));

        % GZ幅が実質0(x方向の制御点が1列だけ等)だと、下のtの計算が
        % 0/0 = NaN になり、全スピーカーの駆動信号がエラーなくNaN化して
        % しまう。「GZ幅を狭める」検討をする際に踏みやすい落とし穴なので、
        % ここで明示的に検出して止める。
        if (max_x_gz - min_x_gz) < eps
            error('filter_pm:degenerateGZ', ...
                'GZのx方向の幅が実質0です。gz_size(1)がitv_mic(1)に対して小さすぎる可能性があります。pos_sp_mic.m側の設定を見直してください。');
        end

        % GZ内で目標(dB)を滑らかに遷移させる。
        %   floor_dB : GZ→DZ境界で到達させる相対音圧レベル[dB]。
        %              main.m で δ_JND, τ, v_walk と現在のGZ幅から算出され、
        %              引数として渡されたものをそのまま使う(このファイルは
        %              floor_dBがどう決まったかを一切知らない)。
        %
        % 境界(t=0, t=1)で勾配がゼロになるスムーズステップ関数 s(t) を使い、
        % BZ(勾配0の一定値)・DZ(勾配0の一定値=0)との接続点にキンク
        % (勾配の不連続)が生じないようにする。
        % 旧実装(振幅を指数減衰=dBで直線的に減衰)は、BZ境界で勾配が
        % 0 → 約-87dB/GZ幅へ不連続にジャンプしており、これがPM解が
        % 名目上の境界より手前からなだらかに音圧を落とし始める一因になって
        % いたと考えられる。また目標がGZ→DZ境界で-87dBという実現困難な
        % 深さを要求していた点も、floor_dBを現実的な値にすることで緩和する。

        for i = gz_idx_start:gz_idx_end
            x_m = mic_geo(i,1);
            y_m = mic_geo(i,2);

            % 0 (BZ側) ～ 1 (DZ側) に正規化した位置パラメータ t
            t = (x_m - min_x_gz) / (max_x_gz - min_x_gz);

            % 両端(t=0, t=1)で微分ゼロのスムーズステップ (Hermite smoothstep)
            s = 3*t.^2 - 2*t.^3;

            % 1. 目標音圧をdB領域で滑らかにfloor_dBまで遷移させる
            amp_g = amp_src * 10^(floor_dB * s / 20);
            p_des(i) = amp_g * exp(1i * (2*pi*f(kk)/c) * (x_m*cos(ang_wave) + y_m*sin(ang_wave)));

            % 2. 重みも同じsを使い対数スケールで単調増加: 1.0 -> 100.0
            %    DZ側の重み(100.0)と連続的に接続する
            log_w = log10(1.0) + s * (log10(100.0) - log10(1.0));
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