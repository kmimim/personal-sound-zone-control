function drv_ls = filter_pm(mic_geo, G, f, ang_wave, amp_src, Nsrc, c, num_bz, num_gz, tau, floor_dB, dz_mode)

    if nargin < 10 || isempty(tau), tau = 0; end
    % Defaults preserve compatibility with calls using the original signature.
    if nargin < 11 || isempty(floor_dB), floor_dB = -20.0; end
    if nargin < 12 || isempty(dz_mode), dz_mode = "zero"; end
    if ~isscalar(floor_dB) || ~isfinite(floor_dB) || floor_dB > 0
        error('filter_pm:invalidFloorDb', ...
            'floor_dBには0以下の有限なスカラー値を指定してください。');
    end
    if ~any(strcmp(dz_mode, {"zero", "floor"}))
        error('filter_pm:invalidDzMode', ...
            'dz_modeには"zero"または"floor"を指定してください。');
    end

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

    if size(mic_geo, 1) ~= n_mic || size(mic_geo, 2) ~= 2
        error('filter_pm:geometrySizeMismatch', ...
            'mic_geoの行数はGのマイク数と一致し、2列(x,y)である必要があります。');
    end
    if num_bz < 1 || num_gz < 0 || num_bz + num_gz > n_mic
        error('filter_pm:invalidZoneCounts', ...
            'num_bzとnum_gzが制御点数と整合していません。');
    end
    if size(G, 3) ~= numel(f) || isempty(f) || any(~isfinite(f)) || any(f <= 0)
        error('filter_pm:invalidFrequencies', ...
            'Gの周波数次元とfの要素数を一致させ、fには有限の正周波数を指定してください。');
    end

    % 周波数ビン数
    f_len = length(f);

    % 出力用行列
    % 行：スピーカ
    % 列：周波数
    drv_ls = zeros(n_sp, f_len);

    for kk = 1:f_len
        g = G(:,:,kk);
        delay_phase = exp(-1i * 2*pi*f(kk) * tau);

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
            p_des(i) = amp_src * exp(1i * (2*pi*f(kk)/c) * (x_m*cos(ang_wave) + y_m*sin(ang_wave))) * delay_phase;
            w_vec(i) = 1.0;
        end

        %--------------------------------------------------
        % 2. Gradation Zone (GZ) の目標音圧と重み
        %--------------------------------------------------
        if num_gz > 0
            gz_idx_start = num_bz + 1;
            gz_idx_end = num_bz + num_gz;

            min_x_gz = min(mic_geo(gz_idx_start:gz_idx_end, 1));
            max_x_gz = max(mic_geo(gz_idx_start:gz_idx_end, 1));

            % GZ幅が実質0(x方向の制御点が1列だけ等)だと、下のtの計算が
            % 0/0 = NaN になるため、ここで明示的に検出して止める。
            if (max_x_gz - min_x_gz) < eps
                error('filter_pm:degenerateGZ', ...
                    'GZのx方向の幅が実質0です。gz_size(1)がitv_mic(1)に対して小さすぎる可能性があります。pos_sp_mic.m側の設定を見直してください。');
            end

            for i = gz_idx_start:gz_idx_end
                x_m = mic_geo(i,1);
                y_m = mic_geo(i,2);

                % 0 (BZ側) ～ 1 (DZ側) に正規化した位置パラメータ t
                t = (x_m - min_x_gz) / (max_x_gz - min_x_gz);

                % 両端(t=0, t=1)で微分ゼロのスムーズステップ
                s = 3*t.^2 - 2*t.^3;

                % 目標音圧をdB領域でfloor_dBまで遷移させる
                amp_g = amp_src * 10^(floor_dB * s / 20);
                p_des(i) = amp_g * exp(1i * (2*pi*f(kk)/c) * (x_m*cos(ang_wave) + y_m*sin(ang_wave))) * delay_phase;

                % 重みを対数スケールで単調増加させる: 1.0 -> 100.0
                log_w = s * log10(100.0);
                w_vec(i) = 10^(log_w);
            end
        end % if num_gz > 0

        %--------------------------------------------------
        % 3. Dark Zone (DZ) の目標音圧と重み
        %--------------------------------------------------
        dz_idx_start = num_bz + num_gz + 1;
        for i = dz_idx_start:n_mic
            if strcmp(dz_mode, "floor")
                % GZ終端と同じ目標振幅・平面波位相をDZに与える。
                x_m = mic_geo(i,1);
                y_m = mic_geo(i,2);
                amp_d = amp_src * 10^(floor_dB / 20);
                p_des(i) = amp_d * exp(1i * (2*pi*f(kk)/c) * ...
                    (x_m*cos(ang_wave) + y_m*sin(ang_wave))) * delay_phase;
            else
                % zero: DZ目標を0振幅にする。
                p_des(i) = 0;
            end
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
