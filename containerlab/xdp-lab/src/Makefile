BPF_C_FILES := $(wildcard *.bpf.c)
BPF_O_FILES := $(patsubst %.bpf.c,%.o,$(BPF_C_FILES))

BUILD_SCRIPT := $(abspath ../../../scripts/build-bpf.sh)
SRCDIR ?= $(shell pwd)

.PHONY: all clean

all: $(BPF_O_FILES)

%.o: %.bpf.c
	bash $(BUILD_SCRIPT) $<

clean:
	rm -f $(BPF_O_FILES) vmlinux.h
