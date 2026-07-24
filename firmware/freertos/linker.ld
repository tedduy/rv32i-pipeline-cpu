OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 1M
}

PHDRS
{
    text PT_LOAD FLAGS(5); /* Read + execute. */
    data PT_LOAD FLAGS(6); /* Read + write. */
}

SECTIONS
{
    . = ORIGIN(RAM);

    .text : ALIGN(4)
    {
        KEEP(*(.init))
        *(.text .text.*)
    } > RAM :text

    .rodata : ALIGN(4)
    {
        *(.rodata .rodata.*)
    } > RAM :text

    .data : ALIGN(4)
    {
        *(.data .data.*)
    } > RAM :data

    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > RAM :data

    . = ALIGN(16);
    __image_end = .;
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
    __freertos_irq_stack_top = __stack_top;

    /DISCARD/ :
    {
        *(.comment)
        *(.note .note.*)
        *(.eh_frame .eh_frame.*)
    }
}

ASSERT(__image_end <= (__stack_top - 4096), "firmware image overlaps the stack")
