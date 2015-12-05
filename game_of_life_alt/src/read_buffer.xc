#include <stdio.h>
#include <timer.h>
#include <stdlib.h>
#include <xscope.h>
#include "interfaces.h"

void read_buffer(streaming chanend workers[num_workers], unsigned num_workers, server interface bufswap_if i_bufswap,
                 server interface control_if i_control, client interface io_if i_io, char initial_buffer[n], unsigned n,
                 int image_width_bits, int image_height_bits, streaming chanend c_wb)
{
    char *movable buffer = &initial_buffer[0];
    int round = 0;
    while (1)
      {
	select
	{
	  case i_control.start_import():
	    printf("RBUF[%d]: import started\n", round);
	    // Update the width, height and the contents of the buffer
	    buffer = i_io.import(move(buffer), image_width_bits, image_height_bits);
	    // Reset the round counter
	    round = 0;
	    printf("RBUF[%d]: import finished\n", round);
	    break;

	  case i_control.start_export():
	    printf("RBUF[%d]: export started\n", round);
	    // Hand the buffer pointer to the export process
	    buffer = i_io.export(move(buffer));
	    // Get the buffer pointer back from the export process
	    printf("RBUF[%d]: export finished\n", round);
	    while(1){}
	    break;

	  case i_control.pause():
	    // Wait here until the unpause signal is received
	    select {
	      case i_control.unpause():
		break;
	    }
	    break;

	  default:
	    break;
	}

	// Send the expected width and height of the next frame to the write buffer
	c_wb <: image_width_bits;
	c_wb <: image_height_bits;

	// Calculate how much of the image each worker should be given
	int slice_height = (image_height_bits + num_workers - 1) / num_workers;
	int last_slice_height = image_height_bits - slice_height*(num_workers - 1);

	int bytes_per_row = (image_width_bits + 7) / 8;

	int bytes_per_worker = slice_height*bytes_per_row;
	int bytes_last_worker = last_slice_height*bytes_per_row;

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

	printf("RBUF[%d]: outputted chunk width and height to all workers\n", round);

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

	printf("RBUF[%d]: outputted row above to all workers\n", round);

	// Distribute the current world to the workers
	for (int i = 0; i < bytes_per_worker; i++)
	  {
	    // For the main group of workers, send the current byte out
	    for (int j = 0; j < num_workers - 1; j++)
	      {
		workers[j] <: buffer[bytes_per_worker*j+i];
	      }

	    // Send the current byte out to the last worker if it still has data remaining
	    if (i < bytes_last_worker)
	      {
		workers[num_workers-1] <: buffer[bytes_per_worker*(num_workers-1)+i];
	      }

	    printf("RBUF[%d]: outputted byte %d to all workers\n", round, i);
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

	printf("RBUF[%d]: outputted row below to all workers\n", round);

	// Once the write buffer has filled up, it will request a swap
	// Wait for that request to come in:
	select
	{
	  case i_bufswap.swap(char * movable &display_buffer):
	      char * movable tmp;
	      tmp = move(display_buffer);
	      display_buffer = move(buffer);
	      buffer = move(tmp);
	      printf("RBUF[%d]: buffer swapped\n", round);
	      // The read buffer now represents the next round
	      round++;
	      break;
	}

	printf("RBUF[%d]\n", round);
      }
}
