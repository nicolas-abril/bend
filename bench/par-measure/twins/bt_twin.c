// C twin of koru's forked binarytrees (bend-par/binarytrees): 1200 times,
// build a tree of depth 13 whose top CUT levels fork (2^CUT subtrees of
// depth 13 - CUT built in parallel), then check it on the calling thread,
// freeing each node as it is read (as Bend's match does). Prints 19659600.
//
//   bt_twin MODE THREADS [CUT]
//
// MODE:
//   seq   no pool; the subtrees are built one after the other
//   spin  a pool whose workers busy-wait on a turn counter (never sleep)
//   cond  Bend's wait: 128 sched_yield, then a condition wait; each tree is
//         one turn, its start broadcast to every worker
//   cond2 the same with two turns a tree (Bend runs a grow and a drain turn)
//   gcd   dispatch_apply on a global concurrent queue (libdispatch)
//
// Nodes are 16 bytes, bump-allocated from one arena per subtree slot (reset
// every tree; nothing is freed), the same in every mode, so the modes differ
// only in how the subtrees are dealt and joined. Not like for like with
// Bend's allocation (Bend frees each node in check): compare modes with each
// other, and Bend's builds with each other.
#ifdef __APPLE__
#include <dispatch/dispatch.h>
#endif
#include <pthread.h>
#include <sched.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct Node { struct Node* l; struct Node* r; } Node;

// one bump arena per subtree slot (and one for the top), reset every tree:
// every mode allocates and touches the same memory
static Node* arena[1 << 12];
static Node* top_arena;
static _Thread_local Node* bump;

static Node* node_new(Node* l, Node* r) {
  Node* n = bump++;
  n->l = l;
  n->r = r;
  return n;
}

// Leaf is NULL; make(0) is Node{Leaf, Leaf}
static Node* make(int d) {
  return d == 0 ? node_new(NULL, NULL) : node_new(make(d - 1), make(d - 1));
}

static long check(Node* t) {
  if (!t) return 0;
  return 1 + check(t->l) + check(t->r);
}

static int CUT = 4, DEPTH = 13, NT = 1, TURNS = 1;
static Node* sub[1 << 12];
static Node* join_top(int lv, int i) {
  return lv == CUT ? sub[i] : node_new(join_top(lv + 1, 2 * i), join_top(lv + 1, 2 * i + 1));
}

// pool
static _Atomic unsigned turn, claim, done;
static pthread_mutex_t lk = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t wake = PTHREAD_COND_INITIALIZER, joined = PTHREAD_COND_INITIALIZER;
static int MODE;  // 1 spin, 2 cond
static int work_now;  // 1: build subtrees this turn, 0: an empty turn

static void run_claims(void) {
  unsigned n = 1u << CUT, got = 0;
  if (work_now) {
    for (unsigned i; (i = atomic_fetch_add(&claim, 1)) < n;) {
      bump = arena[i];
      sub[i] = make(DEPTH - CUT);
      got += 1;
    }
  }
  (void)got;
}

static void wait_turn(unsigned seen) {
  if (MODE == 1) {
    while (atomic_load_explicit(&turn, memory_order_acquire) == seen) {}
    return;
  }
  if (MODE == 2) {
    for (int s = 0; s < 128 && atomic_load(&turn) == seen; s++) sched_yield();
  }
  pthread_mutex_lock(&lk);
  while (atomic_load(&turn) == seen) pthread_cond_wait(&wake, &lk);
  pthread_mutex_unlock(&lk);
}

static void* worker(void* arg) {
  (void)arg;
  unsigned seen = 0;
  for (;;) {
    wait_turn(seen);
    seen = atomic_load(&turn);
    run_claims();
    if (atomic_fetch_sub(&done, 1) == 1 && MODE != 1) {
      pthread_mutex_lock(&lk);
      pthread_cond_signal(&joined);
      pthread_mutex_unlock(&lk);
    }
  }
  return NULL;
}

static void pool_turn(int work, int wakers) {
  work_now = work;
  atomic_store(&claim, 0);
  atomic_store(&done, (unsigned)wakers);
  if (MODE == 1) {
    atomic_fetch_add_explicit(&turn, 1, memory_order_release);
  } else {
    pthread_mutex_lock(&lk);
    atomic_fetch_add(&turn, 1);
    pthread_cond_broadcast(&wake);
    pthread_mutex_unlock(&lk);
  }
  run_claims();
  if (MODE == 1) {
    while (atomic_load_explicit(&done, memory_order_acquire) != 0) {}
    return;
  }
  if (MODE == 2) {
    for (int s = 0; s < 128 && atomic_load(&done) != 0; s++) sched_yield();
  }
  pthread_mutex_lock(&lk);
  while (atomic_load(&done) != 0) pthread_cond_wait(&joined, &lk);
  pthread_mutex_unlock(&lk);
}

int main(int argc, char** argv) {
  const char* mode = argc > 1 ? argv[1] : "seq";
  NT = argc > 2 ? atoi(argv[2]) : 1;
  CUT = argc > 3 ? atoi(argv[3]) : 4;
  int gcd = !strcmp(mode, "gcd");
  MODE = !strcmp(mode, "spin") ? 1 : !strcmp(mode, "cond") || !strcmp(mode, "cond2") ? 2
 : 0;
  TURNS = !strcmp(mode, "cond2") ? 2 : 1;
  int pool = MODE != 0 && NT > 1;
  if (pool) {
    for (int w = 1; w < NT; w++) {
      pthread_t t;
      pthread_create(&t, NULL, worker, (void*)(intptr_t)w);
    }
  }
  unsigned n = 1u << CUT;
  for (unsigned i = 0; i < n; i++) {
    arena[i] = calloc((size_t)2 << (DEPTH - CUT), sizeof(Node));
  }
  top_arena = calloc((size_t)2 << CUT, sizeof(Node));
  long acc = 0;
  for (int it = 0; it < 1200; it++) {
    if (gcd) {
#ifdef __APPLE__
      dispatch_apply(n, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
        bump = arena[i];
        sub[i] = make(DEPTH - CUT);
      });
#endif
    } else if (pool) {
      int wakers = NT - 1;
      if (TURNS == 2) pool_turn(0, wakers);
      pool_turn(1, wakers);
    } else {
      for (unsigned i = 0; i < n; i++) {
        bump = arena[i];
        sub[i] = make(DEPTH - CUT);
      }
    }
    bump = top_arena;
    acc += check(join_top(0, 0));
  }
  printf("%ld\n", acc);
  return 0;
}
