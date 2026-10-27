function h = spec_to_fir(H, bin_idx, L_fir)
    % 共通FFTビン上の応答Hから、実数のFIR（長さL_fir）を作る（帯域外は0）
    if any(bin_idx < 1) || any(bin_idx >= L_fir/2)
        error('spec_to_fir:binRange', 'bin_idxは1以上L_fir/2未満である必要があります。');
    end
    S = zeros(L_fir, 1);
    S(bin_idx + 1) = H(:);
    S(L_fir - bin_idx + 1) = conj(H(:));
    h = real(ifft(S));
end