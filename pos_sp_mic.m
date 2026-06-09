% スピーカーとマイクの配置座標を計算する関数
function [pos_sp, pos_mic, num_mic] = pos_sp_mic(num_sp, y_center, n_x, n_y, d1, d2, pltPos)

    % スピーカーの配置形状を切り替えるフラグ（false: 直線状 / true: 円弧状）
    isArc = false; 

    %% ---------------------------------------------------------------------
    %% 制御ゾーンの座標計算
    %% ---------------------------------------------------------------------
    % main.m から渡された点数と範囲を基に、正確な格子座標の配列を生成
    bz_x = linspace(-d1/2, d1/2, n_x);
    bz_y = linspace(-d2/2, d2/2, n_y);

    % -----------------------
    % シフト後の中心
    % -----------------------
    bz_center = [-1.0, y_center];
    dz_center = [ 1.0, y_center];
    dist_zone = dz_center(1) - bz_center(1); % BZとDZの中心間距離（2.0m）

    % -----------------------
    % 点格納
    % -----------------------
    num_bz = n_x * n_y; % ブライトゾーンの総点数
    pos_bz = zeros(num_bz, 2);

    % BZ（左）：格子状に配置
    n = 0;
    for x_idx = 1:length(bz_x)
        for y_idx = 1:length(bz_y)
            n = n + 1;
            pos_bz(n,:) = [bz_x(x_idx) + bz_center(1), ...
                        bz_y(y_idx) + bz_center(2)];
        end
    end

    % DZ（右）：【Lの字型に修正しつつ、点数をBzと完全に一致させる】
    % 縦辺（長さ d2）と底辺（長さ d1）の総延長に沿って、点数を均等に分配します。
    % これにより角の重複もなくなり、Bzと次元が一致するためエラーが解消します。
    L_total = d1 + d2; 
    s = linspace(0, L_total, num_bz)'; % 0からL字総延長までの等間隔ベクトル

    pos_dz = zeros(num_bz, 2);
    for i = 1:num_bz
        if s(i) <= d2
            % 縦辺（Dz領域の左端：上から下へ向かう）
            pos_dz(i, 1) = dz_center(1) - d1/2;
            pos_dz(i, 2) = (dz_center(2) + d2/2) - s(i);
        else
            % 底辺（Dz領域の下端：左から右へ向かう）
            pos_dz(i, 1) = (dz_center(1) - d1/2) + (s(i) - d2);
            pos_dz(i, 2) = dz_center(2) - d2/2;
        end
    end
    
    % 前半がブライト（格子）、後半がダーク（L字）となるよう1つの行列に結合
    pos_mic = [pos_bz; pos_dz];
    % 実際に生成された総点数を main.m 側へ返す
    num_mic = size(pos_mic, 1);


    %% ---------------------------------------------------------------------
    %% スピーカーアレイ（音源）の座標計算
    %% ---------------------------------------------------------------------

    %% 円弧状にスピーカーを配置する場合
    if isArc
        itv_ang = pi/40;  % スピーカー間の角度間隔 [rad]（180度/40 = 4.5度間隔）
        % 各スピーカーの配置角度を、中心（0度）から左右対称になるよう計算
        ang_sp = itv_ang * ((0.5 - num_sp/2) : (num_sp/2 - 0.5));
        
        % 三角関数を使って、円弧上の (x, y) 座標へ変換
        x_sp = y_center * sin(ang_sp);
        y_sp = y_center - y_center * cos(ang_sp);
        pos_sp = [x_sp', y_sp'];
        
    %% 直線状にスピーカーを配置する場合（デフォルト）
    else
        itv_sp = 0.085;   % スピーカー同士の間隔 [m]（8.5cm間隔）
        
        x_sp_1 = -(num_sp-1)/2 * itv_sp;
        y_sp_1 = 0;       % スピーカーアレイの基準高さ（y=0）
        
        pos_sp = zeros(num_sp, 2);    % スピーカー座標の格納行列を初期化
        pos_sp(1,:) = [x_sp_1, y_sp_1]; % 1台目の座標を代入
        
        % 2台目以降のスピーカーの x 座標を等間隔で計算
        pos_sp(2:end, 1) = x_sp_1 + (1:num_sp-1) * itv_sp;
    end

    %% ---------------------------------------------------------------------
    %% 配置図の描画と画像保存
    %% ---------------------------------------------------------------------
    if pltPos
        clf 
        
        % スピーカー位置を黒い「▲」でプロット
        h1 = scatter(pos_sp(:,1), pos_sp(:,2), 'k', '^', 'filled'); hold on;
        % 制御点をサイズ10の「●」でプロット
        h2 = scatter(pos_mic(:,1), pos_mic(:,2), 10, 'filled');
        
        daspect([1 1 1])    % グラフの縦横比を 1:1 に固定
        xlim([-1.5,1.5 ])   % x軸の表示範囲を -1.5m 〜 1.5m に設定
        ylim([0, 2])        % y軸の表示範囲を 0m 〜 2m に設定
        grid on;            % グリッド線を表示
        
        xlabel("x[m]"); ylabel("y[m]"); % 軸ラベルの設定
        legend({"sp", "mic"});           % 凡例の表示
        
        % 設定条件を自動的に組み込んだ保存用ファイル名を作成
        filename = sprintf("plc_sp_%d_mic_%d_zone-h_%.2fm_zone-dis_%.2fm.png", ...
                            num_sp, num_mic, y_center, dist_zone);
        title(sprintf("sp=%d, mic=%d, height=%.2f, dis=%.2f", num_sp, num_mic, y_center, dist_zone));
        
        set(gca, 'fontsize', 15)       
        saveas(gcf, filename, 'png');  
    end
end