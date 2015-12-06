#include <stdio.h>
#include <timer.h>
#include <stdlib.h>
#include <xscope.h>
#include <xs1.h>
#include <platform.h>
#include "settings.h"

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

int is_live(char world_chunk[], int chunk_width_bits, int chunk_height_bits, int x, int y)
{
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
  live_neighbours += is_live(world_chunk, width_bits, height_bits, x, y+1);
  live_neighbours += is_live(world_chunk, width_bits, height_bits, x+1, y-1);
  live_neighbours += is_live(world_chunk, width_bits, height_bits, x+1, y);
  live_neighbours += is_live(world_chunk, width_bits, height_bits, x+1, y+1);
  /*
                          ,     \    /      ,
                         / \    )\__/(     / \
                        /   \  (_\  /_)   /   \
     __________________/_____\__\@  @/___/_____\_________________
     |                          |\../|                          |
     |                           \VV/                           |
     |                                                          |
     |                      HERE BE DRAGONS                     |
     |  This is the only format I could get this if-statement   |
     |  to work in. Simplifying it breaks things in weird and   |
     |  wonderful ways. A compiler bug?                         |
     |__________________________________________________________|
                   |    /\ /      \\       \ /\    |
                   |  /   V        ))       V   \  |
                   |/     `       //        '     \|
                   `              V                '
   */
  if (is_live(world_chunk, width_bits, height_bits, x, y))
    {
      if (live_neighbours == 2 || live_neighbours == 3)
        {
          return 1;
        }
      else
	{
	  return 0;
	}
    }

  if (live_neighbours == 3)
    {
      return 1;
    }
  else
    {
      return 0;
    }
}



void print_world_chunk(char world_chunk[], int width_bits, int height_bits, int id)
{
  int bytes_per_row = (width_bits + 7) / 8;

  delay_milliseconds(3000*id);

  // Print all world chunk data
  for (int row = 0; row <= height_bits + 1; row++)
    {
      // Demarcate between row above // main chunk // row below
      if (row == 1 || row == height_bits + 1)
	{
	  printf("W[%d] ", id);
	  for (int i = 0; i < width_bits; i++) { printf("--"); }
	  printf("\n");
	}

      // Print worker identifier
      printf("W[%d] ", id);

      // Print contents of the current row
      for (int byte = 0; byte < bytes_per_row; byte++)
	{
	  char this_byte = world_chunk[row*bytes_per_row + byte];
	  for (int i = 0; i < 8; i++)
	    {
	      printf("%c ", ((this_byte >> (7-i)) & 1) == 1 ? '*' : ' ');
	    }
	}
      printf("\n");
    }

  printf("\n");

  // Print row below
}

void worker(chanend read_buffer, int id)
{

  char world_chunk[13100] = {0};

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

      //printf("W[%d]: inputted row above\n", id);

      // Read in the chunk of the world that this worker is responsible for
      for (int i = 0; i < chunk_bytes; i++)
	{
	  read_buffer :> world_chunk[current_index++];
	  //printf("W[%d]: inputted world byte %d\n", id, i);
	}

      // Read in the row below this chunk
      for (int i = 0; i < chunk_width_bits_bytes; i++)
	{
	  read_buffer :> world_chunk[current_index++];
	}

      //printf("W[%d]: inputted row below\n", id);

       //print_world_chunk(world_chunk, chunk_width_bits, chunk_height_bits, id);

      // Update each bit in the chunk
      int sent = 0;

      char temp_byte = 0;
      for (int y = 0; y < chunk_height_bits; y++)
	{
	  int bytes_written_this_row = 0;
	  // Write out the contents of the current row to the write buffer
	  for (int x = 0; x < chunk_width_bits; x++)
	    {
	      // State of the bit in the next round
	      char current_bit_next_round = get_next_round(world_chunk, chunk_width_bits, chunk_height_bits, x, y);

	      // Write the bit to the correct place in the current byte
	      temp_byte |= current_bit_next_round << (7 - x%8);

	      // If we've finished calculating a byte, write it out to the buffer
	      if (x%8 == 7)
		{
	      read_buffer <: temp_byte;
		  temp_byte = 0;
		  bytes_written_this_row++;
		  sent ++;

		}
	    }

	  // If the row does not divide exactly into bytes, write out the final byte
	  if (chunk_width_bits%8 != 0)
	    {
	      read_buffer <: temp_byte;
	      temp_byte = 0;
	      sent ++;
	    }
	}
      printf("Worker %d finished sending back %d!\n", id, sent);
    }
}
