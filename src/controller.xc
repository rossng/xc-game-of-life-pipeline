#include <stdio.h>
#include <timer.h>
#include <stdlib.h>
#include <xs1.h>
#include <xscope.h>
#include "interfaces.h"
#include "accelerometer_defs.h"
#include "i2c.h"

int read_acceleration(client interface i2c_master_if i2c, int reg) {
    i2c_regop_res_t result;
    int accel_val = 0;
    unsigned char data = 0;

    // Read MSB data
    data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, reg, result);
    if (result != I2C_REGOP_SUCCESS) {
        printf("Failed to read MSB data\n");
        return 0;
    }

    accel_val = data << 2;

    // Read LSB data
    data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, reg+1, result);
    if (result != I2C_REGOP_SUCCESS) {
        printf("Failed to read LSB data\n");
      return 0;
    }

    accel_val |= (data >> 6);

    if (accel_val & 0x200) {
      accel_val -= 1023;
    }

    return accel_val;
}

void pauser(client interface pause_if i_pause, client interface i2c_master_if i2c)
{
  i2c_regop_res_t result;
  char status_data = 0;
  int isTilted = 0;
  int wasTilted = 0;

  // Configure FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
  if (result != I2C_REGOP_SUCCESS)
    {
      printf("PSR: I2C write reg failed\n");
    }

  // Enable FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
  if (result != I2C_REGOP_SUCCESS)
    {
      printf("PSR: I2C write reg failed\n");
    }

  while (1)
    {
      //printf("PSR: Waiting for accelerometer data\n");
      //check until new accelerometer data is available
      do
	{
	  status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
	}
      while (!status_data & 0x08);

      //printf("PSR: Reading new accelerometer data\n");

      // get new x-axis tilt value
      int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);
      int y = read_acceleration(i2c, FXOS8700EQ_OUT_Y_MSB);

      //printf("PSR: Finished reading new accelerometer data\n");

      wasTilted = isTilted;

      if (x > 90 || x < -90 || y > 90 || y < -90)
	{
	  isTilted = 1;
	}
      else
	{
	  isTilted = 0;
	}

      if (isTilted && !wasTilted)
	{
	  printf("PSR: Pausing\n");
	  i_pause.pause();
	  //printf("PSR: Paused\n");
	}
      else if (!isTilted && wasTilted)
	{
	  printf("PSR: Unpausing\n");
	  i_pause.unpause();
	}
    }
}

void controller(in port buttons, client interface control_if i_control)
{
  int buttons_value = 0;

  //printf("CON: starting\n");
  while (1)
    {
      buttons when pinseq(15) :> buttons_value;
      //printf("CON: read button value %d\n", buttons_value);
      buttons when pinsneq(15) :> buttons_value;
      //printf("CON: read button value %d\n", buttons_value);

      if (buttons_value == 14)
	{
	  i_control.start_export();
	  //printf("CON: sent export trigger\n");
	}
      else if (buttons_value == 13)
	{
	  i_control.start_import();
	  //printf("CON: sent import trigger\n");
	}
    }
}
