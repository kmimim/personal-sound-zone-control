function [drvA, drvB, ctrlA, ctrlB] = design_drive(type, floor_dB, pos_sp, pos_mic, num_bz, num_gz, G, f, ang_wave, amp_src, Nsrc, c, tau, xr_A, xr_B)
    % 条件ごとの各スピーカーの駆動信号（周波数領域）。drvA: 音A（BZ=左）、drvB: 音B（BZ=右）
    %   type "gz"   : グラデーションゾーンあり（floor_dB、DZ目標=GZ終端）
    %   type "nogz" : グラデーションゾーンなしの従来手法。GZを置かず、BZとDZが x=0 で接する専用ゾーンを使う。暗い側の制御点はL字配置（目標0）のみ（DZ内部の点は use_dzin で追加できる）
    %   type "nogz_gz": GZあり・GZ領域は制御しない従来手法。ゾーンは main.m のもの（BZ・GZ・DZ）。暗い側はL字のみ（GZ領域にもDZ内部にも制御点は置かない）
    %   type "front": 制御なし。ゾーン前(xr_A, xr_B のx範囲)のスピーカーだけが、同じゲインで鳴る
    % ctrlA, ctrlB（省略可）: 図の作成用に、使った制御点を返す構造体。
    %   bz, gz, dz: ゾーンの制御点 / L, dzin: nogzの暗い側の制御点 / on: 鳴らすスピーカー（frontのみ）
    %   zone_bz, zone_gz, zone_dz: その条件専用のゾーンのx範囲（nogzのみ。GZなし・BZとDZが接する）

    % 正則化の強さ（G'G の最大固有値に対する比）。従来は 1e-7。
    % 小さすぎると超指向性の駆動になり、スピーカーの個体差やFIRの周波数刻みの間でキャンセルが崩れる。
    reg_rel = 1e-1;

    n_mic = size(pos_mic, 1);
    idx_bz = 1:num_bz;
    idx_gz = num_bz+1 : num_bz+num_gz;
    idx_dz = num_bz+num_gz+1 : n_mic;

    e2 = zeros(0, 2);
    ctrlA = struct('bz', e2, 'gz', e2, 'dz', e2, 'L', e2, 'dzin', e2, 'fill', e2, 'on', false(size(pos_sp, 1), 1), ...
                   'zone_bz', [], 'zone_gz', [], 'zone_dz', []);   % zone_*: この条件専用のゾーンのx範囲 [x0 x1]（空なら main.m のゾーン）
    ctrlB = ctrlA;

    switch type
        case "gz"
            drvA = filter_pm(pos_mic, G, f, ang_wave, amp_src, Nsrc, c, ...
                num_bz, num_gz, tau, floor_dB, "floor", false, reg_rel);
            idx_B = [idx_dz, idx_gz, idx_bz];
            drvB = filter_pm(pos_mic(idx_B,:), G(idx_B,:,:), f, ang_wave, amp_src, Nsrc, c, ...
                numel(idx_dz), num_gz, tau, floor_dB, "floor", true, reg_rel);
            ctrlA.bz = pos_mic(idx_bz,:);  ctrlA.gz = pos_mic(idx_gz,:);  ctrlA.dz = pos_mic(idx_dz,:);
            ctrlB.bz = pos_mic(idx_dz,:);  ctrlB.gz = pos_mic(idx_gz,:);  ctrlB.dz = pos_mic(idx_bz,:);

        case "nogz"
            % ---- C2（従来手法）専用のゾーン: GZなし。BZ（左）とDZ（右）が x=0 で接する ----
            zone_w  = max(abs(pos_sp(:,1)));  % 各ゾーンの横幅 [m]（既定: スピーカー開口の半分 = 0.775）
            % ---- 暗い側の制御点（目標0）: L字 + DZ内部の間引き点。音Aは右側、音Bはその左右反転 ----
            use_L    = true;   % true: L字の制御点を使う
            use_dzin = false;  % true: DZ内部の制御点も使う（false: L字のみ）
            L_x0   = 0;        % L字の縦線のx [m]（BZとDZの境界）
            L_ytop = 2.2;      % 縦線の上端 [m]
            L_xend = 1.0;      % 横線の右端 [m]
            L_step = 0.04;     % L字の制御点の間隔 [m]

            % BZの制御点: main.m の制御点と同じ間隔（x, y）で、x=-zone_w〜0 に並べる（x=0 の列はL字の縦線と重なるので除く）
            x_all = unique(round(pos_mic(idx_bz,1) * 1e6) / 1e6);
            y_val = unique(round(pos_mic(idx_bz,2) * 1e6) / 1e6);
            dx_mic = median(diff(x_all));
            x_bz = linspace(-zone_w, 0, round(zone_w / dx_mic) + 1);
            x_bz = x_bz(1:end-1);
            pos_bzC = zeros(numel(x_bz) * numel(y_val), 2);
            ip = 0;
            for ix = 1:numel(x_bz)
                for iy = 1:numel(y_val)
                    ip = ip + 1;
                    pos_bzC(ip,:) = [x_bz(ix), y_val(iy)];
                end
            end
            pos_dzC = [-pos_bzC(:,1), pos_bzC(:,2)];     % DZ（右）は BZ の左右反転

            x_leg = (L_x0 : L_step : L_xend)';
            y_leg = (0.14 : L_step : L_ytop)';
            pos_L  = [x_leg, 0.10 * ones(size(x_leg)); L_x0 * ones(size(y_leg)), y_leg];
            pos_LB = [-pos_L(:,1), pos_L(:,2)];
            if ~use_L
                pos_L = zeros(0, 2);  pos_LB = zeros(0, 2);
            end
            % L字の線だけではDZ内部が拘束されないため、DZ内部の格子点を半分に間引いて追加する。
            dz_in  = pos_dzC(1:2:end, :);               % 音AのDZ内部（右ゾーン）
            dz_inB = [-dz_in(:,1), dz_in(:,2)];         % 音BのDZ内部（左ゾーン、左右反転）
            if ~use_dzin
                dz_in = zeros(0, 2);  dz_inB = zeros(0, 2);
            end
            k = 2*pi*f/c;

            mic_A = [pos_bzC; pos_L; dz_in];
            drvA = filter_pm(mic_A, IR_freefield(mic_A, pos_sp, k), f, ang_wave, amp_src, Nsrc, c, ...
                size(pos_bzC, 1), 0, tau, -20, "zero", false, reg_rel);

            mic_B = [pos_dzC; pos_LB; dz_inB];
            drvB = filter_pm(mic_B, IR_freefield(mic_B, pos_sp, k), f, ang_wave, amp_src, Nsrc, c, ...
                size(pos_dzC, 1), 0, tau, -20, "zero", false, reg_rel);

            ctrlA.bz = pos_bzC;  ctrlA.L = pos_L;   ctrlA.dzin = dz_in;
            ctrlB.bz = pos_dzC;  ctrlB.L = pos_LB;  ctrlB.dzin = dz_inB;
            ctrlA.zone_bz = [-zone_w, 0];  ctrlA.zone_dz = [0, zone_w];
            ctrlB.zone_bz = ctrlA.zone_bz;  ctrlB.zone_dz = ctrlA.zone_dz;

        case "nogz_gz"
            % ---- GZあり（GZ領域は制御しない）の従来手法。ゾーンは main.m のもの。"nogz" とL字・DZ内部の設定をそろえる ----
            use_L    = true;   % true: L字の制御点を使う
            use_dzin = false;  % true: DZ内部の制御点も使う（false: L字のみ）
            L_x0   = 0;        % L字の縦線のx [m]（"nogz" と同じ）
            L_ytop = 2.2;      % 縦線の上端 [m]
            L_xend = 1.0;      % 横線の右端 [m]
            L_step = 0.04;     % L字の制御点の間隔 [m]
            x_leg = (L_x0 : L_step : L_xend)';
            y_leg = (0.14 : L_step : L_ytop)';
            pos_L  = [x_leg, 0.10 * ones(size(x_leg)); L_x0 * ones(size(y_leg)), y_leg];
            pos_LB = [-pos_L(:,1), pos_L(:,2)];
            if ~use_L
                pos_L = zeros(0, 2);  pos_LB = zeros(0, 2);
            end
            dz_in  = pos_mic(idx_dz(1:2:end), :);
            dz_inB = [-dz_in(:,1), dz_in(:,2)];
            if ~use_dzin
                dz_in = zeros(0, 2);  dz_inB = zeros(0, 2);
            end
            k = 2*pi*f/c;

            mic_A = [pos_mic(idx_bz,:); pos_L; dz_in];
            drvA = filter_pm(mic_A, IR_freefield(mic_A, pos_sp, k), f, ang_wave, amp_src, Nsrc, c, ...
                num_bz, 0, tau, -20, "zero", false, reg_rel);

            mic_B = [pos_mic(idx_dz,:); pos_LB; dz_inB];
            drvB = filter_pm(mic_B, IR_freefield(mic_B, pos_sp, k), f, ang_wave, amp_src, Nsrc, c, ...
                numel(idx_dz), 0, tau, -20, "zero", false, reg_rel);

            ctrlA.bz = pos_mic(idx_bz,:);  ctrlA.L = pos_L;   ctrlA.dzin = dz_in;
            ctrlB.bz = pos_mic(idx_dz,:);  ctrlB.L = pos_LB;  ctrlB.dzin = dz_inB;

        case "front"
            delay = exp(-1i * 2*pi*f(:).' * tau);
            tol = 1e-6;   % 範囲の端にあるスピーカーを、浮動小数点の誤差で取りこぼさない
            on_A = pos_sp(:,1) >= xr_A(1) - tol & pos_sp(:,1) <= xr_A(2) + tol;
            on_B = pos_sp(:,1) >= xr_B(1) - tol & pos_sp(:,1) <= xr_B(2) + tol;
            drvA = double(on_A) * delay;
            drvB = double(on_B) * delay;
            ctrlA.on = on_A;
            ctrlB.on = on_B;

        otherwise
            error('design_drive:invalidType', 'typeは"gz" / "nogz" / "nogz_gz" / "front" のいずれかです。');
    end
end