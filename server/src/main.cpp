#include "config.h"
#include "robot.h"

Robot robot;

void setup() {
    robot.init();
}

void loop() {
    robot.run();
}