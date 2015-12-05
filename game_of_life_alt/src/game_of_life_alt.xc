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

#define NUM_WORKERS 4

in port p_btn = XS1_PORT_4E;
//port p_sda = XS1_PORT_1F;
//port p_led = XS1_PORT_4F;

char buffer0[10000] = {0};
char buffer1[10000] = {0,1,2,3,4,5,6,7};

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

{int, int} get_cell_range_for_worker(int image_height, int worker_id, int num_workers)
{
  int slice_size = (image_height + num_workers - 1) / num_workers;

  return
    {
      (worker_id*slice_size),
      (worker_id == (num_workers-1)) ? image_height : worker_id*slice_size + slice_size
    };
}

int main(void)
{
    interface bufswap_if i_bufswap;
    interface control_if i_control;
    interface io_if i_io;
    streaming chan c_wb_w[NUM_WORKERS];
    streaming chan c_rb_w[NUM_WORKERS];
    streaming chan c_rb_wb;

    xscope_user_init();

    par
      {
	io(i_io);
	controller(p_btn, i_control);
	par (size_t i = 0; i < NUM_WORKERS; i++)
	  {
	    worker(c_wb_w[i], c_rb_w[i], i);
	  }
	write_buffer(c_wb_w, NUM_WORKERS, i_bufswap, buffer0, 1000, c_rb_wb);
	read_buffer(c_rb_w, NUM_WORKERS, i_bufswap, i_control, i_io, buffer1, 1000, 25, 25, c_rb_wb);
      }
    return 0;
}
