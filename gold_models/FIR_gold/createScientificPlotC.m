function createScientificPlotC(x, y, line_styles, line_widths, marker_types, marker_sizes, ...
                             line_colors, marker_edge_colors, marker_face_colors, ...
                             legend_labels, legend_location, x_limits, y_limits, ...
                             x_label, y_label, plot_title, ...
                             log_x_scale, log_y_scale, figure_position, save_plots)
% createScientificPlot - Создает научный график с настройками
% 
% 2026-05-14 Создана на основе функции createScientificPlot от 2026-05-14
%            
% 
% Входные параметры:
%   x - вектор значений по оси X
%   y - ячейка с векторами значений по оси Y (один график на ячейку)
%   line_styles - ячейка со стилями линий
%   line_widths - вектор с толщинами линий
%   marker_types - ячейка с типами маркеров
%   marker_sizes - вектор с размерами маркеров
%   line_colors - цвета кривых
%   marker_edge_colors - цвета маркеров
%   marker_face_colors - цвета заливки маркеров (оставить пустым для прозрачных)
%   legend_labels - ячейка с подписями для легенды
%   legend_location - строка с расположением легенды ('southwest', 'northeast', и т.д.)
%   x_limits - [x_min, x_max] границы по оси X
%   y_limits - [y_min, y_max] границы по оси Y
%   x_label - подпись оси X (может содержать TEX-форматирование)
%   y_label - подпись оси Y (может содержать TEX-форматирование)
%   plot_title - заголовок графика
%   log_x_scale - логический флаг: true - логарифмическая ось X, false - линейная
%   log_y_scale - логический флаг: true - логарифмическая ось Y, false - линейная
%   figure_position - позиция графика. Предложенные варианты:
%       [300, 100, 1200, 650] - FullHD
%       [300, 100, 900, 650]  - В диплом
%   save_plots - логический флаг: true - сохранить графики, false - не сохранять
%

    %% Проверка входных параметров
    num_plots = length(y);
    
    if length(line_styles) ~= num_plots
        error('Количество стилей линий должно совпадать с количеством графиков');
    end
    if length(line_widths) ~= num_plots
        error('Количество толщин линий должно совпадать с количеством графиков');
    end
    if length(marker_types) ~= num_plots
        error('Количество типов маркеров должно совпадать с количеством графиков');
    end
    if length(marker_sizes) ~= num_plots
        error('Количество размеров маркеров должно совпадать с количеством графиков');
    end
    if length(legend_labels) ~= num_plots
        error('Количество подписей легенды должно совпадать с количеством графиков');
    end
    if length(line_colors) ~= num_plots
        error('Количество цветов линий должно совпадать с количеством графиков');
    end

    if length(marker_edge_colors) ~= num_plots
        error('Количество цветов маркеров должно совпадать с количеством графиков');
    end

    if ~isempty(marker_face_colors)
        if length(marker_face_colors) ~= num_plots
            error('Количество цветов заливки маркеров должно совпадать с количеством графиков');
        end
    end
    if length(figure_position) ~= 4
        error("Некорретное задание расположения графика")
    end

    %% Создание и настройка окна
    % Создаем имя файла без запрещенных символов
    valid_filename = regexprep(plot_title, '[<>:"/\\|?*]', '_');
    valid_filename = regexprep(valid_filename, '\s+', '_');
    plot_title=['\rm' plot_title]; 
    fig = figure('Position', figure_position, ...
                 'Name', plot_title, ...
                 'NumberTitle', 'off');
    
    hold on; 
    grid on; 
    box on;

    %% Построение графиков циклом
    use_individual_x = iscell(x) && (length(x) == num_plots);

    for i = 1:num_plots
        % Проверяем, есть ли данные для текущего графика
        if i <= length(y) && ~isempty(y{i})

            if use_individual_x
                current_x = x{i};
                current_x = current_x(1:length(y{i}));
            else
                current_x = x(1:length(y{i}));
            end

            if length(current_x) ~= length(y{i})
                error('Для графика %d длины x и y не совпадают', i);
            end

            plot_args = { ...
                'Color', line_colors{i}, ...
                'LineWidth', line_widths(i), ...
                'LineStyle', line_styles{i}, ...
                'Marker', marker_types{i}, ...
                'MarkerSize', marker_sizes(i), ...
                'MarkerEdgeColor', marker_edge_colors{i}, ...
                'DisplayName', legend_labels{i}};

            % Если задан цвет заливки маркера
            if ~isempty(marker_face_colors)
                plot_args = [plot_args, {'MarkerFaceColor', marker_face_colors{i}}];
            end

            plot(current_x, y{i}, plot_args{:});
        end
    end

    %% Настройка границ построения
    if ~isempty(x_limits)
        xlim(x_limits);
    end
    if ~isempty(y_limits)
        ylim(y_limits); 
    end

    %% Настройка подписей осей
    % Ось X с форматированием
    if contains(x_label, '\it') || contains(x_label, '\rm') || contains(x_label, '$')
        xlabel(x_label, 'Interpreter', 'tex', ...
               'FontName', 'Times New Roman', ...
               'FontSize', 20);
    else
        xlabel(x_label, 'FontName', 'Times New Roman', 'FontSize', 20);
    end

    % Ось Y
    if contains(y_label, '\it') || contains(y_label, '\rm') || contains(y_label, '$')
        ylabel(y_label, 'Interpreter', 'tex', ...
               'FontName', 'Times New Roman', ...
               'FontSize', 20);
    else
        ylabel(y_label, 'FontName', 'Times New Roman', 'FontSize', 20);
    end

    %% Заголовок графика
    if contains(plot_title, '\it') || contains(plot_title, '\rm') || contains(plot_title, '$')
        title(plot_title, 'Interpreter', 'tex', ...
              'FontName', 'Times New Roman', ...
              'FontSize', 22);
    else
        title(plot_title, 'FontName', 'Times New Roman', 'FontSize', 22);
    end

    %% Легенда
    % Определяем, нужен ли интерпретатор для легенды
    use_interpreter = 'none';
    for i = 1:num_plots
        if contains(legend_labels{i}, '\it') || contains(legend_labels{i}, '\rm') || ...
           contains(legend_labels{i}, '\bf') || contains(legend_labels{i}, '$')
            use_interpreter = 'tex';
            break;
        end
    end
    
    legend_handle = legend(legend_labels, ...
        'Location', legend_location, ...
        'Interpreter', use_interpreter, ...
        'FontName', 'Times New Roman', ...
        'FontSize', 16, ...
        'Box', 'on');

    %% Дополнительная настройка осей
    ax = gca;
     % Логарифмическая шкала по X
    if log_x_scale
        set(ax, 'XScale', 'log');
    end
    % Логарифмическая шкала по Y
    if log_y_scale
        set(ax, 'YScale', 'log');
    end
    
    % Основные настройки
    set(ax, ...
        'FontName', 'Times New Roman', ...
        'FontSize', 20, ...
        'GridLineStyle', '--', ...
        'GridAlpha', 0.25, ...
        'LineWidth', 1, ...
        'XMinorTick', 'off', ...
        'YMinorTick', 'off');
    
    hold off;

    %% Сохранение графиков
    if save_plots
        % Сохраняем PNG
        png_filename = sprintf('%s.png', valid_filename);
        print(png_filename, '-dpng', '-r300');
        fprintf('График сохранен как: %s\n', png_filename);
        
        % Сохраняем FIG
        fig_filename = sprintf('%s.fig', valid_filename);
        saveas(fig, fig_filename);
        fprintf('График сохранен как: %s\n', fig_filename);
    end
end