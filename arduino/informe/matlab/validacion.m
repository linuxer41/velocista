% Datos experimentales (ejemplo)
tiempo_real = [0 0.05 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8];
velocidad_real = [0 0.08 0.15 0.25 0.32 0.36 0.38 0.39 0.39 0.39];

% Simulación modelo
t = 0:0.01:0.8;
u = ones(size(t)) * 3;  % Escalón de 3V
y = lsim(G, u, t);

figure;
plot(tiempo_real, velocidad_real, 'ro', 'DisplayName', 'Real');
hold on;
plot(t, y, 'b-', 'DisplayName', 'Modelo');
title('Validación: Modelo vs Real');
xlabel('Tiempo [s]');
ylabel('Velocidad [m/s]');
legend show;
grid on;