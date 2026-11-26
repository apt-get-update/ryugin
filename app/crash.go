package main

/*
#cgo LDFLAGS: -ldl
#define _GNU_SOURCE
#include <dlfcn.h>
#include <signal.h>
#include <stdio.h>
#include <sys/syscall.h>
#include <ucontext.h>
#include <unistd.h>

// A crash on a thread of Qt or FFmpeg (not Go's) ends the app without a word: Go
// re-raises the signal there. This handler, installed before Go starts, so Go forwards
// those signals to it, first writes to stderr (Sailfish OS: ~/.cache/dragon/ryugin/ryugin/ryugin.log)
// the signal, where it happened (library, function and offset, for addr2line) and the
// frames it can find: a backtrace stops at the signal's frame on aarch64.
static void where(const char *what, void *pc) {
	char line[600];
	Dl_info i;
	int n;
	if (dladdr(pc, &i) && i.dli_fname)
		n = snprintf(line, sizeof line, "%s %p %s+%#lx (%s)\n", what, pc, i.dli_fname,
			(unsigned long)((char *)pc - (char *)i.dli_fbase), i.dli_sname ? i.dli_sname : "?");
	else
		n = snprintf(line, sizeof line, "%s %p\n", what, pc);
	(void)!write(2, line, n > 0 && n < (int)sizeof line ? n : 0);
}

static void crashed(int sig, siginfo_t *info, void *ctx) {
	char msg[80];
	int n = snprintf(msg, sizeof msg, "native crash, signal %d, address %p\n", sig, info->si_addr);
	(void)!write(2, msg, n);
	ucontext_t *u = ctx;
#if defined(__aarch64__)
	// The thread, and Go's g (x28) next to the thread pointer's first words: is Go's state
	// lost, and is it the main thread (Qt's)?
	unsigned long *tp;
	__asm__("mrs %0, tpidr_el0" : "=r"(tp));
	n = snprintf(msg, sizeof msg, "thread %ld of %d, g %#llx\n", syscall(SYS_gettid), getpid(),
		(unsigned long long)u->uc_mcontext.regs[28]);
	(void)!write(2, msg, n);
	char words[200];
	n = snprintf(words, sizeof words, "tp %p: %#lx %#lx %#lx %#lx %#lx %#lx %#lx %#lx\n", (void *)tp,
		tp[0], tp[1], tp[2], tp[3], tp[4], tp[5], tp[6], tp[7]);
	(void)!write(2, words, n);
	where("at", (void *)u->uc_mcontext.pc);
	where("from", (void *)u->uc_mcontext.regs[30]);
	void **fp = (void **)u->uc_mcontext.regs[29]; // frame records: {caller's fp, return address}
#elif defined(__x86_64__)
	where("at", (void *)u->uc_mcontext.gregs[REG_RIP]);
	void **fp = (void **)u->uc_mcontext.gregs[REG_RBP];
#endif
	for (int k = 0; k < 24 && fp && ((unsigned long)fp & 7) == 0; k++) {
		where("frame", fp[1]);
		if ((void **)fp[0] <= fp)
			break;
		fp = (void **)fp[0];
	}
	signal(sig, SIG_DFL);
	raise(sig);
}

// The phone's Mali GPU driver (the vendor's, in /vendor, loaded by libhybris) keeps its
// state in the first TLS words after the thread pointer, where glibc puts the program's own
// TLS, Go's g first (tp+16). The driver overwrote g and the next call into Go crashed
// (cgocallback: g.m nil). Initialised TLS (.tdata) comes before .tbss, Go's: these
// 128 bytes take bionic's slots. They start zero, as libhybris expects (a 1 there crashed
// eglInitialize); only the last byte is set, to keep them in .tdata.
__attribute__((used)) __thread char hybrisSlots[128] = {[127] = 1};

__attribute__((constructor)) static void crashTrace(void) {
	struct sigaction sa = {0};
	sa.sa_sigaction = crashed;
	sa.sa_flags = SA_ONSTACK | SA_SIGINFO;
	int sigs[] = {SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGABRT};
	for (unsigned i = 0; i < sizeof sigs / sizeof *sigs; i++)
		sigaction(sigs[i], &sa, 0);
}
*/
import "C"
