    .section .init, "ax", @progbits
    .align  2
    .globl  _start
    .type   _start, @function

_start:
    la      sp, __stack_top

    /* The ELF loader initializes only file-backed bytes, so clear .bss. */
    la      t0, __bss_start
    la      t1, __bss_end
.Lclear_bss:
    bgeu    t0, t1, .Lbss_done
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       .Lclear_bss

.Lbss_done:
    la      t0, trap_entry
    csrw    mtvec, t0

    call    main

    /* main returns the test status: 1 means pass, every other value fails. */
    li      t0, 0x20000000
    sw      a0, 0(t0)

.Lhalt:
    wfi
    j       .Lhalt

    .size   _start, .-_start

    .align  2
    .globl  trap_entry
    .type   trap_entry, @function
trap_entry:
    /* Any unexpected exception or interrupt fails the smoke test immediately. */
    li      t0, 0x20000000
    li      t1, 0x00000100
    sw      t1, 0(t0)
.Ltrap_halt:
    wfi
    j       .Ltrap_halt

    .size   trap_entry, .-trap_entry
