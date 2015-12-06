#ifndef READ_BUFFER_H_
#define READ_BUFFER_H_

void read_buffer(chanend workers[num_workers], unsigned num_workers,
                 server interface control_if i_control, server interface pause_if i_pause, client interface io_if i_io,
                 char initial_buffer[n], unsigned n, int image_width_bits, int image_height_bit);

#endif /* READ_BUFFER_H_ */
