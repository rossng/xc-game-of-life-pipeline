#ifndef READ_BUFFER_H_
#define READ_BUFFER_H_

void read_buffer(chanend workers[num_workers], unsigned num_workers,
                 server interface control_if i_control, server interface pause_if i_pause
                 );

#endif /* READ_BUFFER_H_ */
