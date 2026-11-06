function [drvA, drvB] = design_drive(type, floor_dB, pos_sp, pos_mic, num_bz, num_gz, G, f, ang_wave, amp_src, Nsrc, c, tau, xr_A, xr_B)
    % 条件ごとの各スピーカーの駆動信号（周波数領域）。drvA: 音A（BZ=左）、drvB: 音B（BZ=右）
    %   type "gz"   : グラデーションゾーンあり（floor_dB、DZ目標=GZ終端）
    %   type "nogz" : グラデーションゾーンなしの従来手法。暗い側の制御点はL字配置（目標0）＋DZ内部の間引き点
    %   type "front": 制御なし。ゾーン前(xr_A, xr_B のx範囲)のスピーカーだけが、同じゲインで鳴る

    % 正則化の強さ（G'G の最大固有値に対する比）。従来は 1e-7。
    % 小さすぎると超指向性の駆動になり、FIRの周波数刻みの間でキャンセルが崩れる。最大|drv|も大きくなる。
    reg_rel = 1e-3;

    n_mic = size(pos_mic, 1);
    idx_bz = 1:num_bz;
    idx_gz = num_bz+1 : num_bz+num_gz;
    idx_dz = num_bz+num_gz+1 : n_mic;
    switch type
        case "gz"
            drvA = filter_pm(pos_mic, G, f, ang_wave, amp_src, Nsrc, c, num_bz, num_gz, tau, floor_dB, "floor", false, reg_rel);
            idx_B = [idx_dz, idx_gz, idx_bz];
            drvB = filter_pm(pos_mic(idx_B,:), G(idx_B,:,:), f, ang_wave, amp_src, Nsrc, c, numel(idx_dz), num_gz, tau, floor_dB, "floor", true, reg_rel);
        case "nogz"
            % 音A: 暗い側は x>=0 側のL字（x=0の縦線 y=0.14〜1.60 m と、y=0.10 m の横線 x=0〜1.0 m）。音Bはその左右反転。
            x_leg = (0:0.04:1.0)';
            y_leg = (0.14:0.04:1.60)';
            pos_L = [x_leg, 0.10 * ones(size(x_leg)); zeros(size(y_leg)), y_leg];
            pos_LB = [-pos_L(:,1), pos_L(:,2)];
            % L字の線だけではDZ内部が拘束されないため、DZ内部の格子点を半分に間引いて追加する。
            dz_in  = pos_mic(idx_dz(1:2:end), :);     % 音AのDZ内部（右ゾーン）
            dz_inB = [-dz_in(:,1), dz_in(:,2)];       % 音BのDZ内部（左ゾーン、左右反転）
            k = 2*pi*f/c;
            mic_A = [pos_mic(idx_bz,:); pos_L; dz_in];
            drvA = filter_pm(mic_A, IR_freefield(mic_A, pos_sp, k), f, ang_wave, amp_src, Nsrc, c, num_bz, 0, tau, -20, "zero", false, reg_rel);
            mic_B = [pos_mic(idx_dz,:); pos_LB; dz_inB];
            drvB = filter_pm(mic_B, IR_freefield(mic_B, pos_sp, k), f, ang_wave, amp_src, Nsrc, c, numel(idx_dz), 0, tau, -20, "zero", false, reg_rel);
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