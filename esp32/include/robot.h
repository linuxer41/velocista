#ifndef ROBOT_H
#define ROBOT_H

#include "motor.h"
#include "sensor.h"
#include "pid.h"
#include "features.h"
#include "config.h"

class Robot {
public:
    Motor leftMotor;
    Motor rightMotor;
    PID linePid;
    PID leftPid;
    PID rightPid;
    QTR qtr;
    Features features;

    Robot();
    void init();
    void loadConfig();
    void saveConfig();
};

extern Robot robot;

#endif