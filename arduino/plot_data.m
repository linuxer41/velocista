% Script de MATLAB para graficar datos del seguidor de línea desde CSV
% Cargar los datos
data = readtable('data.csv');

% Extraer columnas
time = data.time;
pos = data.pos;
rpmL = data.rpmL;
rpmR = data.rpmR;
lineOut = data.lineOut;
pwmL = data.pwmL;
pwmR = data.pwmR;

% Convertir tiempo a segundos (asumiendo microsegundos)
time_s = time / 1e6;

% Crear figura con subplots
figure;

% Respuesta escalón de posición de línea
subplot(2,2,1);
plot(time_s, pos);
title('Respuesta Escalón de Posición de Línea');
xlabel('Tiempo (s)');
ylabel('Posición');
grid on;

% Respuesta escalón de RPM
subplot(2,2,2);
plot(time_s, rpmL, 'b-', 'LineWidth', 1.5);
hold on;
plot(time_s, rpmR, 'r-', 'LineWidth', 1.5);
title('Respuesta Escalón de RPM');
xlabel('Tiempo (s)');
ylabel('RPM');
legend('Izquierda', 'Derecha');
grid on;

% Entrada PWM
subplot(2,2,3);
plot(time_s, pwmL, 'b-', 'LineWidth', 1.5);
hold on;
plot(time_s, pwmR, 'r-', 'LineWidth', 1.5);
title('Entrada PWM');
xlabel('Tiempo (s)');
ylabel('PWM');
legend('Izquierda', 'Derecha');
grid on;

% Salida de línea
subplot(2,2,4);
plot(time_s, lineOut);
title('Salida de Línea');
xlabel('Tiempo (s)');
ylabel('Salida');
grid on;

% Ajustar diseño
sgtitle('Análisis del Sistema Seguidor de Línea');