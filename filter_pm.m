function drv_ls = filter_pm(mic_geo, G, f, ang_wave, amp_src, Nsrc, c ,num_bz)

    % Gのサイズ取得
    s = size(G);
    n_mic = s(1);
    n_sp  = s(2);

    % 周波数ビン数
    if numel(s) >= 3
        f_len = s(3);
    else
        f_len = 1;
    end

    % 出力用行列
    drv_ls = zeros(n_sp, f_len);

    %===================================================================
    % 【重み付け設定】GZ内（-0.5〜0.5）のグラデーション仕様
    %===================================================================
    % 全マイクの重みを格納する列ベクトル（初期値はすべて 1.0）
    w = ones(n_mic, 1);
    
    % GZエリアのマイクのインデックスを特定
    gz_indices = (num_bz + 1):(2 * num_bz);
    
    % GZのマイクのx座標をすべて抽出
    gz_x = mic_geo(gz_indices, 1);
    
    % 中央(x=0.0)に近づくほど重みを徐々に減らしていく
    % x = -0.5 で重み 1.0（きっちり制御開始）
    % x =  0.0 で重み 0.01（ほとんどサボる）
    w_min = 0.01; 
    
    for i = 1:length(gz_indices)
        idx = gz_indices(i);
        current_x = gz_x(i);
        
        if current_x <= 0.0
            % 【GZの前半: -0.5 <= x <= 0.0】
            % x = -0.5 から 0.0 に向かって重みを直線的に減少させる
            w(idx) = 1.0 - (1.0 - w_min) * (current_x - (-0.5)) / 0.5;
        else
            % 【GZの後半: 0.0 < x <= 0.5】
            % DZと同様に完全に音を消したいため、重みは1.0（全力で制御させる）
            w(idx) = 1.0;
        end
    end
    
    % 対角行列 W に変換
    W = diag(w);
    %===================================================================

    % 周波数ごとに処理
    for kk = 1:f_len

        % 現在の周波数における伝達関数行列
        g = G(:,:,kk);

        % 正則化パラメータの計算
        reg_para = 1e-5 * max(eig(g' * g));

        %--------------------------------------------------
        % 各ゾーンの目標音圧生成（グラデーション仕様）
        %--------------------------------------------------
        % ① Bright Zone の目標音圧（平面波）
        p_des_bz = amp_src .* exp( ...
            1i * (2*pi*f(kk)/c) * ...
            (mic_geo(1:num_bz,1)*cos(ang_wave) + ...
             mic_geo(1:num_bz,2)*sin(ang_wave)));

        % ② Gradient Zone の目標音圧（目標そのものも減衰させる）
        p_des_gz = zeros(num_bz, Nsrc); % 初期化
        for i = 1:length(gz_indices)
            current_x = gz_x(i);
            
            if current_x <= 0.0
                % 【GZの前半: -0.5 <= x <= 0.0】
                % x = -0.5 で減衰率 1.0（通常音量）
                % x =  0.0 で減衰率 0.0（無音目標）
                decay_factor = 1.0 - (current_x - (-0.5)) / 0.5;
                
                % 元の平面波の位相を計算
                p_phase = exp(1i * (2*pi*f(kk)/c) * ...
                    (current_x * cos(ang_wave) + mic_geo(gz_indices(i),2) * sin(ang_wave)));
                
                % 振幅を直線減衰させた値を目標音圧として格納（ドット付き演算子で安全に計算）
                p_des_gz(i, :) = decay_factor .* amp_src .* p_phase;
            else
                % 【GZの後半: 0.0 < x <= 0.5】
                % DZと同様に完全に 0 を目標にする
                p_des_gz(i, :) = zeros(1, Nsrc);
            end
        end

        % ③ Dark Zone の目標音圧（0固定）
        p_des_dz = zeros(n_mic - 2*num_bz, Nsrc);

        % 全制御点の目標音圧ベクトルを縦に結合
        p_des = [p_des_bz;
                 p_des_gz;
                 p_des_dz];

        %--------------------------------------------------
        % 重み付き最小二乗法 (Weighted Pressure Matching)
        %--------------------------------------------------
        drv_single = (g' * W * g + reg_para * eye(n_sp)) \ (g' * W * p_des);

        % 周波数ごとの結果を保存
        drv_ls(:,kk) = drv_single;
    end

end