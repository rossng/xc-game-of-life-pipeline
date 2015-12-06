#ifndef INTERFACES_H_
#define INTERFACES_H_

interface bufswap_if
{
  void swap(char * movable &x);
};

interface control_if
{
  [[guarded]] void start_export();
  [[guarded]] void start_import();
};

interface pause_if
{
  [[guarded]] void pause();
  [[guarded]] void unpause();
};

interface io_if
{
  char * movable export(char * movable world, int width_bits, int height_bits);
  char * movable import(char * movable world, int &width_bits, int &height_bits);
};

#endif /* INTERFACES_H_ */
