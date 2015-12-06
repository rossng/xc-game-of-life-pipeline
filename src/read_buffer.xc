#include <stdio.h>
#include <timer.h>
#include <stdlib.h>
#include <xscope.h>
#include "pgm.h"
#include "interfaces.h"

char *movable print_world(char *movable world, int &width_bits, int &height_bits)
{
  int bytes_per_row = (width_bits + 7) / 8;

  for (int row = 0; row < height_bits; row++)
    {
      for (int byte = 0; byte < bytes_per_row; byte++)
	{
	  char this_byte = world[row*bytes_per_row + byte];
	  for (int i = 0; i < 8; i++)
	    {
	      printf("%c ", ((this_byte >> (7-i)) & 1) == 1 ? '*' : ' ');
	    }
	}
      printf("\n");
    }

  printf("\n");

  return move(world);
}

void read_buffer(chanend workers[num_workers], unsigned num_workers,
                 server interface control_if i_control, server interface pause_if i_pause
                 )
{

  char buffer[131072] = {0};


  int round = 0;
  int paused = 0;
  unsigned int current_time;
  timer t;

  int image_width_bits = 0;
  int image_height_bits = 0;

  while (1)
    {

      printf("Round %d\n", round);

      int total_bytes = 0;

      //delay_milliseconds(2000);
      select
      {
	case i_control.start_import():
	  printf("RBUF[%d]: import started\n", round);
	  // Update the width, height and the contents of the buffer
	  read_pgm("small.pgm", image_width_bits, image_height_bits, buffer);
	  // Reset the round counter
	  round = 0;
	  printf("RBUF[%d]: import finished\n", round);
	  break;

	case i_control.start_export():
	    write_pgm("out.pgm", buffer, image_width_bits, image_height_bits);
	    printf("RBUF[%d]: export finished\n", round);
	    break;

	case i_pause.pause():
	  //printf("RBUF[%d]: paused\n", round);
	  paused = 1;
	  break;

	default:
	  break;
      }

      if (paused)
	{
	  select {
	    case i_pause.unpause():
	      paused = 0;
	      break;
	  }
	}

      if( (image_width_bits > 0) && (image_height_bits > 0))
    {

      //buffer = print_world(move(buffer), image_width_bits, image_height_bits);


      // Calculate how much of the image each worker should be given
      int slice_height = image_height_bits  / num_workers;
      int last_slice_height = image_height_bits - slice_height*(num_workers - 1);

      int bytes_per_row = (image_width_bits + 7) / 8;

      int bytes_per_worker = slice_height*bytes_per_row;
      int bytes_last_worker = last_slice_height*bytes_per_row;

      total_bytes = bytes_per_worker * (num_workers - 1) + bytes_last_worker;

      int bytes_in_image = bytes_per_worker*(num_workers-1) + bytes_last_worker;

      // Inform the workers of the width and height of their chunks
      for (int i = 0; i < num_workers - 1; i++)
	{
	  workers[i] <: image_width_bits;
	  workers[i] <: slice_height;

	}

      // Inform the last worker of its width and height, which may differ
      workers[num_workers-1] <: image_width_bits;
      workers[num_workers-1] <: last_slice_height;

      //printf("RBUF[%d]: outputted chunk width and height to all workers\n", round);

      // Distribute the row above each worker
      for (int i = 0; i < bytes_per_row; i++)
	{
	  // For the first worker, send the last row of the image
	  workers[0] <: buffer[bytes_in_image - bytes_per_row + i];

	  // For the main group of workers, send the current byte out
	  for (int j = 1; j < num_workers; j++)
	    {
	      workers[j] <: buffer[bytes_per_worker*j-bytes_per_row+i];
	    }
	}

      //printf("RBUF[%d]: outputted row above to all workers\n", round);

      // Distribute the current world to the workers
      for (int i = 0; i < bytes_per_worker; i++)
	{
	  // For the main group of workers, send the current byte out
	  for (int j = 0; j < num_workers - 1; j++)
	    {
	      workers[j] <: buffer[bytes_per_worker*j+i];
	    }

	}

      for(int i = 0; i< bytes_last_worker ; i++){

          workers[num_workers-1] <: buffer[bytes_per_worker*(num_workers-1)+i];
      }


	  // Distribute the row above each worker
      for (int i = 0; i < bytes_per_row; i++)
	{
	  // For the main group of workers, send the current byte out
	  for (int j = 0; j < (num_workers - 1); j++)
	    {
	      workers[j] <: buffer[bytes_per_worker*(j+1)+i];
	    }

	  // For the last worker, send the first row of the image
	  workers[num_workers - 1] <: buffer[i];
	}

      //printf("RBUF[%d]: outputted row below to all workers\n", round);


      char in_byte ;

      int byte_in[8] = {0};

      //Read in from the worker, overwriting the current buffer
      for( int i = 0 ; i < total_bytes ; i++ )
    {

          select
       {
              case workers[int j] :> in_byte:

                  buffer[ j * bytes_per_worker + byte_in[j] ] = in_byte;
                  byte_in[j] ++;
                  break;

       }


      }

      if(round%100 == 0){
          t :> current_time;
          printf("RBUF[%d]: time is %u\n", round, current_time);
      }

      round ++;
  }
}
}
