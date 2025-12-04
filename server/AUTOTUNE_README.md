# PID Auto-Tuning Feature Implementation

## Overview
I have successfully implemented an automated PID tuning feature for the line-following robot, similar to the existing "calibra" command but focused on optimizing PID parameters rather than sensor calibration.

## New Command: `autotune`

### How it works:
1. **Command**: Send `autotune` via serial communication
2. **Prerequisites**: Robot must be in line-following mode (`set mode 1`)
3. **Process**: The robot automatically tests different PID parameter combinations while following the line
4. **Duration**: Takes several minutes to complete all tests
5. **Optimization**: Uses IAE (Integral Absolute Error) as the performance metric
6. **Safety**: Automatically aborts if robot loses the line or deviates too much

### Key Features:
- **Automatic Parameter Testing**: Tests systematic variations of Kp, Ki, Kd values around the current settings
- **Performance Metrics**: Calculates IAE (Integral Absolute Error) for each test configuration
- **Real-time Feedback**: Shows progress and results during testing
- **Safety Mechanisms**: 
  - Aborts if robot loses the line
  - Restores original values if needed
  - Can be cancelled with `reset` command
- **Auto-save**: Automatically saves the best parameters found to EEPROM
- **Visual Indicator**: LED blinks faster (200ms) during auto-tuning vs normal (100ms)

### Algorithm Details:
- **Test Duration**: 5 seconds per parameter combination
- **Test Combinations**: Systematic variations around original values:
  - Kp: 60%, 80%, 100%, 120%, 140% of original
  - Ki: 50%, 75%, 100%, 150%, 200% of original  
  - Kd: 50%, 75%, 100%, 125%, 150% of original
- **Reduced Test Set**: Optimized for faster execution (10 combinations vs full grid)
- **Best Selection**: Chooses parameters with lowest IAE score

### Command Usage:
```bash
# Set robot to line-following mode first
set mode 1

# Start auto-tuning
autotune

# Monitor progress in serial monitor
# Can cancel at any time with:
reset
```

### Sample Output:
```
type:1|Iniciando auto-tuning PID...
type:1|IMPORTANTE: El robot debe estar siguiendo una línea.
type:1|El auto-tuning puede tomar varios minutos.
type:1|Probando combinación 1/10 - Kp:0.900, Ki:0.001, Kd:0.040
type:1|Test 1/10 - IAE: 45.67 (Max dev: 234)
type:1|*** NUEVO MEJOR RESULTADO ***
type:1|Probando combinación 2/10 - Kp:1.200, Ki:0.001, Kd:0.040
...
type:1|=== AUTO-TUNING COMPLETADO ===
type:1|Mejores parámetros encontrados: Kp=1.350, Ki=0.002, Kd=0.060
type:1|IAE final: 32.45
type:1|Parámetros guardados automáticamente.
```

### Safety Features:
- **Line Loss Detection**: Automatically aborts if deviation exceeds safe thresholds
- **Original Value Backup**: Saves and restores original PID values if needed
- **Emergency Stop**: `reset` command immediately cancels and restores original values
- **Mode Validation**: Only works in line-following mode to prevent accidents

### Integration:
- Seamlessly integrated with existing command system
- Works with all existing features and filters
- Preserves all safety mechanisms of the original robot code
- No interference with normal operation when not active

This implementation provides a robust, automated way to optimize the line-following PID controller without manual trial-and-error, making the robot easier to tune for different track conditions and mechanical setups.