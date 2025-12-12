% Identificación de parámetros del motor para izquierda y derecha
clc; clear; close all;

% Leer datos
data = readtable('../../data.csv');

% Extraer columnas
time_us = data.time; % microsegundos
rpmL = data.rpmL;
rpmR = data.rpmR;
pwmL = data.pwmL;
pwmR = data.pwmR;

% Convertir tiempo a segundos
time = time_us / 1e6;
time = time - time(1); % relativo al inicio

% Convertir RPM a rad/s
omegaL = rpmL * 2 * pi / 60;
omegaR = rpmR * 2 * pi / 60;

% Asumir Vbat = 8.4 V (nominal)
Vbat = 8.4;
% Voltaje aplicado Va = (pwm / 255) * Vbat
VaL = (pwmL / 255) * Vbat;
VaR = (pwmR / 255) * Vbat;

% Crear objetos iddata para identificación
% Para motor izquierdo
Ts = mean(diff(time)); % período de muestreo aproximado
data_id_L = iddata(omegaL, VaL, Ts);
data_id_R = iddata(omegaR, VaR, Ts);

% Estimar función de transferencia de orden 3 (como el modelo)
% G(s) = K / (a s^3 + b s^2 + c s)
np = 3; % orden numerador
dp = 3; % orden denominador
G_est_L = tfest(data_id_L, np, dp);
G_est_R = tfest(data_id_R, np, dp);

% Mostrar funciones estimadas
disp('Función de transferencia estimada para motor izquierdo:');
G_est_L
disp('Función de transferencia estimada para motor derecho:');
G_est_R

% Extraer coeficientes
[num_L, den_L] = tfdata(G_est_L, 'v');
[num_R, den_R] = tfdata(G_est_R, 'v');

% El modelo es G(s) = Km / (La J s^3 + (La B + Ra J) s^2 + (Ra B + Ka Km) s)
% Coeficientes: den = [La J, La B + Ra J, Ra B + Ka Km]
% num = [Km]

% Parámetros conocidos
Ra = 12.6; % Ohm
La = 0.0025; % H

% Para motor izquierdo
Km_L = num_L(1);
a_L = den_L(1);
b_L = den_L(2);
c_L = den_L(3);

% Resolver para J, B, Ka
% a = La * J
J_L = a_L / La;

% b = La * B + Ra * J
% c = Ra * B + Ka * Km

% De b: La * B + Ra * J = b => B = (b - Ra * J) / La
B_L = (b_L - Ra * J_L) / La;

% De c: Ra * B + Ka * Km = c => Ka = (c - Ra * B) / Km
Ka_L = (c_L - Ra * B_L) / Km_L;

% Similar para derecho
Km_R = num_R(1);
a_R = den_R(1);
b_R = den_R(2);
c_R = den_R(3);

J_R = a_R / La;
B_R = (b_R - Ra * J_R) / La;
Ka_R = (c_R - Ra * B_R) / Km_R;

% Mostrar parámetros
fprintf('\nParámetros del motor izquierdo:\n');
fprintf('J = %.6f kg·m²\n', J_L);
fprintf('B = %.6f N·m·s\n', B_L);
fprintf('Ka = %.6f V·s/rad\n', Ka_L);
fprintf('Km = %.6f N·m/A\n', Km_L);
fprintf('Ra = %.6f Ω\n', Ra);
fprintf('La = %.6f H\n', La);

fprintf('\nParámetros del motor derecho:\n');
fprintf('J = %.6f kg·m²\n', J_R);
fprintf('B = %.6f N·m·s\n', B_R);
fprintf('Ka = %.6f V·s/rad\n', Ka_R);
fprintf('Km = %.6f N·m/A\n', Km_R);
fprintf('Ra = %.6f Ω\n', Ra);
fprintf('La = %.6f H\n', La);

% Validar: comparar respuesta simulada vs real
figure;
subplot(2,1,1);
plot(time, omegaL, 'b', time, lsim(G_est_L, VaL, time), 'r--');
title('Motor Izquierdo: Datos vs Modelo Estimado');
xlabel('Tiempo [s]');
ylabel('Velocidad Angular [rad/s]');
legend('Datos', 'Modelo');

subplot(2,1,2);
plot(time, omegaR, 'b', time, lsim(G_est_R, VaR, time), 'r--');
title('Motor Derecho: Datos vs Modelo Estimado');
xlabel('Tiempo [s]');
ylabel('Velocidad Angular [rad/s]');
legend('Datos', 'Modelo');