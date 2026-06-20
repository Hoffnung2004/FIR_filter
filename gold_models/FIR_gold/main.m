clc
clear
close all
format compact
palette = {'#0D47A1', '#00ACC1', '#FFEB3B', '#FF5722'};


% Условие
Fs = 20e6; % Частоте семплирования
N  = 31;   % Порядок фильтра
fp = 2e6;  % Частота пропускания
fs = 4e6;  % Частота запирания
q = 16;
taps = firpm(N, [0 fp fs Fs/2]/(Fs/2), [1 1 0 0], [1 1]);

tsin = 0.0001;

Wtaps = 16;
Wsignal = 16;
Wout = 40;
Wfinal = 40;
roundMethod = 'Nearest';

freq_list = [1e6 2e6 3e6 4e6 5e6 6e6];
t = 0:1/Fs:(tsin - 1/Fs);
M0 = 2^(q-1);
M = max(taps);

taps_new = taps/M*(M0-1);
taps_newF = fi(taps_new, 1, 16);

taps_F = fi(taps, 1, 16, M/(M0-1), 0);

% sum(bin(taps_F)~=bin(taps_newF)) % Раскомментировать для сверки

% Для отображения

    x = t;
    line_styles = {'-','-'};
    marker_types = {'none','none'};
    line_widths = [2,2];
    marker_sizes = [8,8];
    figure_position = [300 100 1200 650];
    line_colors = {'#3F6FAE','#B84D46'};
    marker_edge_colors = {'g','g'}; % Не используется
    marker_face_colors = {'g','g'};
    
% Число точек вывода:
print_point = 100;

% Тест 1. Нули.
data_in = zeros(print_point+1,1);
data_out = quantFilterIntOutWL(data_in, taps_new, ...
    Wsignal, Wtaps, Wout, Wfinal, roundMethod);

data_in = data_in(:);
data_out = data_out(:);


fid = fopen('test1_in.txt', 'w');
fprintf(fid, '%d \n', data_in); 
fclose(fid);
fid = fopen('test1_out.txt', 'w');
fprintf(fid, '%d \n', data_out); 
fclose(fid);

plot_title = 'Тест 1 (нули)';
legend_labels = {'In','Out'};
y = {data_in(1:print_point+1),data_out(1:print_point+1)*max(abs(data_in(1:print_point+1)))/max(abs(data_out(1:print_point+1)))};
createScientificPlotC(x, y, line_styles, line_widths, marker_types, marker_sizes, ...
                                line_colors, marker_edge_colors, marker_face_colors, ...
                                legend_labels, 'northeast', [0 print_point/Fs], [-1 1], ...
                                'Время (с)', 'Сигнал',plot_title, ...
                                 false, false, figure_position, true);



% Тест 2. Единичный испульс
data_in = [zeros(10,1); 1; zeros(400,1)];
data_out = quantFilterIntOutWL(data_in, taps_new, ...
    Wsignal, Wtaps, Wout, Wfinal, roundMethod);
data_in = data_in(:);
data_out = data_out(:);
fid = fopen('test2_in.txt', 'w');
fprintf(fid, '%d \n', data_in); 
fclose(fid);
fid = fopen('test2_out.txt', 'w');
fprintf(fid, '%d \n', data_out); 
fclose(fid);

plot_title = 'Тест 2 (единичный импульс)';
legend_labels = {'In',['Out (scale /' num2str(max(abs(data_out(1:print_point+1)))/max(abs(data_in(1:print_point+1)))) ')']};
y = {data_in(1:print_point+1),data_out(1:print_point+1)*max(abs(data_in(1:print_point+1)))/max(abs(data_out(1:print_point+1)))};
createScientificPlotC(x, y, line_styles, line_widths, marker_types, marker_sizes, ...
                                line_colors, marker_edge_colors, marker_face_colors, ...
                                legend_labels, 'northeast', [0 print_point/Fs], [-max(abs(data_in(1:print_point+1))) max(abs(data_in(1:print_point+1)))]*1.1, ...
                                'Время (с)', 'Сигнал',plot_title, ...
                                 false, false, figure_position, true);

% Тест 3. Ступенька
data_in = [zeros(10,1); ones(400,1)];
data_out = quantFilterIntOutWL(data_in, taps_new, ...
    Wsignal, Wtaps, Wout, Wfinal, roundMethod);
data_in = data_in(:);
data_out = data_out(:);
fid = fopen('test3_in.txt', 'w');
fprintf(fid, '%d \n', data_in); 
fclose(fid);
fid = fopen('test3_out.txt', 'w');
fprintf(fid, '%d \n', data_out); 
fclose(fid);

plot_title = 'Тест 3 (ступенька)';
legend_labels = {'In',['Out (scale /' num2str(max(abs(data_out(1:print_point+1)))/max(abs(data_in(1:print_point+1)))) ')']};
y = {data_in(1:print_point+1),data_out(1:print_point+1)*max(abs(data_in(1:print_point+1)))/max(abs(data_out(1:print_point+1)))};
createScientificPlotC(x, y, line_styles, line_widths, marker_types, marker_sizes, ...
                                line_colors, marker_edge_colors, marker_face_colors, ...
                                legend_labels, 'northeast', [0 print_point/Fs], [-max(abs(data_in(1:print_point+1))) max(abs(data_in(1:print_point+1)))]*1.1, ...
                                'Время (с)', 'Сигнал',plot_title, ...
                                 false, false, figure_position, true);

% Тест 4. Синус в полосе пропускания

freq = 1e6;
data_in = [zeros(1,10) (2^(Wsignal-1)-1)*sin(2*pi*freq*t)]';
data_out = quantFilterIntOutWL(data_in, taps_new, ...
    Wsignal, Wtaps, Wout, Wfinal, roundMethod);
data_in = data_in(:);
data_out = data_out(:);
fid = fopen('test4_in.txt', 'w');
fprintf(fid, '%d \n', data_in); 
fclose(fid);
fid = fopen('test4_out.txt', 'w');
fprintf(fid, '%d \n', data_out); 
fclose(fid);

plot_title = 'Тест 4 (Синус в полосе пропускания)';
legend_labels = {'In',['Out (scale /' num2str(max(abs(data_out(1:print_point+1)))/max(abs(data_in(1:print_point+1)))) ')']};
y = {data_in(1:print_point+1),data_out(1:print_point+1)*max(abs(data_in(1:print_point+1)))/max(abs(data_out(1:print_point+1)))};
createScientificPlotC(x, y, line_styles, line_widths, marker_types, marker_sizes, ...
                                line_colors, marker_edge_colors, marker_face_colors, ...
                                legend_labels, 'northeast', [0 print_point/Fs], [-max(abs(data_in(1:print_point+1))) max(abs(data_in(1:print_point+1)))]*1.1, ...
                                'Время (с)', 'Сигнал',plot_title, ...
                                 false, false, figure_position, true);

% Тест 5. Синус в переходной области
freq = 3e6;
data_in = [zeros(1,10) (2^(Wsignal-1)-1)*sin(2*pi*freq*t)]';
data_out = quantFilterIntOutWL(data_in, taps_new, ...
    Wsignal, Wtaps, Wout, Wfinal, roundMethod);
data_in = data_in(:);
data_out = data_out(:);
fid = fopen('test5_in.txt', 'w');
fprintf(fid, '%d \n', data_in); 
fclose(fid);
fid = fopen('test5_out.txt', 'w');
fprintf(fid, '%d \n', data_out); 
fclose(fid);

plot_title = 'Тест 5 (Синус в переходной полосе)';
legend_labels = {'In',['Out (scale /' num2str(max(abs(data_out(1:print_point+1)))/max(abs(data_in(1:print_point+1)))) ')']};
y = {data_in(1:print_point+1),data_out(1:print_point+1)*max(abs(data_in(1:print_point+1)))/max(abs(data_out(1:print_point+1)))};
createScientificPlotC(x, y, line_styles, line_widths, marker_types, marker_sizes, ...
                                line_colors, marker_edge_colors, marker_face_colors, ...
                                legend_labels, 'northeast', [0 print_point/Fs], [-max(abs(data_in(1:print_point+1))) max(abs(data_in(1:print_point+1)))]*1.1, ...
                                'Время (с)', 'Сигнал',plot_title, ...
                                 false, false, figure_position, true);

% Тест 6. Синус в полосе подавления
freq = 6e6;
data_in = [zeros(1,10) (2^(Wsignal-1)-1)*sin(2*pi*freq*t)]';
data_out = quantFilterIntOutWL(data_in, taps_new, ...
    Wsignal, Wtaps, Wout, Wfinal, roundMethod);
data_in = data_in(:);
data_out = data_out(:);
fid = fopen('test6_in.txt', 'w');
fprintf(fid, '%d \n', data_in); 
fclose(fid);
fid = fopen('test6_out.txt', 'w');
fprintf(fid, '%d \n', data_out); 
fclose(fid);

plot_title = 'Тест 6 (Синус в полосе задержки)';
legend_labels = {'In',['Out (scale /' num2str(max(abs(data_out(1:print_point+1)))/max(abs(data_in(1:print_point+1)))) ')']};
y = {data_in(1:print_point+1),data_out(1:print_point+1)*max(abs(data_in(1:print_point+1)))/max(abs(data_out(1:print_point+1)))};
createScientificPlotC(x, y, line_styles, line_widths, marker_types, marker_sizes, ...
                                line_colors, marker_edge_colors, marker_face_colors, ...
                                legend_labels, 'northeast', [0 print_point/Fs], [-max(abs(data_in(1:print_point+1))) max(abs(data_in(1:print_point+1)))]*1.1, ...
                                'Время (с)', 'Сигнал',plot_title, ...
                                 false, false, figure_position, true);

% Тест 7. Тест на переполнение 1
data_in = (2^(Wsignal-1))*repmat(double(sign(double(taps_newF(end:-1:1)))), 1, 20);
data_in = min(data_in,2^(Wsignal-1)-1);
data_out = quantFilterIntOutWL(data_in, taps_new, ...
     Wsignal, Wtaps, Wout, Wfinal, roundMethod);
data_in = data_in(:);
data_out = data_out(:);
fid = fopen('test7_in.txt', 'w');
fprintf(fid, '%d \n', data_in); 
fclose(fid);
fid = fopen('test7_out.txt', 'w');
fprintf(fid, '%d \n', data_out); 
fclose(fid);

plot_title = 'Тест 7 (Тест на переполнение 1)';
legend_labels = {'In',['Out (scale /' num2str(max(abs(data_out(1:print_point+1)))/max(abs(data_in(1:print_point+1)))) ')']};
y = {data_in(1:print_point+1),data_out(1:print_point+1)*max(abs(data_in(1:print_point+1)))/max(abs(data_out(1:print_point+1)))};
createScientificPlotC(x, y, line_styles, line_widths, marker_types, marker_sizes, ...
                                line_colors, marker_edge_colors, marker_face_colors, ...
                                legend_labels, 'northeast', [0 print_point/Fs], [-max(abs(data_in(1:print_point+1))) max(abs(data_in(1:print_point+1)))]*1.1, ...
                                'Время (с)', 'Сигнал',plot_title, ...
                                 false, false, figure_position, true);

% Тест 8. Тест на переполнение 2
data_in = -(2^(Wsignal-1))*repmat(double(sign(double(taps_newF(end:-1:1)))), 1, 20);
data_in = min(data_in,2^(Wsignal-1)-1);
data_out = quantFilterIntOutWL(data_in, taps_new, ...
     Wsignal, Wtaps, Wout, Wfinal, roundMethod);
data_in = data_in(:);
data_out = data_out(:);
fid = fopen('test8_in.txt', 'w');
fprintf(fid, '%d \n', data_in); 
fclose(fid);
fid = fopen('test8_out.txt', 'w');
fprintf(fid, '%d \n', data_out); 
fclose(fid);

plot_title = 'Тест 8 (Тест на переполнение 2)';
legend_labels = {'In',['Out (scale /' num2str(max(abs(data_out(1:print_point+1)))/max(abs(data_in(1:print_point+1)))) ')']};
y = {data_in(1:print_point+1),data_out(1:print_point+1)*max(abs(data_in(1:print_point+1)))/max(abs(data_out(1:print_point+1)))};
createScientificPlotC(x, y, line_styles, line_widths, marker_types, marker_sizes, ...
                                line_colors, marker_edge_colors, marker_face_colors, ...
                                legend_labels, 'northeast', [0 print_point/Fs], [-max(abs(data_in(1:print_point+1))) max(abs(data_in(1:print_point+1)))]*1.1, ...
                                'Время (с)', 'Сигнал',plot_title, ...
                                 false, false, figure_position, true);


% Тест 9. Шум
data_in = randi([-(2^(Wsignal-1)) (2^(Wsignal-1))-1],1000,1);
data_out = quantFilterIntOutWL(data_in, taps_new, ...
     Wsignal, Wtaps, Wout, Wfinal, roundMethod);
data_in = data_in(:);
data_out = data_out(:);
fid = fopen('test9_in.txt', 'w');
fprintf(fid, '%d \n', data_in); 
fclose(fid);
fid = fopen('test9_out.txt', 'w');
fprintf(fid, '%d \n', data_out); 
fclose(fid);

plot_title = 'Тест 9 (Шум)';
legend_labels = {'In',['Out (scale /' num2str(max(abs(data_out(1:print_point+1)))/max(abs(data_in(1:print_point+1)))) ')']};
y = {data_in(1:print_point+1),data_out(1:print_point+1)*max(abs(data_in(1:print_point+1)))/max(abs(data_out(1:print_point+1)))};
createScientificPlotC(x, y, line_styles, line_widths, marker_types, marker_sizes, ...
                                line_colors, marker_edge_colors, marker_face_colors, ...
                                legend_labels, 'northeast', [0 print_point/Fs], [-max(abs(data_in(1:print_point+1))) max(abs(data_in(1:print_point+1)))]*1.1, ...
                                'Время (с)', 'Сигнал',plot_title, ...
                                 false, false, figure_position, true);

% Тест 10. Использование по назначению
freq1 = 1e6;
freq2 = 6e6;
data_in = [zeros(1,10) (2^(Wsignal-1)-1)*sin(2*pi*freq1*t)+(2^(Wsignal-1)-1)*sin(2*pi*freq2*t)]';
data_out = quantFilterIntOutWL(data_in, taps_new, ...
     Wsignal, Wtaps, Wout, Wfinal, roundMethod);
data_in = data_in(:);
data_out = data_out(:);
fid = fopen('test10_in.txt', 'w');
fprintf(fid, '%d \n', data_in); 
fclose(fid);
fid = fopen('test10_out.txt', 'w');
fprintf(fid, '%d \n', data_out); 
fclose(fid);

plot_title = 'Тест 10 (Подавление одной из частот)';
legend_labels = {'In',['Out (scale /' num2str(max(abs(data_out(1:print_point+1)))/max(abs(data_in(1:print_point+1)))) ')']};
y = {data_in(1:print_point+1),data_out(1:print_point+1)*max(abs(data_in(1:print_point+1)))/max(abs(data_out(1:print_point+1)))};
createScientificPlotC(x, y, line_styles, line_widths, marker_types, marker_sizes, ...
                                line_colors, marker_edge_colors, marker_face_colors, ...
                                legend_labels, 'northeast', [0 print_point/Fs], [-max(abs(data_in(1:print_point+1))) max(abs(data_in(1:print_point+1)))]*1.1, ...
                                'Время (с)', 'Сигнал',plot_title, ...
                                 false, false, figure_position, true);





