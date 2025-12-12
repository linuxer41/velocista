% Lugar Geométrico de las Raíces - Sistema Continuo para Ajuste de K
clc; clear; close all;

% Función de transferencia de la planta (modelo identificado)
num = 1650;
den = [1 330 140];
G = tf(num, den);

% Dibujar el lugar de raíces
figure;
rlocus(G);
title('Lugar Geométrico de las Raíces - Sistema Continuo');
xlabel('Parte Real');
ylabel('Parte Imaginaria');
grid on;

% Agregar líneas de diseño: zeta = 0.5 (sobrepaso ~7%), wn = 20 rad/s (ts ~0.4s)
sgrid(0.5, 20);

% Encontrar el valor de K en el punto deseado
% Usar rlocfind para seleccionar el punto donde zeta >=0.5 y wn~20
[K, poles] = rlocfind(G);

% Mostrar resultados
fprintf('Valor de K seleccionado: %.4f\n', K);
fprintf('Polos en lazo cerrado: %.4f + %.4fj, %.4f - %.4fj\n', real(poles(1)), imag(poles(1)), real(poles(2)), imag(poles(2)));

% Simular respuesta al escalón con el K obtenido
sys_cl = feedback(K * G, 1);
figure;
step(sys_cl);
title('Respuesta al Escalón - Sistema en Lazo Cerrado con K Ajustado');
xlabel('Tiempo [s]');
ylabel('Velocidad [rad/s]');
grid on;

% Calcular sobrepaso y tiempo de establecimiento
info = stepinfo(sys_cl);
fprintf('Sobrepaso: %.2f%%\n', info.Overshoot);
fprintf('Tiempo de establecimiento (2%%): %.4f s\n', info.SettlingTime);