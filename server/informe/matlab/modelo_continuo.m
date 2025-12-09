% Modelo continuo del motor
clc; clear; close all;

K = 0.191;      % Ganancia estática [(m/s)/V]
tau = 0.18;     % Constante de tiempo [s]
G = tf(K, [tau 1]);

% Respuesta al escalón
figure;
step(G, 1);
title('Respuesta al escalón - Modelo continuo');
xlabel('Tiempo [s]');
ylabel('Velocidad [m/s]');
grid on;