.intel_syntax noprefix

.equ NULL,                  0
.equ STDIN,                 0
.equ STDOUT,                1
.equ NULL_TERMINATOR,       0
.equ SIZE_OF_CHAR,          1
.equ SIZE_OF_SHORT,         2
.equ SIZE_OF_INT,           4
.equ SIZE_OF_LONG,          8

/*  system calls */
.equ SYS_READ,              0
.equ SYS_WRITE,             1
.equ SYS_MMAP,              9
.equ SYS_MUNMAP,            11
.equ SYS_EXIT,              60
.equ SYS_GETRANDOM,         318

/*  flags, options, etc. */
.equ PROT_READ,             1
.equ PROT_WRITE,            2
.equ MAP_PRIVATE,           2
.equ MAP_ANONYMOUS,         32

.global malloc
.global free
.global mmap
.global munmap
.global exit
.global random
.global getrandom
.global getrandomint


/*
    Macro to push registers

    Parameters
        r1, r2,...
*/
.macro pushr regs:vararg
    .irp register,\regs
        push \register
    .endr
.endm

/*
    Macro to pop registers

    Parameters:
        r1, r2, ...
*/
.macro popr regs:vararg
    .irp register,\regs
        pop \register
    .endr
.endm
/*
    Macro for mmap, this is not the actual malloc offered by C.
    Instead it uses the mmap syscall

    Parameters:
        size

    Modifies: rax, rcx, rdi, rsi, rdx, r8, r9, r10
    
    Return registers:
        rax: addr

    See also: mmap
*/
.macro malloc size
    push         r12
    mov          r12, \size
    call         mmap
    pop          r12
.endm

/*
    Macro for munmap, this is not the free offered by C.
    Instead it uses munmap syscall.

    Parameters:
        addr, len

    Modifies:
        rax, rdi, rsi

    See also: munmap
        
*/
.macro free addr, len
    push        r12
    push        r13
    mov         r12, \addr
    mov         r13, \len
    call        munmap
    pop         r13
    pop         r12
.endm

/*
    Gets a random int in the given range

    Parameters:
        from, to

    See also: getrandom
*/
.macro getrandomint from, to
    push        r12
    push        r13
    mov         r12, \from
    mov         r13, \to
    call        getrandom
    pop         r13
    pop         r12
.endm


.text

/*
    Abstracts the mmap syscall

    Input registers:
        r12: size

    Modifies:
        rax, rcx, rdi, rsi, rdx, r8, r9, r10

    Output registers:
        rax: address
*/
mmap:
    mov         rax, SYS_MMAP
    mov         rdi, NULL
    mov         rsi, r12
    mov         rdx, PROT_READ | PROT_WRITE
    mov         r10, MAP_PRIVATE | MAP_ANONYMOUS
    mov         r8, -1
    mov         r9, 0
    syscall
    ret

/*
    Abstraction for munmap syscall

    Input registers:
        r12: address
        r13: size

    Modifies:
        rax, rdi, rsi
*/
munmap:
    mov         rax, SYS_MUNMAP
    mov         rdi, r12
    mov         rsi, r13
    syscall
    ret

/*
    Get a random number within the range

    Input registers:
        r12: from
        r13: to

    Modifies:
        rax, rbx, xmm0, xmm1, xmm2, xmm3

    Output registers:
        rax: randint

    See also: random
*/
getrandom:
    push        r12
    push        r13
    call        random
    /* round(from + random() * (to - from)) */

    /* to - from */
    sub         r13, r12

    mov         rbx, 0xff
    cvtsi2ss    xmm0, rax
    cvtsi2ss    xmm1, rbx
    cvtsi2ss    xmm2, r12
    cvtsi2ss    xmm3, r13

    /* random byte / 255 (to simulate random()'s behaviour) */
    divss       xmm0, xmm1
    /* random() * (to - from) */
    mulss       xmm0, xmm3
    /* from + random() * (to - from) */
    addss       xmm0, xmm2
    /* round the whole thing and return it to rax */
    cvtss2si    rax, xmm0

    pop         r13
    pop         r12
    ret

/*
    Generates one random byte using the getrandom syscall

    Modifies:
        rax, rdi, rsi, rdx, r8, r9

    Output registers:
        rax: random byte value

    See also: malloc, free
*/
random:
    /* allocate memory for one byte */
    malloc      1
    /* store the allocated memory in r8 */
    mov         r8, rax

    mov         rax, SYS_GETRANDOM
    mov         rdi, r8         # *buffer
    mov         rsi, 1          # count
    xor         rdx, rdx        # flags
    syscall

    mov         rsi, rdi
    lodsb
    mov         r9, rax
    /* free the allocated memory */
    free        r8, 1
    /* return the random byte */
    mov         rax, r9
    ret

exit:
    leave
    mov         rax, SYS_EXIT
    /* return code (0) */
    xor         rdi, rdi
    syscall
