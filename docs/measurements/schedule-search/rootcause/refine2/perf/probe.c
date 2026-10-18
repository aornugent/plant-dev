/* A fixed workload timed in process CPU seconds: a dependent floating-point chain
   (core speed) and a pointer chase over 64 MiB (memory latency). Prints both. */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
static double cpu(void) { struct timespec t; clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t); return t.tv_sec + 1e-9 * t.tv_nsec; }
int main(void) {
  double c0 = cpu(), x = 1.0;
  for (long i = 0; i < 200000000L; ++i) x = x * 1.0000001 + 1e-9;
  double c1 = cpu();
  size_t n = (64u << 20) / sizeof(size_t);
  size_t *next = malloc(n * sizeof(size_t));
  for (size_t i = 0; i < n; ++i) next[i] = i;
  srand(1);
  for (size_t i = n - 1; i > 0; --i) { size_t j = ((size_t)rand() * RAND_MAX + rand()) % (i + 1); size_t t = next[i]; next[i] = next[j]; next[j] = t; }
  double c2 = cpu(); size_t p = 0;
  for (long i = 0; i < 5000000L; ++i) p = next[p];
  double c3 = cpu();
  printf("%.4f %.4f %g %zu\n", c1 - c0, c3 - c2, x, p);
  return 0;
}
