## Copyright 2020 Flynn Liu
## SPDX-License-Identifier: Apache-2.0

# flags you can change
CXX := g++
CXXFLAGS += -std=c++14 -Wall
MODE := debug

# tools
R7RS := gosh -r7 -bq
GEN_GRAPH := $(R7RS) generate-graph.scm

# file lists
with_graph := koopa_graph
files := $(with_graph) koopa main

# function definition
exists = $(shell [ -f $1 ] && echo $1)
touch = @ [ -f $1 ] && (touch -c $1 || true)

define compile_object
  $(1:=.o): $(1:=.cpp) $(call exists, $(1:=.hpp))
	$$(CXX) $$(CXXFLAGS) -c $$<
endef

define generate_graph
  # generate ?.inc.hpp and ?.inc.cpp from ?.scm
  $(1:=.inc.hpp): $(1:=.scm)
	$$(GEN_GRAPH) $(1:=.scm) $(1:=.inc.hpp) $(1:=.inc.cpp)

  $(1:=.inc.cpp): $(1:=.inc.hpp) $(1:=.scm)
	$$(call touch, $$@)

  # update ?.hpp and ?.cpp if the graph is newer
  $(1:=.cpp) $(1:=.hpp): $(1:=.inc.hpp) $(1:=.inc.cpp)
	$$(call touch, $$@)
endef

# debug and relase flags
# if CXXFLAGS is passed in as a parameter, these flags will not be added
debug_flags := -g
release_flags := -O3
ifeq ($(MODE),debug)
  CXXFLAGS += $(debug_flags)
else
  CXXFLAGS += $(release_flags)
endif

# default target
all: program
.DELETE_ON_ERROR:

# generate graphs
$(foreach graph, $(with_graph), $(eval $(call generate_graph, $(graph) )) )

# include all objects
$(foreach name, $(files), $(eval $(call compile_object, $(name) )) )

program: $(sort $(files:=.o))
	$(CXX) -o $@ $^

clean-inc:
	rm -f *.inc.cpp *.inc.hpp *.tmp

clean:
	rm -f *.o *.tmp program

clean!: clean-inc clean

.PHONY: clean clean-inc clean! all
