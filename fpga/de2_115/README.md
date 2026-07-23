# DE2-115 integration

This directory contains the optional Intel Cyclone IV DE2-115 board wrapper,
pin constraints and SignalTap setup. The board top instantiates the public
native-bus core with simple local instruction/data memories.

Open `rv32i_top.qpf` in Quartus and compile `de2_115_top`. Generated Quartus
reports and programming files are intentionally ignored.

No Fmax, utilization or power number is claimed in the repository. Publish
such results only with the exact RTL commit, Quartus version, device, SDC
constraints and raw reports.
