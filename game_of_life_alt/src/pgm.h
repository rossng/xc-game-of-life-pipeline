#ifndef PGM_H_
#define PGM_H_

#ifdef __XC__

int write_pgm(char fname[], unsigned char world[], int image_width, int image_height);
int read_pgm(char fname[], int &image_width, int &image_height, unsigned char world[]);

#else

int write_pgm(char fname[], unsigned char world[], int image_width, int image_height);
int read_pgm(char fname[], int * image_width, int * image_height, unsigned char world[]);

#endif /* __XC__ */

#endif /* PGM_H_ */
