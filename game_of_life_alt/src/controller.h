#include "interfaces.h"
#include "i2c.h"

#ifndef CONTROLLER_H_
#define CONTROLLER_H_

void pauser(client interface pause_if i_pause, client interface i2c_master_if i2c);
void controller(in port buttons, client interface control_if i_control);

#endif /* CONTROLLER_H_ */
