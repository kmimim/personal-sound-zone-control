# 伝達関数計算関数 G

function G = IR_freefield(mic_geo, sp_geo, k)
    % mic_geo, sp_geo: 座標 [点数 x 2]、k: 波数の配列 -> G: [マイク x スピーカー x 周波数]
    r = sqrt((mic_geo(:,1) - sp_geo(:,1).').^2 + (mic_geo(:,2) - sp_geo(:,2).').^2);
    r = max(r, 1e-4);  % 距離0を避ける
    G = zeros(size(r, 1), size(r, 2), length(k));
    for kk = 1:length(k)
        G(:,:,kk) = (1i / 4) * besselh(0, 1, k(kk) * r);  % 2次元グリーン関数
    end
end