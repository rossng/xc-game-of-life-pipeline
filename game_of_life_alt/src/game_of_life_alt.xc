#include <stdio.h>
#include <timer.h>
#include <stdlib.h>
#include <xscope.h>
#include <xs1.h>
#include <platform.h>
#include "interfaces.h"
#include "write_buffer.h"
#include "read_buffer.h"
#include "io.h"
#include "controller.h"
#include "worker.h"
#include "i2c.h"
#include "accelerometer_defs.h"

#define NUM_WORKERS 3

in port p_btn = XS1_PORT_4E;
port p_scl = XS1_PORT_1E;
port p_sda = XS1_PORT_1F;
port p_led = XS1_PORT_4F;

char buffer0[30000] = {0};
char buffer1[30000] = {0,1,2,3,4,5,6,7};

void xscope_user_init(void)
{
   //xscope_register(0, 0, "", 0, "");
   //xscope_config_io(XSCOPE_IO_TIMED);
}

int main(void)
{
  interface bufswap_if i_bufswap;
  interface pause_if i_pause;
  interface control_if i_control;
  interface i2c_master_if i_i2c[1];
  interface io_if i_io;
  chan c_wb_w[NUM_WORKERS];
  chan c_rb_w[NUM_WORKERS];
  chan c_rb_wb;

  //xscope_user_init();

  par
    {
      io(i_io);
      pauser(i_pause, i_i2c[0]);
      controller(p_btn, i_control);
      i2c_master(i_i2c, 1, p_scl, p_sda, 10);
      par (unsigned i = 0; i < NUM_WORKERS; i++)
	{
	  worker(c_wb_w[i], c_rb_w[i], i);
	}
      write_buffer(c_wb_w, NUM_WORKERS, i_bufswap, buffer0, 30000, c_rb_wb);
      read_buffer(c_rb_w, NUM_WORKERS, i_bufswap, i_control, i_pause, i_io, buffer1, 30000, 25, 25, c_rb_wb);
    }
  return 0;
}
