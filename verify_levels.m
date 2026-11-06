% 出力したrawから、左BZ中心と右BZ中心での音の大きさ(RMS)を、自由空間の伝達関数で再計算する（音Aと音Bの大きさが同じか）
clear; clc;
in_dir = "speaker_raw";  fs_out = 48000;  c = 340;
num_sp = 32;  itv_sp = 0.05;  zone_h = 1.0;  ref_x = 0.575;           % BZ中心のx [m]（左: -ref_x、右: +ref_x）
names = {"C1_nocontrol", "C2_conventional", "C3_gz_fl-20", "C4_gz_fl-30"};
pos_sp = [((0:num_sp-1)' - (num_sp-1)/2) * itv_sp, zeros(num_sp, 1)];   % 左から1〜32
ref = [-ref_x, zone_h; ref_x, zone_h];
fprintf("%-16s | 左BZ中心のRMS | 右BZ中心のRMS | 右-左 [dB]\n", "条件");
for q = 1:numel(names)
    for n = 1:num_sp
        fid = fopen(fullfile(in_dir, names{q}, sprintf("spk%02d.raw", n)), 'rb');
        s = fread(fid, Inf, 'int16', 0, 'ieee-le') / 32767;  fclose(fid);
        if n == 1, N = numel(s); Sf = zeros(N, num_sp); end
        Sf(:,n) = s;
    end
    F = fft(Sf);
    fk = (0:N-1)' * fs_out / N;
    sel = find(fk >= 400 & fk <= 2100);
    G = IR_freefield(ref, pos_sp, 2*pi*fk(sel).'/c);          % [2 x 32 x 帯域内のビン数]
    P = zeros(2, numel(sel));
    for n = 1:num_sp
        P = P + squeeze(G(:,n,:)) .* repmat(F(sel,n).', 2, 1);
    end
    rms = sqrt(2 * sum(abs(P).^2, 2)) / N;                      % パーセバルの式（正の周波数のみ）
    fprintf("%-16s | %12.5f | %12.5f | %+7.2f\n", names{q}, rms(1), rms(2), 20*log10(rms(2)/rms(1)));
end