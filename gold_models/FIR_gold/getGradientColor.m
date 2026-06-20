function hexColor = getGradientColor(n, i, palette)
% GETGRADIENTCOLOR Возвращает hex-цвет для i-й точки из n точек градиента.
%   hexColor = getGradientColor(n, i, palette)
%
%   ВХОД:
%     n       - общее число точек (целое >= 1)
%     i       - номер текущей точки (целое, 1 <= i <= n)
%     palette - cell array hex-строк, например:
%               {'#0D47A1', '#00ACC1', '#FFEB3B', '#FF5722'}
%               {'#000000', '#FFFFFF'}
%               {'#440154', '#3B528B', '#21908C', '#5DC863', '#FDE725'}
%               {'#1E88E5', '#E53935'}
%   ВЫХОД:
%     hexColor - строка вида '#RRGGBB'

    if n < 1
        error('Параметр n должен быть >= 1.');
    end
    if i < 1 || i > n
        error('Параметр i должен быть в диапазоне [1, n].');
    end
    
    % Нормализация индекса к отрезку [0, 1]
    if n == 1
        t = 0;
    else
        t = (i - 1) / (n - 1);
    end
    
    % Преобразование палитры в матрицу RGB в диапазоне [0, 1]
    M = numel(palette);
    rgbStops = zeros(M, 3);
    for k = 1:M
        h = palette{k};
        if h(1) == '#'
            h = h(2:end); % Убираем решётку, если есть
        end
        rgbStops(k, 1) = hex2dec(h(1:2)) / 255;
        rgbStops(k, 2) = hex2dec(h(3:4)) / 255;
        rgbStops(k, 3) = hex2dec(h(5:6)) / 255;
    end
    
    % Линейная интерполяция между ближайшими опорными цветами
    if M == 1
        resRGB = rgbStops(1, :);
    else
        scaledT = t * (M - 1);
        idx     = floor(scaledT);
        idx     = min(idx, M - 2);          % защита от выхода за последний сегмент
        frac    = scaledT - idx;            % дробная часть внутри сегмента [0,1]
        
        c1 = rgbStops(idx + 1, :);
        c2 = rgbStops(idx + 2, :);
        resRGB = c1 + frac * (c2 - c1);
    end
    
    % Округление и перевод обратно в hex
    r = round(resRGB(1) * 255);
    g = round(resRGB(2) * 255);
    b = round(resRGB(3) * 255);
    hexColor = sprintf('#%02X%02X%02X', r, g, b);
end