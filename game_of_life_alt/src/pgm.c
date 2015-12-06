#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <xscope.h>

/**
 * Write a supplied image out to a PGM file.
 * @param fname		The path of the destination file, e.g.
 *                  	"/home/user/xmos/project/" on Linux or "C:\\user\\xmos\\project\\" on Windows
 * @param world     	An array of chars (length width*height) representing the image.
 *                  	To be written to the file.
 * @param image_width 	The width of the image.
 * @param image_height	The height of the image.
 * @return          	0: success
 *                  	-1: error
 */
int write_pgm(char fname[], unsigned char world[], int image_width, int image_height)
{
    printf("PGM: Attempting to open %s for writing\n", fname);

    // Attempt to open the file in read/update mode
    FILE *fp = fopen(fname, "wb");
    if (fp == NULL)
      {
	printf("PGM: Could not open %s in rb+ mode.\n", fname);
	return -1;
      }

    rewind(fp);

    // Write the header buffer out to the file
    fprintf(fp, "P5\n%d %d\n255\n", image_width, image_height);

    int bytes_per_row = (image_width + 7) / 8;

    // Write one byte for each bit in the world chunk
    for (int row = 0; row < image_height; row++)
      {
	int row_start_byte = bytes_per_row * row;

	for (int col = 0; col < image_width; col++)
	  {
	    int byte_pos_in_row = col / 8;

	    int bit_offset = col%8;

	    if((world[row_start_byte + byte_pos_in_row] >> (7 - bit_offset)) & 1)
	      {
		fputc(255, fp);
	      }
	    else
	      {
		fputc(0, fp);
	      }
	  }
      }

    // Attempt to close the file
    if(0 != fclose(fp))
      {
        printf( "PGM: Error closing file %s.\n", fname);
        return -1;
      }

    printf("PGM: Successfully wrote file\n");

    return 0;
}

/**
 * Read a PGM file into an array, each row packed into the smallest number of bits possible.
 * Rows are a whole number of bits (there may be a gap between each row).
 * @param fname		The path of the file to read in
 * @param image_width	OUT: A reference to save the image width into
 * @param image_height	OUT: A reference to save the image height into
 * @param world		OUT: A buffer to save the image data into
 * @return		0: success
 * 			-1: error
 */
int read_pgm(char fname[], int * image_width, int * image_height, unsigned char world[])
{
  // Attempt to open the file using the supplied path
  printf("PGM: Opening %s\n", fname);
  FILE *fp = fopen(fname, "rb");

  // If the file fails to open, report the error
  if (fp == NULL)
    {
      printf("PGM: Could not open %s to read\n", fname);
      return -1;
    }

  // Buffer to store header data read from the image
  char str[64];

  // Ignore the PGM format version indicator (should be P5)
  fgets(str, 64, fp);

  // Store the width and height from the image header
  fgets(str, 64, fp);
  sscanf(str, "%d%d", image_width, image_height);

  // Ignore the max gray value (we're assuming 255)
  fgets(str, 64, fp);

  // Position of the file pointer is now at the beginning of the pixel data

  // Read in a chunk of pixels from the file
  char buffer[1000];
  fread(buffer, 1, 1000, fp);

  // Read in the pixel data, packing it into a temporary byte and then writing
  // once the byte is full
  char temp_byte = 0;
  unsigned char current_pixel = 0;
  int bytes_per_row = (*image_width + 7) / 8;

  for (int row = 0; row < *image_height; row++)
    {
      for (int col = 0; col < *image_width; col++)
	{
	  int byte_index = (*image_width * row + col);
	  current_pixel = buffer[byte_index%1000];

	  // If the pixel == max value, it is live
	  if (current_pixel == 255)
	    {
	      temp_byte |= 1 << (7 - col%8);
	    }

	  // We want to pack eight pixels (eight bytes) into a single byte
	  // If col%8 == 7, we have finished packing a byte, so write it to the world array
	  if (col%8 == 7)
	    {
	      // Write the byte out and reset it
	      world[bytes_per_row*row + col/8] = temp_byte;
	      temp_byte = 0;
	  }

	  // If we've reached the end of the buffer, load in more of the file
	  if (byte_index%1000 == 999)
	    {
	      fread(buffer, 1, 1000, fp);
	    }
	}

      // If this row has a number of pixels not divisible by 8, write out the final byte
      if (*image_width%8 != 0)
	{
	  world[bytes_per_row*row + *image_width/8] = temp_byte;
	  temp_byte = 0;
	}
    }

  printf("PGM: Finished reading image\n");

  // Attempt to close the file
  if (0 != fclose(fp))
    {
      printf("PGM: Error closing file %s.\n", fname);
      return -1;
    }

  return 0;
}
