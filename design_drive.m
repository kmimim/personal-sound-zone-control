function [drvA, drvB] = design_drive(type, floor_dB, pos_sp, pos_mic, num_bz, num_gz, G, f, ang_wave, amp_src, Nsrc, c, tau, xr_A, xr_B)
    % 条件ごとの各スピーカーの駆動信号（周波数領域）。drvA: 音A（BZ=左）、drvB: 音B（BZ=右）
    %   type "gz"   : グラデーションゾーンあり（floor_dB、DZ目標=GZ終端）
    %   type "nogz" : グラデーションゾーンなしの従来手法。暗い側の制御点はL字配置（目標0）＋DZ内部の間引き点
    %   type "front": 制御なし。ゾーン前(xr_A, xr_B のx範囲)のスピーカーだけが、同じゲインで鳴る

    % 正則化の強さ（G'G の最大固有値に対する比）。従来は 1e-7。
    % 小さすぎると超指向性の駆動になり、スピーカーの個体差やFIRの周波数刻みの間でキャンセルが崩れる。
    reg_rel = 1e-1;

    n_mic = size(pos_mic, 1);
    idx_bz = 1:num_bz;
    idx_gz = num_bz+1 : num_bz+num_gz;
    idx_dz = num_bz+num_gz+1 : n_mic;

    switch type
        case "gz"
            drvA = filter_pm(pos_mic, G, f, ang_wave, amp_src, Nsrc, c, ...
                num_bz, num_gz, tau, floor_dB, "floor", false, reg_rel);
            idx_B = [idx_dz, idx_gz, idx_bz];
            drvB = filter_pm(pos_mic(idx_B,:), G(idx_B,:,:), f, ang_wave, amp_src, Nsrc, c, ...
                numel(idx_dz), num_gz, tau, floor_dB, "floor", true, reg_rel);

        case "nogz"
            % 暗い側の制御点: L字（目標0）＋DZ内部の間引き点。音Aは右側、音Bはその左右反転。
            %   縦線: BZの端（最も右の制御点）から L_gap だけ離れた位置、y=0.14〜L_ytop m（既定 x=-0.335）
            %   横線: y=0.10 m、縦線の位置〜x=L_xend m
            L_gap  = 0.08;   % BZ端の制御点から縦線までの距離 [m]。0.04でBZゾーンの縁(x=-0.375)に重なり、0.08でその真隣（縁の外側0.04 m）
                     %   大きいほどBZの再現が楽になり、中央は暗くなる
            L_ytop = 2.2;    % 縦線の上端 [m]
            L_xend = 1.0;    % 横線の右端 [m]
            fill_gap = true;  % true: L字の隣（縦線とDZの間）にも目標0の制御点を置く（中央が暗くなるが、BZの波打ちは増える）
            fill_end = 0.37;   % その右端 [m]（音Aの場合。音Bは左右反転）
            x_L0 = max(pos_mic(idx_bz,1)) + L_gap;
            x_leg = (x_L0:0.04:L_xend)';
            y_leg = (0.14:0.04:L_ytop)';
            pos_L  = [x_leg, 0.10 * ones(size(x_leg)); x_L0 * ones(size(y_leg)), y_leg];
            pos_LB = [-pos_L(:,1), pos_L(:,2)];
            % L字の線だけではDZ内部が拘束されないため、DZ内部の格子点を半分に間引いて追加する。
            dz_in  = pos_mic(idx_dz(1:2:end), :);    % 音AのDZ内部（右ゾーン）
            dz_inB = [-dz_in(:,1), dz_in(:,2)];      % 音BのDZ内部（左ゾーン、左右反転）
            if fill_gap
                x_fill = (x_L0 + 0.085 : 0.08 : fill_end)';
                y_fill = linspace(min(pos_mic(idx_bz,2)), max(pos_mic(idx_bz,2)), 7)';
                [Xf, Yf] = meshgrid(x_fill, y_fill);
                pos_fill = [Xf(:), Yf(:)];
            else
                pos_fill = zeros(0, 2);
            end
            pos_fillB = [-pos_fill(:,1), pos_fill(:,2)];
            k = 2*pi*f/c;

            mic_A = [pos_mic(idx_bz,:); pos_L; dz_in; pos_fill];
            drvA = filter_pm(mic_A, IR_freefield(mic_A, pos_sp, k), f, ang_wave, amp_src, Nsrc, c, ...
                num_bz, 0, tau, -20, "zero", false, reg_rel);

            mic_B = [pos_mic(idx_dz,:); pos_LB; dz_inB; pos_fillB];
            drvB = filter_pm(mic_B, IR_freefield(mic_B, pos_sp, k), f, ang_wave, amp_src, Nsrc, c, ...
                numel(idx_dz), 0, tau, -20, "zero", false, reg_rel);

        case "front"
            delay = exp(-1i * 2*pi*f(:).' * tau);
            tol = 1e-6;   % 範囲の端にあるスピーカーを、浮動小数点の誤差で取りこぼさない
            on_A = pos_sp(:,1) >= xr_A(1) - tol & pos_sp(:,1) <= xr_A(2) + tol;
            on_B = pos_sp(:,1) >= xr_B(1) - tol & pos_sp(:,1) <= xr_B(2) + tol;
            drvA = double(on_A) * delay;
            drvB = double(on_B) * delay;

        otherwise
            error('design_drive:invalidType', 'typeは"gz" / "nogz" / "front" のいずれかです。');
    end
end