.intel_syntax noprefix

.include "src/system.s"
.include "src/print.s"

.global _start

.equ WIDTH,                     80
.equ HEIGHT,                    30
.equ SNAKE_HEAD,                1
.equ SNAKE_BODY,                2
.equ APPLE,                     3
.equ SNAKE_HEAD_INITIAL_X,      WIDTH / 2
.equ SNAKE_HEAD_INIIIAL_Y,      HEIGHT / 2

.equ DIRECTION.UP,              0
.equ DIRECTION.DOWN,            1
.equ DIRECTION.LEFT,            2
.equ DIRECTION.RIGHT,           3

.equ KEY.UP,            65
.equ KEY.DOWN,          66
.equ KEY.RIGHT,         67
.equ KEY.LEFT,          68
.equ KEY.ESCAPE,        27
.equ KEY.ESCAPE_SEQ,    91

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

.macro set_on_snakes_head object
    lea     rsi, [grid]
    xor     rax, rax
    xor     rbx, rbx
    mov     ax, [snakeheadx]
    mov     bx, [snakeheady]
    mov     dx, WIDTH
    /* snakehead location = snakeheady * WIDTH + snakeheadx */
    imul    bx, dx
    add     bx, ax
    mov     byte ptr [rsi + rbx], \object
    /* mov    byte ptr [rsi + rbx - 1], SNAKE_BODY
    mov     byte ptr [rsi + rbx - 2], SNAKE_BODY */
.endm

.data

wall:           .ascii "#"
newline:        .ascii "\n"
clr:            .ascii "\033c"
blank:          .ascii " "
apple:          .ascii "@"
snakehead:      .ascii "*"
snakebody:      .ascii "+"
scoretext:      .ascii "Score: "
scoretextlen    = $ - scoretext
snakeheady:     .short SNAKE_HEAD_INIIIAL_Y
snakeheadx:     .short SNAKE_HEAD_INITIAL_X
sleepreq:       .quad 1, 0
score:          .quad 0
currentdir:     .byte DIRECTION.RIGHT

.bss

.lcomm grid WIDTH * HEIGHT
.lcomm appleloc 1
.lcomm old_termios SIZEOF_TERMIOS
.lcomm new_termios SIZEOF_TERMIOS
.lcomm input_buffer 3

.text

    /* required by debugger */
main:
    jmp         _start

_start:
    /* create a new stack frame */
    push        rbp
    mov         rbp, rsp
    call        config_terminal_settings
    call        prepare_grid

gameloop:
    call        draw_grid
    call        readkey
    call        sleep
    call        move
    jmp         gameloop
    jmp         exit


draw_grid:
    call        clear_screen
    lea         r12, [scoretext]
    mov         r13, scoretextlen
    call        print_string
    mov         r12, score
    call        print_usigned_int
    println
    /* draw the top wall */
    call        draw_horizontal_boundary
    printchar_nopreserve [wall]
    /* row index */
    mov         r14, 1
    /* column index */
    mov         r15, 1
    xor         rcx, rcx
    lea         rsi, [grid]
draw_grid_start:
    xor         rax, rax
    lodsb
    cmp         al, NULL
    je          print_space
    cmp         al, SNAKE_HEAD
    je          print_snake_head
    cmp         al, SNAKE_BODY
    je          print_snake_body
    cmp         al, APPLE
    je          print_apple
draw_grid_cont:
    inc         rcx
    inc         r15
    cmp         r15, WIDTH
    jg          move_new_row
    jmp         draw_grid_start
draw_grid_done:
    /* draw the bottom wall */
    call        draw_horizontal_boundary
    ret

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

print_apple:
    printchar   [apple]
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

    /* prepare teh grid, snake and apple */
prepare_grid:
    call        place_head
    call        place_apple
    ret

remove_head:
    set_on_snakes_head NULL
    ret

place_head:
    set_on_snakes_head SNAKE_HEAD
    ret

place_apple:
    getrandomint 0, WIDTH*HEIGHT
    mov         r12, rax
    lea         rsi, [grid]
    /* if the location is not empty, try again */
    cmp         byte ptr [rsi + r12], 0
    jne         place_apple
    mov         byte ptr [rsi + r12], APPLE
    ret

clear_screen:
    pushr       r12, r13
    lea         r12, [clr]
    mov         r13, 2
    call        print_string
    popr        r13, r12
    ret

sleep:
    mov         qword ptr [sleepreq], 1
    mov         qword ptr [sleepreq + 32], 0
    mov         rax, SYS_NANOSLEEP
    lea         rdi, [sleepreq]
    syscall
    ret

move:
    /* call        remove_head */

    cmp         byte ptr [currentdir], DIRECTION.UP
    je          moveup
    cmp         byte ptr [currentdir], DIRECTION.DOWN
    je          movedown
    cmp         byte ptr [currentdir], DIRECTION.LEFT
    je          moveleft
    cmp         byte ptr [currentdir], DIRECTION.RIGHT
    je          moveright

moveup:
    call        remove_head
    mov         byte ptr [currentdir], DIRECTION.UP
    dec         dword ptr [snakeheady]
    call        place_head
    ret

movedown:
    call        remove_head
    mov         byte ptr [currentdir], DIRECTION.DOWN
    inc         dword ptr [snakeheady]
    call        place_head
    ret

moveleft:
    call        remove_head
    mov         byte ptr [currentdir], DIRECTION.LEFT
    dec         dword ptr [snakeheadx]
    call        place_head
    ret

moveright:
    call        remove_head
    mov         byte ptr [currentdir], DIRECTION.RIGHT
    inc         dword ptr [snakeheadx]
    call        place_head
    ret

readkey:
    mov         rax, SYS_READ
    mov         rdi, STDIN
    lea         rsi, [input_buffer]
    mov         rdx, 3
    syscall

    lea         rsi, [input_buffer]
    lodsb
    lodsb
    lodsb
    cmp         rax, KEY.UP
    je          moveup
    cmp         rax, KEY.DOWN
    je          movedown
    cmp         rax, KEY.LEFT
    je          moveleft
    cmp         rax, KEY.RIGHT
    je          moveright
    ret

config_terminal_settings:
    /* save original terminal settings */
    tcgets      [old_termios]
    /* copy old settings into new settings */
    tcgets      [new_termios]
    /* modify new settings */
    and         word ptr [new_termios + 12], CLEAR_FLAG
    mov         byte ptr [new_termios + 18 + VMIN], 3
    mov         byte ptr [new_termios + 18 + VTIME], 0

    mov         rax, SYS_IOCTL
    mov         rdi, STDIN
    mov         rsi, TCSETS
    lea         rdx, [new_termios]
    syscall
    ret
