function h = spec_to_fir(H, bin_idx, L_fir)
    % 共通FFTビン(bin_idx)上の周波数応答Hから、実数の因果FIR(長さL_fir)を作る。
    % 設計帯域外は0、負周波数側は共役対称。
    if any(bin_idx < 1) || any(bin_idx >= L_fir/2)
        error('spec_to_fir:binRange', 'bin_idxは1以上L_fir/2未満である必要があります。');
    end
    S = zeros(L_fir, 1);
    S(bin_idx + 1) = H(:);
    S(L_fir - bin_idx + 1) = conj(H(:));
    h = real(ifft(S));
end
