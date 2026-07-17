#ifndef _RVMODEL_MACROS_H
#define _RVMODEL_MACROS_H

#define RVMODEL_DATA_SECTION

/* Base-I tests execute directly from the core's reset state. */
#define RVMODEL_BOOT_TO_MMODE

#define RVMODEL_HALT_PASS  \
  li t0, 0x20000000       ;\
  li t1, 1                ;\
  sw t1, 0(t0)            ;\
1: j 1b

#define RVMODEL_HALT_FAIL  \
  li t0, 0x20000000       ;\
  li t1, 3                ;\
  sw t1, 0(t0)            ;\
1: j 1b

#define RVMODEL_IO_WRITE_STR(_R1, _R2, _R3, _STR_PTR) \
1: lbu  _R1, 0(_STR_PTR)                              ;\
   beqz _R1, 2f                                       ;\
   li   _R2, 0x10000000                               ;\
   sw   _R1, 0(_R2)                                   ;\
   addi _STR_PTR, _STR_PTR, 1                         ;\
   j 1b                                               ;\
2:

#endif
