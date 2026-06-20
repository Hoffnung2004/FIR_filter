function y = quantFilterIntOutWL(signal_raw, taps, ...
    Wsignal, Wtaps, Wout, Wfinal, roundMethod)

    sett = fimath(...
        'RoundingMethod', roundMethod, ...
        'OverflowAction', 'Saturate', ...
        'ProductMode', 'SpecifyPrecision', ...
        'ProductWordLength', Wout, ...
        'ProductFractionLength', 0, ...
        'SumMode', 'SpecifyPrecision', ...
        'SumWordLength', Wout, ...
        'SumFractionLength', 0);

    signalF = fi(signal_raw, 1, Wsignal, 0);
    tapsF   = fi(taps,       1, Wtaps,   0);

    signalF = fi(signalF, 1, Wout, 0, 'fimath', sett);
    tapsF   = fi(tapsF,   1, Wout, 0, 'fimath', sett);

    N = length(signalF);
    M = length(tapsF);

    yF = fi(zeros(size(signalF)), 1, Wout, 0, 'fimath', sett);

    for n = 1:N

        acc = fi(0, 1, Wout, 0, 'fimath', sett);

        for k = 1:M

            idx = n - k + 1;

            if idx >= 1
                acc = acc + signalF(idx) * tapsF(k);
            end

        end

        yF(n) = acc;

    end


    % Финальная выходная разрядность
    y_final = fi(yF, 1, Wfinal, 0, ...
        'RoundingMethod', roundMethod, ...
        'OverflowAction', 'Saturate');

    % Возврат в нормированный double для анализа
    y = double(y_final);

end