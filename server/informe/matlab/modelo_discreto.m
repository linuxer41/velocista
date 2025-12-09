% Modelo discreto
T = 0.05;  % Periodo de muestreo
Gz = c2d(G, T, 'zoh');

figure;
rlocus(Gz);
title('Lugar de raíces - Sistema discreto');
grid on;