%include "../src/alloc.asm"

section .data
global _start
_start:     
        sys_exit(0)