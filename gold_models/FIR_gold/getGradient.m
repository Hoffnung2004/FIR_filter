function hexColor = getGradient(n, palette)
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

    hexColor = {};
    for i=1:n
        hexColor{end+1} = getGradientColor(n,i,palette);
    end
    
end