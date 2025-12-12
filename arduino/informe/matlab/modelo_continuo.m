% Modelo continuo del motor (segundo orden identificado)
clc; clear; close all;

num = 1650;
den = [1 330 140];
G = tf(num, den);

% Respuesta al escalón
figure;
step(G, 1);
title('Respuesta al escalón - Modelo continuo (segundo orden)');
xlabel('Tiempo [s]');
ylabel('Velocidad [rad/s]');
grid on;