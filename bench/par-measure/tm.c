// tm: run a command and print one line of what it cost.
//
//   tm CMD ARGS...   (the command's stdout and stderr pass through)
//
// The line goes to fd 3 if it is open, else to stderr, as key=value pairs:
//   rc wall_ms user_ms sys_ms vcsw ivcsw rss_mb instr cycles pinstr pcycles
//   puser_ms psys_ms runnable_ms
// The p* fields are the share spent on performance cores (macOS
// RUSAGE_INFO_V6); runnable_ms is the threads' runnable time, on a core or
// waiting for one (less user and sys, the time waiting for a core). The child is spawned with posix_spawn and waited with
// waitid(WNOWAIT) so proc_pid_rusage can read it before it is reaped.
#include <libproc.h>
#include <spawn.h>
#include <stdio.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <time.h>
#include <fcntl.h>
#include <mach/mach_time.h>

extern char** environ;

int main(int argc, char** argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: tm CMD ARGS...\n");
    return 127;
  }
  mach_timebase_info_data_t tb;
  mach_timebase_info(&tb);
  struct timespec a, b;
  pid_t pid;
  clock_gettime(CLOCK_MONOTONIC_RAW, &a);
  if (posix_spawnp(&pid, argv[1], NULL, NULL, argv + 1, environ)) {
    perror("posix_spawn");
    return 127;
  }
  siginfo_t si;
  if (waitid(P_PID, pid, &si, WEXITED | WNOWAIT) < 0) {
    perror("waitid");
    return 127;
  }
  clock_gettime(CLOCK_MONOTONIC_RAW, &b);
  struct rusage_info_v6 ri;
  memset(&ri, 0, sizeof ri);
  int have = proc_pid_rusage(pid, RUSAGE_INFO_V6, (rusage_info_t*)&ri) == 0;
  struct rusage ru;
  int st = 0;
  wait4(pid, &st, 0, &ru);
  int rc = WIFEXITED(st) ? WEXITSTATUS(st) : 128 + WTERMSIG(st);
  double wall = (b.tv_sec - a.tv_sec) * 1e3 + (b.tv_nsec - a.tv_nsec) / 1e6;
  double ns = (double)tb.numer / tb.denom;  // mach ticks to ns
  FILE* out = fcntl(3, F_GETFD) != -1 ? fdopen(3, "w") : stderr;
  fprintf(out, "rc=%d wall_ms=%.3f user_ms=%.3f sys_ms=%.3f vcsw=%ld ivcsw=%ld"
    " rss_mb=%.1f", rc, wall,
    ru.ru_utime.tv_sec * 1e3 + ru.ru_utime.tv_usec / 1e3,
    ru.ru_stime.tv_sec * 1e3 + ru.ru_stime.tv_usec / 1e3,
    ru.ru_nvcsw, ru.ru_nivcsw, ru.ru_maxrss / 1048576.0);
  if (have) {
    fprintf(out, " instr=%llu cycles=%llu pinstr=%llu pcycles=%llu"
      " puser_ms=%.3f psys_ms=%.3f runnable_ms=%.3f",
      ri.ri_instructions, ri.ri_cycles, ri.ri_pinstructions, ri.ri_pcycles,
      ri.ri_user_ptime * ns / 1e6, ri.ri_system_ptime * ns / 1e6,
      ri.ri_runnable_time * ns / 1e6);
  }
  fprintf(out, "\n");
  fclose(out);
  return rc;
}
