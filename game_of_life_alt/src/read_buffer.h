#ifndef READ_BUFFER_H_
#define READ_BUFFER_H_

void read_buffer(streaming chanend workers[num_workers], unsigned num_workers, server interface bufswap_if i_bufswap,
                 server interface control_if i_control, client interface io_if i_io, char initial_buffer[n], unsigned n,
                 int image_width_bits, int image_height_bits, streaming chanend c_wb);

#endif /* READ_BUFFER_H_ */
