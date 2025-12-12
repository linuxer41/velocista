% Modelo discreto
num = 1650;
den = [1 330 140];
G = tf(num, den);
T = 0.05;  % Periodo de muestreo
Gz = c2d(G, T, 'zoh');

figure;
rlocus(Gz);
title('Lugar de raíces - Sistema discreto');
grid on;