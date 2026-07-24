#ifndef FREERTOS_RISC_V_CHIP_SPECIFIC_EXTENSIONS_H
#define FREERTOS_RISC_V_CHIP_SPECIFIC_EXTENSIONS_H

#define portasmHAS_MTIME 1
#define portasmADDITIONAL_CONTEXT_SIZE 0

.macro portasmSAVE_ADDITIONAL_REGISTERS
    /* No additional registers to save */
.endm

.macro portasmRESTORE_ADDITIONAL_REGISTERS
    /* No additional registers to restore */
.endm

#endif
