% Parámetros PID
Kp = 1.2;
Ki = 0.05;
Kd = 0.08;
T = 0.05;

% Controlador PID discreto
C = pid(Kp, Ki, Kd, 'Ts', T);

% Lazo cerrado
sys_cl = feedback(C * Gz, 1);

% Respuesta al escalón
figure;
step(sys_cl, 1);
title('Respuesta al escalón - Lazo cerrado con PID');
xlabel('Tiempo [s]');
ylabel('Velocidad [m/s]');
grid on;