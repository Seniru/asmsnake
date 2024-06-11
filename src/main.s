.intel_syntax noprefix

.include "src/system.s"
.include "src/print.s"

.global _start

.equ WIDTH,                     80
.equ HEIGHT,                    30
.equ SNAKE_HEAD,                1
.equ SNAKE_BODY,                2
.equ SNAKE_HEAD_INITIAL_X,      WIDTH / 2
.equ SNAKE_HEAD_INIIIAL_Y,      HEIGHT / 2

.macro printr register=rax
    mov     r12, \register
    call    print_usigned_int
.endm

.macro println
    lea     r12, [newline]
    mov     r13, 1
    call    print_string
.endm

.macro printchar character
    pushr   r12, r13, rax, rbx, rcx, rdx, rsi, rdi
    lea     r12, \character
    mov     r13, 1
    call    print_string
    popr    rdi, rsi, rdx, rcx, rbx, rax, r13, r12
.endm

.macro printchar_nopreserve character
    lea     r12, \character
    mov     r13, 1
    call    print_string
.endm

.data

wall:           .ascii "#"
newline:        .ascii "\n"
clr:            .ascii "\033c"
blank:          .ascii " "
apple:          .ascii "@"
snakehead:      .ascii "*"
snakebody:      .ascii "+"
snakeheady:     .short SNAKE_HEAD_INIIIAL_Y
snakeheadx:     .short SNAKE_HEAD_INITIAL_X


.bss

.lcomm grid WIDTH * HEIGHT

.text

    /* required by debugger */
main:
    jmp         _start

_start:
    /* create a new stack frame */
    push        rbp
    mov         rbp, rsp
    call        draw_grid
    jmp         exit


draw_grid:
    call        clear_screen
    /* draw the top wall */
    call        draw_horizontal_boundary
    printchar_nopreserve [wall]
    /* row index */
    mov         r14, 1
    /* column index */
    mov         r15, 1
    xor         rcx, rcx
    lea         rsi, [grid]
    xor         rax, rax
    xor         rbx, rbx
    mov         ax, [snakeheadx]
    mov         bx, [snakeheady]
    mov         dx, WIDTH
    /* snakehead location = snakeheady * WIDTH + snakeheadx */
    imul        bx, dx
    add         bx, ax
    mov         byte ptr [rsi + rbx], SNAKE_HEAD
    mov         byte ptr [rsi + rbx - 1], SNAKE_BODY
    mov         byte ptr [rsi + rbx - 2], SNAKE_BODY
draw_grid_start:
    xor         rax, rax
    lodsb
    cmp         al, NULL
    je          print_space
    cmp         al, SNAKE_HEAD
    je          print_snake_head
    cmp         al, SNAKE_BODY
    je          print_snake_body
draw_grid_cont:
    inc         rcx
    inc         r15
    cmp         r15, WIDTH
    jg          move_new_row
    jmp         draw_grid_start
draw_grid_done:
    /* draw the bottom wall */
    call        draw_horizontal_boundary

    jmp         exit

move_new_row:
    inc         r14
    mov         r15, 1
    pushr       r12, r13, rax, rbx, rcx, rdx, rsi, rdi
    printchar_nopreserve [wall]
    println
    popr        rdi, rsi, rdx, rcx, rbx, rax, r13, r12
    cmp         r14, HEIGHT
    jge         draw_grid_done
    printchar   [wall]
    jmp         draw_grid_start

print_space:
    printchar   [blank]
    jmp         draw_grid_cont

print_snake_head:
    printchar   [snakehead]
    jmp         draw_grid_cont

print_snake_body:
    printchar   [snakebody]
    jmp         draw_grid_cont

draw_horizontal_boundary:
    lea         r12, [blank]
    mov         r13, 1
    call        print_string
    mov         rcx, WIDTH
draw_horizontal_boundary_loop:
    push        rcx
    printchar   [wall]
    pop         rcx
    loop        draw_horizontal_boundary_loop
    println
    ret


clear_screen:
    pushr       r12, r13
    lea         r12, [clr]
    mov         r13, 2
    call        print_string
    popr        r13, r12
    ret
