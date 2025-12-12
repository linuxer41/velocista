% Script de MATLAB para diagrama de Bode y análisis de lugar geométrico de raíces
% Esta es una plantilla - necesitas identificar la función de transferencia de tu sistema

% Función de transferencia de ejemplo para un sistema de motor (ajusta parámetros basados en tu sistema)
% Asumir G(s) = K / (s^2 + a*s + b) - planta del motor
% C(s) = Kp + Ki/s + Kd*s - controlador PID

% Parámetros de ejemplo (necesitas identificar estos desde tus datos)
K = 1;      % Ganancia de la planta
a = 0.1;    % Coeficiente de amortiguamiento
b = 0.01;   % Frecuencia natural al cuadrado
Kp = 0.55;  % Ganancia proporcional
Ki = 0.0014; % Ganancia integral
Kd = 0.015;  % Ganancia derivativa

% Función de transferencia de la planta
num_plant = K;
den_plant = [1, a, b];
G = tf(num_plant, den_plant);

% Controlador PID
num_pid = [Kd, Kp, Ki];
den_pid = [1, 0];
C = tf(num_pid, den_pid);

% Función de transferencia en lazo abierto
G_open = C * G;

% Función de transferencia en lazo cerrado
G_closed = feedback(G_open, 1);

% Lugar geométrico de raíces
figure;
rlocus(G_open);
title('Lugar Geométrico de Raíces');
grid on;

% Diagrama de Bode
figure;
bode(G_open);
title('Diagrama de Bode');
grid on;

% Respuesta escalón en lazo cerrado
figure;
step(G_closed);
title('Respuesta Escalón en Lazo Cerrado');
grid on;

% Mostrar información del sistema
disp('Función de Transferencia en Lazo Abierto:');
G_open
disp('Polos en Lazo Cerrado:');
pole(G_closed)
disp('Ceros en Lazo Cerrado:');
zero(G_closed)