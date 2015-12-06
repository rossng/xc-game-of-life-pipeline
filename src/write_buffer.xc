#include <stdio.h>
#include <timer.h>
#include <stdlib.h>
#include <xscope.h>
#include "interfaces.h"
#include "settings.h"

void write_buffer(chanend workers[num_workers], unsigned num_workers, client interface bufswap_if i_bufswap,
                  char initial_buffer[n], unsigned n, chanend c_rb)
{
    char *movable buffer = &initial_buffer[0];
    int image_width_bits = 0;
    int image_height_bits = 0;

    while (1)
      {
	// Get the size of the next frame from the read buffer
	c_rb :> image_width_bits;
	c_rb :> image_height_bits;

	// Calculate the various sizes expected
	int slice_height = (image_height_bits + num_workers - 1) / num_workers;
	int last_slice_height = image_height_bits - slice_height*(num_workers - 1);

	int bytes_per_worker = slice_height*((image_width_bits + 7) / 8);
	int bytes_last_worker = last_slice_height*((image_width_bits + 7) / 8);

	int bytes_received_for_worker[NUM_WORKERS] = {0};

	// Read in the expected amount of data from each worker
	int workers_finished_receiving = 0;
	while (workers_finished_receiving < num_workers) {
	  select
	  {
	      case(unsigned i = 0; i < num_workers; i++)
		bytes_received_for_worker[i] < ((i == num_workers - 1) ? bytes_last_worker : bytes_per_worker) => workers[i] :> char byte:
		  buffer[i*bytes_per_worker + bytes_received_for_worker[i]] = byte;
		  //printf("WBUF: inputted byte %d from worker %d\n", bytes_received_for_worker[i], i);
		  bytes_received_for_worker[i]++;
		  if (bytes_received_for_worker[i] == ((i == num_workers - 1) ? bytes_last_worker : bytes_per_worker)) {
		      workers_finished_receiving++;
		  }
		  break;
	  }
	}

	// Send the new frame to the read buffer and get ready to write the next frame
	//printf("WBUF: requesting buffer swap\n");
	i_bufswap.swap(buffer);
    }
}
