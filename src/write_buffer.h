#ifndef WRITE_BUFFER_H_
#define WRITE_BUFFER_H_

void write_buffer(chanend workers[num_workers], unsigned num_workers, client interface bufswap_if i_bufswap,
                  char initial_buffer[n], unsigned n, chanend c_rb);

#endif /* WRITE_BUFFER_H_ */
