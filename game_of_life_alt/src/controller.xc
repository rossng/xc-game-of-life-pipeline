#include <stdio.h>
#include <timer.h>
#include <stdlib.h>
#include <xs1.h>
#include <xscope.h>
#include "interfaces.h"

void controller(in port buttons, client interface control_if i_control)
{
    int buttons_value = 0;

    printf("CON: starting\n");

    while (1)
      {
        buttons when pinseq(15) :> buttons_value;
	printf("CON: read button value %d\n", buttons_value);
        buttons when pinsneq(15) :> buttons_value;
	printf("CON: read button value %d\n", buttons_value);

        if (buttons_value == 14)
          {
            i_control.start_export();
            printf("CON: sent export trigger\n");
          }
        else if (buttons_value == 13)
          {
            i_control.start_import();
            printf("CON: sent import trigger\n");
          }
      }
}
