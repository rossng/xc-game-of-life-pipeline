#include <stdio.h>
#include <timer.h>
#include <stdlib.h>
#include <xscope.h>
#include <xs1.h>
#include <platform.h>
#include "interfaces.h"

#define NUM_WORKERS 4

on tile[0]: in port p_btn = XS1_PORT_4E;
//port p_sda = XS1_PORT_1F;
//port p_led = XS1_PORT_4F;

char buffer0[1000] = {0};
char buffer1[1000] = {0,1,2,3,4,5,6,7};

void xscope_user_init(void)
{
   xscope_register(0, 0, "", 0, "");
   xscope_config_io(XSCOPE_IO_TIMED);
}

int coords_to_bit_index(int width, int height, int x, int y)
{
  // Wrap x to the other side if it goes off the edge of the grid
  if (x < 0) { x = width + x; }
  if (x >= width) { x = x - width; }
  return 8*((width + 7)/8)*(y+1) + x;
}

int bit_index_to_byte_index(int width, int height, int bit_index)
{
  return bit_index/8;
}

int bit_index_to_bit_offset(int width, int height, int bit_index)
{
  return bit_index%8;
}

int is_live(char world_chunk[], int chunk_width_bits, int chunk_height_bits, int x, int y) {
  int bit_index = coords_to_bit_index(chunk_width_bits, chunk_height_bits, x, y);

  int byte_index = bit_index_to_byte_index(chunk_width_bits, chunk_height_bits, bit_index);
  int bit_offset = bit_index_to_bit_offset(chunk_width_bits, chunk_height_bits, bit_index);

  return (world_chunk[byte_index] >> (7 - bit_offset)) & 1;
}

char get_next_round(char world_chunk[], int width_bits, int height_bits, int x, int y)
{
  int live_neighbours = 0;
  live_neighbours += is_live(world_chunk, width_bits, height_bits, x-1, y-1);
  live_neighbours += is_live(world_chunk, width_bits, height_bits, x-1, y);
  live_neighbours += is_live(world_chunk, width_bits, height_bits, x-1, y+1);
  live_neighbours += is_live(world_chunk, width_bits, height_bits, x, y-1);
  live_neighbours += is_live(world_chunk, width_bits, height_bits, x-1, y+1);
  live_neighbours += is_live(world_chunk, width_bits, height_bits, x+1, y-1);
  live_neighbours += is_live(world_chunk, width_bits, height_bits, x+1, y);
  live_neighbours += is_live(world_chunk, width_bits, height_bits, x+1, y+1);

  if (is_live(world_chunk, width_bits, height_bits, x, y))
    {
      if (live_neighbours == 2 || live_neighbours == 3)
        {
          return 1;
        }
    }
  else
    {
      if (live_neighbours == 3) {
	  return 1;
      }
    }

  return 0;
}

// TODO: wraparound

void worker(streaming chanend write_buffer, streaming chanend read_buffer, int id)
{
  char world_chunk[1000] = {0};
  int chunk_width_bits = 0;
  int chunk_height_bits = 0;
  int chunk_width_bits_bytes = 0;
  int chunk_bytes = 0;

  while (1)
    {
      // Read in the width and height of the world chunk to be processed
      read_buffer :> chunk_width_bits;
      read_buffer :> chunk_height_bits;

      printf("W[%d]: inputted width %d and height %d\n", id, chunk_width_bits, chunk_height_bits);

      // Calculate how many bytes are expected to be read in per row
      // Cell liveness is packed as 8-per-byte
      chunk_width_bits_bytes = (chunk_width_bits + 7) / 8;
      chunk_bytes = chunk_height_bits*((chunk_width_bits + 7) / 8);

      int current_index = 0;

      // Read in the row above this chunk
      for (int i = 0; i < chunk_width_bits_bytes; i++)
	{
	  read_buffer :> world_chunk[current_index++];
	}

      printf("W[%d]: inputted row above\n", id);

      // Read in the chunk of the world that this worker is responsible for
      for (int i = 0; i < chunk_bytes; i++)
	{
	  read_buffer :> world_chunk[current_index++];
	  printf("W[%d]: inputted world byte %d\n", id, i);
	}

      // Read in the row below this chunk
      for (int i = 0; i < chunk_width_bits_bytes; i++)
	{
	  read_buffer :> world_chunk[current_index++];
	}

      printf("W[%d]: inputted row below\n", id);

      // Update each bit in the chunk
      char temp_byte = 0;
      for (int y = 0; y < chunk_height_bits; y++)
	{
	  // Write out the contents of the current row to the write buffer
	  for (int x = 0; x < chunk_width_bits; x++)
	    {
	      // Index of the bit representing the cell at the specified co-ordinates
	      int bit_index = y*chunk_width_bits + x;

	      // State of the bit in the next round
	      char current_bit_next_round = get_next_round(world_chunk, chunk_width_bits, chunk_height_bits, x, y);

	      // Write the bit to the correct place in the current byte
	      temp_byte |= current_bit_next_round << (7 - bit_index%8);

	      // If we've finished calculating a byte, write it out to the buffer
	      if (bit_index%8 == 7)
		{
		  write_buffer <: temp_byte;
		  temp_byte = 0;
		  printf("W[%d]: outputted byte %d\n", id, bit_index/8);
		}
	    }

	  // If the row does not divide exactly into bytes, write out the final byte
	  if (chunk_width_bits%8 != 0)
	    {
	      write_buffer <: temp_byte;
	    }
	}
    }
}

void write_buffer(streaming chanend workers[num_workers], unsigned num_workers, client interface bufswap_if i_bufswap,
                  char initial_buffer[n], unsigned n, streaming chanend c_rb)
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

	int bytes_received_for_worker[100] = {0};

	// Read in the expected amount of data from each worker
	int workers_finished_receiving = 0;
	while (workers_finished_receiving < num_workers) {
	  select
	  {
	    case(size_t i = 0; i < num_workers; i++)
	      bytes_received_for_worker[i] < ((i == num_workers - 1) ? bytes_last_worker : bytes_per_worker) => workers[i] :> char byte:
		buffer[i*bytes_per_worker + bytes_received_for_worker[i]] = byte;
		printf("WBUF: inputted byte %d from worker %d\n", bytes_received_for_worker[i], i);
		bytes_received_for_worker[i]++;
		if (bytes_received_for_worker[i] == ((i == num_workers - 1) ? bytes_last_worker : bytes_per_worker)) {
		    workers_finished_receiving++;
		}
		break;
	  }
	}

	// Send the new frame to the read buffer and get ready to write the next frame
	printf("WBUF: requesting buffer swap\n");
	i_bufswap.swap(buffer);
    }

}

{int, int} get_cell_range_for_worker(int image_height, int worker_id, int num_workers)
{
  int slice_size = (image_height + num_workers - 1) / num_workers;

  return
    {
      (worker_id*slice_size),
      (worker_id == (num_workers-1)) ? image_height : worker_id*slice_size + slice_size
    };
}

void read_buffer(streaming chanend workers[num_workers], unsigned num_workers, server interface bufswap_if i_bufswap,
                 server interface control_if i_control, char initial_buffer[n], unsigned n, int image_width_bits, int image_height_bits,
                 streaming chanend c_wb)
{
    char *movable buffer = &initial_buffer[0];
    int round = 0;
    while (1)
      {
	select
	{
	  case i_control.start_import():
	    printf("RBUF[%d]: import started", round);
	    // Update the width, height and the contents of the buffer

	    // Reset the round counter
	    round = 0;
	    while(1){}
	    break;

	  case i_control.start_export():
	    printf("RBUF[%d]: export started", round);
	    // Hand the buffer pointer to the export process
	    // Get the buffer pointer back from the export process
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

void controller(in port buttons, client interface control_if i_control)
{
    int buttons_value;

    while (1)
      {
        buttons when pinseq(15) :> buttons_value;
        buttons when pinsneq(15) :> buttons_value;

        if (buttons_value == 14)
          {
            printf("CON: sending export trigger\n");
            i_control.start_export();
            printf("CON: sent export trigger\n");
          }
        else if (buttons_value == 13)
          {
            printf("CON: sending import trigger\n");
            i_control.start_import();
            printf("CON: sent import trigger\n");
          }
      }
}

int main(void)
{
    interface bufswap_if i_bufswap;
    interface control_if i_control;
    streaming chan c_wb_w[NUM_WORKERS];
    streaming chan c_rb_w[NUM_WORKERS];
    streaming chan c_rb_wb;

    par
      {
	on tile[0]: controller(p_btn, i_control);
	par (size_t i = 0; i < NUM_WORKERS; i++)
	  {
	    on tile[i%2]: worker(c_wb_w[i], c_rb_w[i], i);
	  }
	on tile[0]: write_buffer(c_wb_w, NUM_WORKERS, i_bufswap, buffer0, 1000, c_rb_wb);
	on tile[0]: read_buffer(c_rb_w, NUM_WORKERS, i_bufswap, i_control, buffer1, 1000, 25, 25, c_rb_wb);
      }
    return 0;
}
