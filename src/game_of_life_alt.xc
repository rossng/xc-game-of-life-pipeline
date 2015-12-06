#include <stdio.h>
#include <timer.h>
#include <stdlib.h>
#include <xscope.h>
#include <xs1.h>
#include <platform.h>
#include "interfaces.h"
#include "read_buffer.h"
#include "controller.h"
#include "worker.h"
#include "i2c.h"
#include "accelerometer_defs.h"
#include "settings.h"




on tile[0]: in port p_btn = XS1_PORT_4E;
on tile[0]: port p_scl = XS1_PORT_1E;
on tile[0]: port p_sda = XS1_PORT_1F;
on tile[0]: port p_led = XS1_PORT_4F;


void xscope_user_init(void)
{
   //xscope_register(0, 0, "", 0, "");
   //xscope_config_io(XSCOPE_IO_TIMED);
}

int main(void)
{

  interface pause_if i_pause;
  interface control_if i_control;
  interface i2c_master_if i_i2c[1];

  chan c_rb_w[NUM_WORKERS];


  //xscope_user_init();

  par
    {


      on tile[0] :pauser(i_pause, i_i2c[0]);
      on tile[0] :controller(p_btn, i_control);
      on tile[0] :i2c_master(i_i2c, 1, p_scl, p_sda, 10);


	  on tile[1] : worker( c_rb_w[0], 0);
	  on tile[1] : worker( c_rb_w[1], 1);
	  on tile[1] : worker( c_rb_w[2], 2);
	  on tile[0] : worker( c_rb_w[3], 3);
	  on tile[0] : worker( c_rb_w[4], 4);
	  on tile[0] : worker( c_rb_w[5], 5);
	  on tile[0] : worker( c_rb_w[6], 6);
	  on tile[0] : worker( c_rb_w[7], 7);

      on tile[1] : read_buffer(c_rb_w, NUM_WORKERS,  i_control, i_pause );

    }

  return 0;
}
