# Makefile for building port binary
#
# Makefile targets:
#
# all/install   build and install the port binary
# clean         clean build products and intermediates
#
# Variables to override:
#
# CC               C compiler. MUST be set if crosscompiling
# CROSSCOMPILE	   crosscompiler prefix, if any
# MIX_COMPILE_PATH path to the build's ebin directory
# CFLAGS	compiler flags for compiling all C files
# LDFLAGS	linker flags for linking all binaries
# SUDO_ASKPASS  path to ssh-askpass when modifying ownership of wpa_ex
# SUDO          path to SUDO. If you don't want the privileged parts to run, set to "true"

PREFIX = $(MIX_COMPILE_PATH)/../priv
BUILD = $(MIX_COMPILE_PATH)/../obj
BIN = $(PREFIX)/wpa_ex

# Check that we're on a supported build platform
ifeq ($(CROSSCOMPILE),)
    # Not crosscompiling, so check that we're on Linux.
    ifneq ($(shell uname -s),Linux)
        $(warning nerves_wpa_supplicant only works on Linux, but crosscompilation)
        $(warning is supported by defining $$CROSSCOMPILE.)
        $(warning See Makefile for details. If using Nerves,)
        $(warning this should be done automatically.)
        $(warning .)
        $(warning Skipping C compilation unless targets explicitly passed to make.)
	BIN :=
    endif
endif

WPA_DEFINES = -DCONFIG_CTRL_IFACE -DCONFIG_CTRL_IFACE_UNIX

LDFLAGS += -lrt
CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter

# If not cross-compiling, then run sudo by default
ifeq ($(origin CROSSCOMPILE), undefined)
SUDO_ASKPASS ?= /usr/bin/ssh-askpass
SUDO ?= sudo
else
# If cross-compiling, then permissions need to be set some build system-dependent way
SUDO ?= true
endif

SRC = src/wpa_ex.c src/wpa_ctrl/os_unix.c src/wpa_ctrl/wpa_ctrl.c
OBJ = $(SRC:src/%.c=$(BUILD)/%.o)

calling_from_make:
	mix compile

all: install

install: $(PREFIX) $(BUILD) $(BIN)

$(OBJ): Makefile

$(BUILD)/%.o: src/%.c
	$(CC) -c $(WPA_DEFINES) $(CFLAGS) -o $@ $<

$(BIN): $(OBJ)
	$(CC) $^ $(LDFLAGS) -o $@
	# setuid root wpa_ex so that it can interact with the wpa_supplicant
	SUDO_ASKPASS=$(SUDO_ASKPASS) $(SUDO) -- sh -c 'chown root:root $@; chmod +s $@'

$(PREFIX):
	mkdir -p $@

$(BUILD):
	mkdir -p $(BUILD)/wpa_ctrl

clean:
	$(RM) $(BIN) $(BUILD)/*.o $(BUILD)/wpa_ctrl/*.o

.PHONY: all clean calling_from_make install
