function y = resample_fft(x, fs_in, fs_out)
    % FFTで帯域制限補間して、サンプリング周波数を fs_in から fs_out に変換する
    x = x(:);
    N = numel(x);
    M = round(N * fs_out / fs_in);
    if M == N
        y = x;
        return;
    end
    X = fft(x);
    Y = zeros(M, 1);
    n_pos = floor((min(N, M) - 1) / 2);
    Y(1) = X(1);
    Y(2:n_pos+1) = X(2:n_pos+1);
    Y(M-n_pos+1:M) = X(N-n_pos+1:N);
    y = real(ifft(Y)) * (M / N);
end