#include <stdio.h>
#include "interfaces.h"
#include "pgm.h"

/*void io(server interface io_if i_io)
{
  while (1)
    {
      select
      {
	case i_io.export(char * movable world, int width_bits, int height_bits) -> char * movable return_world:
	    //printf("IO: returning world pointer\n");
	    write_pgm("out.pgm", world, width_bits, height_bits);
	    return_world = move(world);
	    break;
	case i_io.import(char * movable world, int &width_bits, int &height_bits) -> char * movable return_world:
	    //printf("IO: return world pointer\n");
	    read_pgm("small.pgm", width_bits, height_bits, world);
	    return_world = move(world);
	    break;
      }
    }
}*/
