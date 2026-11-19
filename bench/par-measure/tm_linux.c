// tm for Linux: run a command, print rc, wall, user, sys, context switches
// and peak RSS on stderr (one line, the same keys as tm.c's first ones).
#define _GNU_SOURCE
#include <spawn.h>
#include <stdio.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <time.h>
extern char** environ;
int main(int argc, char** argv) {
  struct timespec a, b;
  struct rusage ru;
  pid_t pid;
  int st = 0;
  clock_gettime(CLOCK_MONOTONIC, &a);
  if (argc < 2 || posix_spawnp(&pid, argv[1], NULL, NULL, argv + 1, environ)
    || wait4(pid, &st, 0, &ru) < 0) {
    return 127;
  }
  clock_gettime(CLOCK_MONOTONIC, &b);
  fprintf(stderr, "rc=%d wall_ms=%.3f user_ms=%.3f sys_ms=%.3f vcsw=%ld ivcsw=%ld rss_mb=%.1f\n",
    WIFEXITED(st) ? WEXITSTATUS(st) : 128 + WTERMSIG(st),
    (b.tv_sec - a.tv_sec) * 1e3 + (b.tv_nsec - a.tv_nsec) / 1e6,
    ru.ru_utime.tv_sec * 1e3 + ru.ru_utime.tv_usec / 1e3,
    ru.ru_stime.tv_sec * 1e3 + ru.ru_stime.tv_usec / 1e3,
    ru.ru_nvcsw, ru.ru_nivcsw, ru.ru_maxrss / 1024.0);
  return 0;
}
