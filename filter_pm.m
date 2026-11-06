function drv_ls = filter_pm(mic_geo, G, f, ang_wave, amp_src, Nsrc, c, num_bz, num_gz, tau, floor_dB, dz_mode, reverse_gz, reg_rel)
    % floor_dB: GZ終端（floorモードではDZも）の目標 [dB]
    % dz_mode: "zero"（DZ目標=0）/ "floor"（DZ目標=GZ終端と同じ値）
    % reverse_gz: true でGZの遷移方向を反転（BZが右側の二重音声の音B）
    % reg_rel: 正則化の強さ（G'G の最大固有値に対する比）。既定 1e-7
    % 時間規約は e^{+iωt}。+y方向に進む平面波は e^{-ik(...)}、遅延は e^{-iωτ}

    if nargin < 10 || isempty(tau), tau = 0; end
    if nargin < 11 || isempty(floor_dB), floor_dB = -20.0; end
    if nargin < 12 || isempty(dz_mode), dz_mode = "zero"; end
    if nargin < 13 || isempty(reverse_gz), reverse_gz = false; end
    if nargin < 14 || isempty(reg_rel), reg_rel = 1e-7; end
    if ~isscalar(floor_dB) || ~isfinite(floor_dB) || floor_dB > 0
        error('filter_pm:invalidFloorDb', ...
            'floor_dBには0以下の有限なスカラー値を指定してください。');
    end
    if ~any(strcmp(dz_mode, {"zero", "floor"}))
        error('filter_pm:invalidDzMode', ...
            'dz_modeには"zero"または"floor"を指定してください。');
    end

    if Nsrc ~= 1
        error('filter_pm:unsupportedNsrc', ...
            'filter_pm は現在 Nsrc = 1 (単一の目標音場) のみに対応しています。');
    end

    [n_mic, n_sp, ~] = size(G);  % size(G,1:2) は環境によって非対応の場合があるため書き換え

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

    f_len = length(f);

    drv_ls = zeros(n_sp, f_len);

    for kk = 1:f_len
        g = G(:,:,kk);
        delay_phase = exp(-1i * 2*pi*f(kk) * tau);

        % 正則化: λ = reg_rel × (G'G の最大固有値)
        gg = g' * g;
        gg = (gg + gg') / 2;
        reg_para = reg_rel * max(real(eig(gg)));

        p_des = zeros(n_mic, Nsrc);
        w_vec = ones(n_mic, 1);  % 重みベクトルの初期化

        for i = 1:num_bz
            x_m = mic_geo(i,1);
            y_m = mic_geo(i,2);
            p_des(i) = amp_src * exp(-1i * (2*pi*f(kk)/c) * (x_m*cos(ang_wave) + y_m*sin(ang_wave))) * delay_phase;
            w_vec(i) = 1.0;
        end

        if num_gz > 0
            gz_idx_start = num_bz + 1;
            gz_idx_end = num_bz + num_gz;

            min_x_gz = min(mic_geo(gz_idx_start:gz_idx_end, 1));
            max_x_gz = max(mic_geo(gz_idx_start:gz_idx_end, 1));

            if (max_x_gz - min_x_gz) < eps
                error('filter_pm:degenerateGZ', ...
                    'GZのx方向の幅が実質0です。gz_size(1)がitv_mic(1)に対して小さすぎる可能性があります。pos_sp_mic.m側の設定を見直してください。');
            end

            for i = gz_idx_start:gz_idx_end
                x_m = mic_geo(i,1);
                y_m = mic_geo(i,2);

                t = (x_m - min_x_gz) / (max_x_gz - min_x_gz);  % BZ側 0 → DZ側 1
                if reverse_gz, t = 1 - t; end  % BZが右側のとき、遷移方向を反転

                s = 3*t.^2 - 2*t.^3;  % 両端で傾き0

                amp_g = amp_src * 10^(floor_dB * s / 20);
                p_des(i) = amp_g * exp(-1i * (2*pi*f(kk)/c) * (x_m*cos(ang_wave) + y_m*sin(ang_wave))) * delay_phase;

                log_w = s * log10(100.0);  % 重み 1 → 100
                w_vec(i) = 10^(log_w);
            end
        end  % if num_gz > 0

        dz_idx_start = num_bz + num_gz + 1;
        for i = dz_idx_start:n_mic
            if strcmp(dz_mode, "floor")
                x_m = mic_geo(i,1);
                y_m = mic_geo(i,2);
                amp_d = amp_src * 10^(floor_dB / 20);
                p_des(i) = amp_d * exp(-1i * (2*pi*f(kk)/c) * ...
                    (x_m*cos(ang_wave) + y_m*sin(ang_wave))) * delay_phase;
            else
                p_des(i) = 0;
            end
            w_vec(i) = 100.0;
        end

        % d = (G'WG + λI)^-1 G'W p_des（W=diag(w_vec) は要素積で計算）
        Gw = g .* w_vec;
        drv_single = (g' * Gw + reg_para * eye(n_sp)) \ (g' * (w_vec .* p_des));

        drv_ls(:,kk) = drv_single;
    end
end