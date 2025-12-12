% Análisis de Datos Reales del Sistema
clc; clear; close all;

% Leer datos del archivo CSV
data = readtable('data.csv');

% Extraer columnas
time = data.time / 1e6; % Convertir de microsegundos a segundos
pos = data.pos;
rpmL = data.rpmL;
rpmR = data.rpmR;
lineOut = data.lineOut;
pwmL = data.pwmL;
pwmR = data.pwmR;

% Ajustar tiempo relativo al inicio
time = time - time(1);

% Gráfica 1: Posición de la línea vs tiempo
figure;
plot(time, pos);
title('Posición de la Línea vs Tiempo');
xlabel('Tiempo [s]');
ylabel('Posición [unidades]');
grid on;

% Gráfica 2: RPM de motores izquierdo y derecho vs tiempo
figure;
plot(time, rpmL, 'b-', time, rpmR, 'r--');
title('RPM de Motores vs Tiempo');
xlabel('Tiempo [s]');
ylabel('RPM');
legend('Izquierdo', 'Derecho');
grid on;

% Gráfica 3: Salida del PID de línea vs tiempo
figure;
plot(time, lineOut);
title('Salida del PID de Línea vs Tiempo');
xlabel('Tiempo [s]');
ylabel('Salida PID');
grid on;

% Gráfica 4: PWM de motores vs tiempo
figure;
plot(time, pwmL, 'b-', time, pwmR, 'r--');
title('PWM de Motores vs Tiempo');
xlabel('Tiempo [s]');
ylabel('PWM');
legend('Izquierdo', 'Derecho');
grid on;

% Cálculos de desempeño
% Error de posición (asumiendo referencia 0)
error_pos = pos - 0;
mse_pos = mean(error_pos.^2);
fprintf('MSE de posición: %.4f\n', mse_pos);

% Variabilidad de RPM
std_rpmL = std(rpmL);
std_rpmR = std(rpmR);
fprintf('Desviación estándar RPM Izquierdo: %.4f\n', std_rpmL);
fprintf('Desviación estándar RPM Derecho: %.4f\n', std_rpmR);

% Energía PWM (aproximación)
energia_pwmL = sum(abs(pwmL)) / length(pwmL);
energia_pwmR = sum(abs(pwmR)) / length(pwmR);
fprintf('Energía promedio PWM Izquierdo: %.4f\n', energia_pwmL);
fprintf('Energía promedio PWM Derecho: %.4f\n', energia_pwmR);

% Validación con modelo
% Usar el modelo continuo para comparar
num = 1650;
den = [1 330 140];
G = tf(num, den);

% Simular respuesta con entrada PWM promedio
pwm_promedio = mean((pwmL + pwmR)/2);
t_sim = 0:0.01:max(time);
[y_sim, t_sim] = step(pwm_promedio * G, t_sim);

figure;
plot(time, (rpmL + rpmR)/2, 'b-', t_sim, y_sim, 'r--');
title('Comparación Modelo vs Datos Reales');
xlabel('Tiempo [s]');
ylabel('RPM Promedio');
legend('Datos Reales', 'Modelo Simulado');
grid on;