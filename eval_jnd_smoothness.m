function result = eval_jnd_smoothness(spl_profile, x, v, delta_JND, tau)
% eval_jnd_smoothness  空間SPLプロファイルを歩行速度で時間軸に変換し、
% JND(弁別閾)に基づく知覚的なめらかさを評価する。
%
% 入力:
%   spl_profile : 1×N  x方向のSPLプロファイル [dB]
%                 (plot_spl_profile.m の spl_profile と同じもの)
%   x           : 1×N  spl_profileに対応するx座標 [m]
%   v           : 想定歩行速度 [m/s]  (例: 0.82=ゆっくり, 1.31=通常歩行)
%   delta_JND   : 音圧レベル弁別閾 [dB]  (例: 1.0。文献値は0.5~1.5程度で変動)
%   tau         : ラウドネスの時間積分定数 [s]
%                 (例: 0.050=release/BZ->DZ方向、0.022=attack/DZ->BZ方向。
%                  Glasberg & Moore, 2002; Moore, 2014 のモデルに基づく目安値)
%
% 出力: result 構造体
%   .t              : 1×N  歩行速度vで換算した時刻 [s] (x(1)を原点とする)
%   .slope_dBps     : 1×N  各時刻でのSPL変化率 dSPL/dt [dB/s]
%   .slope_max_dBps : 許容変化率の閾値 [dB/s] (= delta_JND/tau。vに依存しない)
%   .viol_mask      : 1×N  論理配列。|slope_dBps| が閾値を超えている点
%   .viol_ratio     : スカラー。閾値超過している点の割合(0~1)
%   .viol_index     : スカラー。max(|slope_dBps|) / slope_max_dBps
%                      1以下なら全区間で"滑らか"の基準を満たしている

    x = x(:).';
    spl_profile = spl_profile(:).';

    if v <= 0
        error('eval_jnd_smoothness:invalidSpeed', 'vは正の値である必要があります。');
    end

    dx = mean(diff(x));           % x方向の格子間隔 [m] (等間隔を仮定)
    dt = dx / v;                  % 対応する時間間隔 [s]

    t = (x - x(1)) / v;           % 歩行速度vで換算した時刻軸 [s]

    slope_dBps = gradient(spl_profile, dt);   % dSPL/dt [dB/s]

    slope_max_dBps = delta_JND / tau;         % 許容変化率の閾値 (vに依存しない)

    viol_mask  = abs(slope_dBps) > slope_max_dBps;
    viol_ratio = sum(viol_mask) / numel(viol_mask);
    viol_index = max(abs(slope_dBps)) / slope_max_dBps;

    result.t              = t;
    result.slope_dBps      = slope_dBps;
    result.slope_max_dBps  = slope_max_dBps;
    result.viol_mask       = viol_mask;
    result.viol_ratio      = viol_ratio;
    result.viol_index      = viol_index;
end