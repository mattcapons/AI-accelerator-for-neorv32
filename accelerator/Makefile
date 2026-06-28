GHDL ?= ghdl
STD ?= 08
WORKDIR ?= build/ghdl

RTL_SRCS := \
	rtl/systolic_pkg.vhd \
	rtl/systolic_pe.vhd \
	rtl/systolic_array.vhd \
	rtl/systolic_controller.vhd \
	rtl/buffer_unit.vhd \
	rtl/systolic_engine.vhd

TESTS := \
	tb_buffer_unit \
	tb_systolic_pe \
	tb_systolic_controller \
	tb_systolic_array

TB_SRCS := $(addprefix sim/,$(addsuffix .vhd,$(TESTS)))

.PHONY: all analyze test $(TESTS) clean

all: analyze

$(WORKDIR):
	mkdir -p $@

analyze: $(WORKDIR)
	$(GHDL) -a --std=$(STD) --workdir=$(WORKDIR) $(RTL_SRCS)

test: $(TESTS)

$(TESTS): analyze
	$(GHDL) -a --std=$(STD) --workdir=$(WORKDIR) sim/$@.vhd
	$(GHDL) -e --std=$(STD) --workdir=$(WORKDIR) $@
	$(GHDL) -r --std=$(STD) --workdir=$(WORKDIR) $@ --assert-level=error

clean:
	rm -rf build
