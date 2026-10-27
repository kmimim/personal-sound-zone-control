function x = read_raw_pcm(path, n_channels, raw_type, max_val)
    % ヘッダなしPCM(RAW)を読み、[-1,1)に正規化した列ベクトルを返す（多チャンネルは平均してモノ化）
    if ~isscalar(n_channels) || ~isfinite(n_channels) || n_channels < 1 || n_channels ~= fix(n_channels)
        error('read_raw_pcm:invalidChannelCount', 'n_channelsには1以上の整数を指定してください。');
    end
    fid = fopen(path, 'rb');
    if fid == -1
        error('read_raw_pcm:fileOpenFailed', 'ファイルを開けませんでした: %s', path);
    end
    raw = fread(fid, Inf, raw_type);
    fclose(fid);
    if isempty(raw)
        error('read_raw_pcm:emptyInput', '入力音声ファイルにPCMデータがありません: %s', path);
    end
    if mod(numel(raw), n_channels) ~= 0
        error('read_raw_pcm:incompleteFrame', ...
            'サンプル数がチャンネル数(%d)で割り切れません。RAW形式とチャンネル数を確認してください: %s', n_channels, path);
    end
    if n_channels > 1
        n_frames = numel(raw) / n_channels;
        raw = reshape(raw, n_channels, n_frames).';
        x = mean(raw, 2);
    else
        x = raw(:);
    end
    x = double(x) / max_val;
end