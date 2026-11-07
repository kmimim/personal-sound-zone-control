%% 条件 C1〜C4 ごとに、制御点マップ・音圧マップ・折れ線グラフ（y=zone_h）を out_dir/figs に保存する
% make_speaker_raw.m から run される（plot_cond = true）。必要な変数は make_speaker_raw.m / main.m で定義済み。
%   rw_drvA, rw_drvB : 各条件の駆動信号（周波数領域） / rw_ctrlA, rw_ctrlB : 各条件の制御点（design_drive の第3,4出力）
% 出力: out_dir/figs/C{番号}_{名前}_control_points.png, _spl_map.png, _profile.png と、条件の比較 profile_compare.png
% 音圧は「各条件・各音のBZ制御点の平均広帯域エネルギー」を 0 dB とした相対値（spl_distribution.m / plot_spl_profile.m と同じ基準）。
% 図の体裁（カラーマップ・ゾーン枠・線の色）は spl_distribution.m / plot_spl_profile.m に合わせている。

pc_dir = fullfile(out_dir, "figs");
if ~exist(pc_dir, 'dir'), mkdir(pc_dir); end
if plot_show, pc_vis = 'on'; else, pc_vis = 'off'; end

pc_names = cell(rw_n, 1);
for q = 1:rw_n
    pc_names{q} = sprintf('C%d_%s', q, char(rw_conds{q,1}));
end

%% ゾーンの範囲（制御点の範囲。plot_spl_profile.m と同じ定義）
pc_pb = pos_mic(1:num_bz, :);
pc_pg = pos_mic(num_bz+1:num_bz+num_gz, :);
pc_pd = pos_mic(num_bz+num_gz+1:end, :);
pc_bzx = [min(pc_pb(:,1)), max(pc_pb(:,1))];
pc_dzx = [min(pc_pd(:,1)), max(pc_pd(:,1))];
if num_gz > 0
    pc_gzx = [min(pc_pg(:,1)), max(pc_pg(:,1))];
else
    pc_gzx = [pc_bzx(2), pc_dzx(1)];
end
pc_zy = [min(pc_pb(:,2)), max(pc_pb(:,2))];
% 制御点マップ用の枠 [x, y, 幅, 高さ]（BZ, GZ, DZ）と色
pc_box = [pc_bzx(1), pc_zy(1), pc_bzx(2)-pc_bzx(1), pc_zy(2)-pc_zy(1);
          pc_gzx(1), pc_zy(1), pc_gzx(2)-pc_gzx(1), pc_zy(2)-pc_zy(1);
          pc_dzx(1), pc_zy(1), pc_dzx(2)-pc_dzx(1), pc_zy(2)-pc_zy(1)];
pc_zcol = [0.25 0.60 0.75; 0.20 0.60 0.35; 0.45 0.45 0.45];
% 音圧マップ用の枠線（spl_distribution.m と同じ: 制御点の範囲から 0.01 m 内側）
pc_off = 0.01;
pc_conL = [pc_bzx(1)+pc_off, pc_zy(1)+pc_off; pc_bzx(1)+pc_off, pc_zy(2)-pc_off; pc_bzx(2)-pc_off, pc_zy(2)-pc_off; ...
           pc_bzx(2)-pc_off, pc_zy(1)+pc_off; pc_bzx(1)+pc_off, pc_zy(1)+pc_off];   % 左のゾーン
pc_conR = [pc_dzx(1)+pc_off, pc_zy(1)+pc_off; pc_dzx(1)+pc_off, pc_zy(2)-pc_off; pc_dzx(2)-pc_off, pc_zy(2)-pc_off; ...
           pc_dzx(2)-pc_off, pc_zy(1)+pc_off; pc_dzx(1)+pc_off, pc_zy(1)+pc_off];   % 右のゾーン
pc_sound = {'Sound A (bright: left zone)', 'Sound B (bright: right zone)'};

% カラーマップ（spl_distribution.m と同じ: 黒 → 紫 → 赤 → 黄）
pc_n = 256;  pc_c1 = round(pc_n/3);  pc_c2 = round(pc_n*2/3);
pc_cb = [0.05 0.05 0.05];  pc_cp = [0.35 0.00 0.55];  pc_cr = [0.90 0.15 0.15];  pc_cy = [1.00 0.95 0.20];
pc_cmap = zeros(pc_n, 3);
for ch = 1:3
    pc_cmap(1:pc_c1, ch)        = linspace(pc_cb(ch), pc_cp(ch), pc_c1);
    pc_cmap(pc_c1+1:pc_c2, ch)  = linspace(pc_cp(ch), pc_cr(ch), pc_c2-pc_c1);
    pc_cmap(pc_c2+1:end, ch)    = linspace(pc_cr(ch), pc_cy(ch), pc_n-pc_c2);
end

%% 0 dB の基準（各条件・各音のBZ制御点の平均広帯域エネルギー）
pc_ibzA = 1:num_bz;
pc_ibzB = num_bz+num_gz+1 : num_mic;
pc_refA = zeros(rw_n, 1);  pc_refB = zeros(rw_n, 1);
for q = 1:rw_n
    pA = zeros(numel(pc_ibzA), f_len);  pB = zeros(numel(pc_ibzB), f_len);
    for n = 1:f_len
        pA(:,n) = G_ctrl(pc_ibzA,:,n) * rw_drvA{q}(:,n);
        pB(:,n) = G_ctrl(pc_ibzB,:,n) * rw_drvB{q}(:,n);
    end
    pc_refA(q) = mean(sum(abs(pA).^2, 2));
    pc_refB(q) = mean(sum(abs(pB).^2, 2));
end

%% 折れ線グラフ用: y = zone_h 上のレベル
pc_xl = rw_xl;
pc_LA = zeros(numel(pc_xl), rw_n);  pc_LB = zeros(numel(pc_xl), rw_n);
for q = 1:rw_n
    pLA = zeros(numel(pc_xl), f_len);  pLB = zeros(numel(pc_xl), f_len);
    for n = 1:f_len
        pLA(:,n) = rw_Gline(:,:,n) * rw_drvA{q}(:,n);
        pLB(:,n) = rw_Gline(:,:,n) * rw_drvB{q}(:,n);
    end
    pc_LA(:,q) = 10*log10(sum(abs(pLA).^2, 2) / pc_refA(q) + eps);
    pc_LB(:,q) = 10*log10(sum(abs(pLB).^2, 2) / pc_refB(q) + eps);
end

%% 音圧マップ用: 部屋全体のレベル（周波数ごとに伝達関数を作り、全条件を同時に積算する）
pc_mx = room_size(1) : itv_map : room_size(2);
pc_my = max(itv_map, room_size(3)) : itv_map : room_size(4);
[pc_MX, pc_MY] = meshgrid(pc_mx, pc_my);
pc_P = [pc_MX(:), pc_MY(:)];
pc_EA = zeros(size(pc_P, 1), rw_n);  pc_EB = pc_EA;
for n = 1:f_len
    Gn = IR_freefield(pc_P, pos_sp, k_list(n));      % [点 x スピーカー]
    for q = 1:rw_n
        pc_EA(:,q) = pc_EA(:,q) + abs(Gn * rw_drvA{q}(:,n)).^2;
        pc_EB(:,q) = pc_EB(:,q) + abs(Gn * rw_drvB{q}(:,n)).^2;
    end
end

%% 図: 条件ごとに3枚
for q = 1:rw_n
    ttl = strrep(pc_names{q}, '_', ' ');

    % --- (1) 制御点マップ
    fig = figure('Visible', pc_vis, 'Position', [100, 100, 1400, 620]);
    pc_ctrl = {rw_ctrlA{q}, rw_ctrlB{q}};
    for s = 1:2
        c_ = pc_ctrl{s};
        subplot(1, 2, s);  hold on;
        for b = 1:3
            if pc_box(b,3) > 0
                rectangle('Position', pc_box(b,:), 'EdgeColor', pc_zcol(b,:), 'LineStyle', '--');
            end
        end
        h = [];  lab = {};
        if any(c_.on)
            if any(~c_.on)
                h(end+1) = scatter(pos_sp(~c_.on,1), pos_sp(~c_.on,2), 30, [0.6 0.6 0.6], '^');
                lab{end+1} = 'Speaker (silent)';
            end
            h(end+1) = scatter(pos_sp(c_.on,1), pos_sp(c_.on,2), 40, [0.85 0.1 0.1], '^', 'filled');
            lab{end+1} = sprintf('Speaker (active: %d)', nnz(c_.on));
        else
            h(end+1) = scatter(pos_sp(:,1), pos_sp(:,2), 30, [0 0 0], '^', 'filled');
            lab{end+1} = 'Speaker';
        end
        pc_layers = {c_.bz,   'Bright zone points',      [0.25 0.60 0.75], 16;
                     c_.gz,   'Gradation zone points',   [0.20 0.60 0.35], 12;
                     c_.dz,   'Dark zone points',        [0.45 0.45 0.45], 12;
                     c_.L,    'Dark: L-line points',     [0.80 0.00 0.00], 12;
                     c_.dzin, 'Dark: DZ interior points',[0.90 0.55 0.15], 14;
                     c_.fill, 'Dark: gap-fill points',   [0.60 0.20 0.70], 14};
        for L_ = 1:size(pc_layers, 1)
            P_ = pc_layers{L_, 1};
            if ~isempty(P_)
                h(end+1) = scatter(P_(:,1), P_(:,2), pc_layers{L_,4}, repmat(pc_layers{L_,3}, size(P_,1), 1), 'filled');
                lab{end+1} = sprintf('%s (%d)', pc_layers{L_,2}, size(P_,1));
            end
        end
        daspect([1 1 1]);  xlim(room_size(1:2));  ylim(room_size(3:4));  grid on;  box on;
        xlabel('x [m]');  ylabel('y [m]');
        title(sprintf('%s: %s', ttl, pc_sound{s}));
        lg = legend(h, lab(1:numel(h)), 'Location', 'northeast');  set(lg, 'FontSize', 7);
    end
    saveas(fig, fullfile(pc_dir, [pc_names{q} '_control_points.png']), 'png');  close(fig);

    % --- (2) 音圧マップ（spl_distribution.m と同じ体裁）
    fig = figure('Visible', pc_vis, 'Position', [100, 100, 1400, 620]);
    pc_Lm = {10*log10(pc_EA(:,q) / pc_refA(q) + eps), 10*log10(pc_EB(:,q) / pc_refB(q) + eps)};
    for s = 1:2
        Z = reshape(pc_Lm{s}, size(pc_MX));
        subplot(1, 2, s);
        colormap(pc_cmap);
        imagesc(pc_mx, pc_my, Z);  hold on;
        axis xy;
        scatter(pos_sp(:,1), pos_sp(:,2), 15, 'k', '^', 'filled');
        if s == 1
            plot(pc_conL(:,1), pc_conL(:,2), 'c--', 'LineWidth', 0.8);   % 音Aの明るい側（左）
            plot(pc_conR(:,1), pc_conR(:,2), 'w--', 'LineWidth', 0.8);
        else
            plot(pc_conL(:,1), pc_conL(:,2), 'w--', 'LineWidth', 0.8);
            plot(pc_conR(:,1), pc_conR(:,2), 'c--', 'LineWidth', 0.8);   % 音Bの明るい側（右）
        end
        hold off;
        xlabel('x[m]');  ylabel('y[m]');
        colorbar;  caxis(map_clim);
        title(sprintf('%s: %s', ttl, pc_sound{s}));
        daspect([1 1 1]);  xlim(room_size(1:2));  ylim(room_size(3:4));
        grid on;  ax = gca;
        try
            set(ax, 'GridColor', [1, 1, 1]);  set(ax, 'GridAlpha', 0.35);  set(ax, 'GridLineStyle', ':');
        catch
        end
        box on;  set(gca, 'Layer', 'top');
    end
    set(gcf, 'PaperPositionMode', 'auto');
    saveas(fig, fullfile(pc_dir, [pc_names{q} '_spl_map.png']), 'png');  close(fig);

    % --- (3) 折れ線グラフ（y = zone_h。plot_spl_profile.m と同じ体裁）
    fig = figure('Visible', pc_vis, 'Position', [100, 100, 1000, 460]);
    y_lo = min([pc_LA(:,q); pc_LB(:,q)]) - 5;  y_hi = max([pc_LA(:,q); pc_LB(:,q)]) + 5;
    patch([pc_bzx(1) pc_gzx(1) pc_gzx(1) pc_bzx(1)], [y_lo y_lo y_hi y_hi], 'c', 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'DisplayName', 'Left zone (Sound A bright)');
    hold on;
    if num_gz > 0
        patch([pc_gzx(1) pc_gzx(2) pc_gzx(2) pc_gzx(1)], [y_lo y_lo y_hi y_hi], 'g', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'DisplayName', 'Gradation Zone');
    end
    patch([pc_gzx(2) pc_dzx(2) pc_dzx(2) pc_gzx(2)], [y_lo y_lo y_hi y_hi], 'k', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'DisplayName', 'Right zone (Sound B bright)');
    plot(pc_xl, pc_LA(:,q), '-', 'Color', [0, 0, 0.5], 'LineWidth', 1.5, 'DisplayName', sprintf('Sound A (y = %.2f m)', zone_h));
    plot(pc_xl, pc_LB(:,q), '-', 'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.5, 'DisplayName', sprintf('Sound B (y = %.2f m)', zone_h));
    xlabel('x [m]');  ylabel('Relative broadband level [dB re mean BZ energy]');
    title(sprintf('%s: x-direction relative level at y = %.2f m', ttl, zone_h));
    xlim(room_size(1:2));  ylim([y_lo, y_hi]);  grid on;
    legend('Location', 'best');
    drawnow;
    saveas(fig, fullfile(pc_dir, [pc_names{q} '_profile.png']), 'png');  close(fig);
end

%% 条件の比較（折れ線グラフ）
fig = figure('Visible', pc_vis, 'Position', [100, 100, 1400, 480]);
pc_col = [0 0 0; 0.85 0.33 0.10; 0.00 0.45 0.74; 0.47 0.67 0.19];
for s = 1:2
    subplot(1, 2, s);  hold on;
    if s == 1, Lc = pc_LA; else, Lc = pc_LB; end
    for q = 1:rw_n
        plot(pc_xl, Lc(:,q), 'Color', pc_col(mod(q-1, 4)+1, :), 'LineWidth', 1.4);
    end
    xlim(room_size(1:2));  grid on;  box on;
    xlabel('x [m]');  ylabel('Relative broadband level [dB re mean BZ energy]');
    title(sprintf('%s (y = %.2f m)', pc_sound{s}, zone_h));
    legend(strrep(pc_names, '_', ' '), 'Location', 'south');
end
saveas(fig, fullfile(pc_dir, 'profile_compare.png'), 'png');  close(fig);

fprintf("\n図を %s に保存しました（各条件: _control_points / _spl_map / _profile、全体: profile_compare）\n", pc_dir);