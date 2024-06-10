.intel_syntax noprefix

.include "src/system.asm"

.global _start

.text

    /* required by debugger */
main:
    jmp         _start

_start:
    /* create a new stack frame */
    push        rbp
    mov         rbp, rsp

    jmp         exit
