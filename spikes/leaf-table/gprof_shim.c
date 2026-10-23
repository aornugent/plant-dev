/* Start and stop gperftools' CPU profiler from inside R (.C), so the timer
   runs only in the R process and only around the phase being profiled. */
#include <gperftools/profiler.h>

void prof_start(char **file) { ProfilerStart(file[0]); }
void prof_stop(void) { ProfilerStop(); }
