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



#endif /* INTERFACES_H_ */
