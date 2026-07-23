# Clock and reset domains

The CPU has one functional clock, `i_clk`, and one active-low asynchronous
reset, `i_arst_n`. Interrupt inputs are required to be synchronous to `i_clk`;
an MCU integration must add synchronizers before the core when interrupt
sources originate in another clock domain.

There is no internal clock gating and no second functional clock domain.
Consequently the standalone core does not maintain CDC or RDC waiver/setup
directories. CDC/RDC analysis belongs at SoC integration level if additional
clocks, reset controllers or asynchronous peripherals are introduced.

All sequential RTL uses the same reset polarity and clock edge. The reset may
assert asynchronously; the containing system is responsible for a clean reset
release relative to `i_clk`.
