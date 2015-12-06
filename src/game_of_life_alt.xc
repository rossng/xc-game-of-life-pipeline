#include <stdio.h>
#include <timer.h>
#include <stdlib.h>
#include <xscope.h>
#include <xs1.h>
#include <platform.h>
#include "interfaces.h"
#include "read_buffer.h"
#include "io.h"
#include "controller.h"
#include "worker.h"
#include "i2c.h"
#include "accelerometer_defs.h"
#include "settings.h"

on tile[0]: in port p_btn = XS1_PORT_4E;
on tile[0]: port p_scl = XS1_PORT_1E;
on tile[0]: port p_sda = XS1_PORT_1F;
//port p_led = XS1_PORT_4F;

char buffer0[BUFFER_SIZE] = {0};

void xscope_user_init(void)
{
   //xscope_register(0, 0, "", 0, "");
   //xscope_config_io(XSCOPE_IO_TIMED);
}

int main(void)
{
  //interface bufswap_if i_bufswap;
  interface pause_if i_pause;
  interface control_if i_control;
  interface i2c_master_if i_i2c[1];
  interface io_if i_io;
  //chan c_wb_w[NUM_WORKERS];
  chan c_rb_w[NUM_WORKERS];
  //chan c_rb_wb;

  //xscope_user_init();

  par
    {
      on tile[0]: io(i_io);
      on tile[0]: pauser(i_pause, i_i2c[0]);
      on tile[0]: controller(p_btn, i_control);
      on tile[0]: i2c_master(i_i2c, 1, p_scl, p_sda, 10);
      par (unsigned i = 0; i < NUM_WORKERS; i++)
	{
	  on tile[1]: worker(c_rb_w[i], i);
	}
      //on tile[0]: write_buffer(c_wb_w, NUM_WORKERS, i_bufswap, buffer0, BUFFER_SIZE, c_rb_wb);
      on tile[0]: read_buffer(c_rb_w, NUM_WORKERS, i_control, i_pause, i_io, buffer0, BUFFER_SIZE, 25, 25);
    }
  return 0;
}
