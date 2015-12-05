#include <stdio.h>
#include <xscope.h>
#include "interfaces.h"

void io(server interface io_if i_io)
{
  while (1)
    {
      select
      {
	case i_io.export(char * movable world) -> char * movable return_world:
	    //printf("IO: returning world pointer\n");
	    return_world = move(world);
	    break;
	case i_io.import(char * movable world, int &width_bits, int &height_bits) -> char * movable return_world:
	    //printf("IO: return world pointer\n");
	    width_bits = 100;
	    height_bits = 100;
	    return_world = move(world);
	    break;
      }
    }
}
