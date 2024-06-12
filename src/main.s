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
.equ SNAKE_HEAD_INITIAL_Y,      HEIGHT / 2

.equ DIRECTION.UP,              0
.equ DIRECTION.DOWN,            1
.equ DIRECTION.LEFT,            2
.equ DIRECTION.RIGHT,           3

.equ KEY.UP,                    65
.equ KEY.DOWN,                  66
.equ KEY.RIGHT,                 67
.equ KEY.LEFT,                  68
.equ KEY.ESCAPE,                27
.equ KEY.ESCAPE_SEQ,            91

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

.macro printunicode character
    pushr   r12, r13, rax, rbx, rcx, rdx, rsi, rdi
    lea     r12, \character
    mov     r13, 3
    call    print_string
    popr    rdi, rsi, rdx, rcx, rbx, rax, r13, r12
.endm

.macro printunicode_nopreserve character
    lea     r12, \character
    mov     r13, 3
    call    print_string

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

    .if \object == SNAKE_HEAD
    /* check if it had an apple previously */
    
    jmp     check_apple

    .else
    /* body moves forward (replicate it by just putting a body in the grid) */
    mov     byte ptr [rsi + rbx], SNAKE_BODY
    /* mov    byte ptr [rsi + rbx - 1], SNAKE_BODY
    mov     byte ptr [rsi + rbx - 2], SNAKE_BODY */
    .endif
.endm

.data

horizontalwall:     .byte 0xe2, 0x94, 0x80 # ─
verticalwall:       .byte 0xe2, 0x94, 0x82 # │
topleftwall:        .byte 0xe2, 0x94, 0x8c # ┌
toprightwall:       .byte 0xe2, 0x94, 0x90 # ┐
bottomleftwall:     .byte 0xe2, 0x94, 0x94 # └
bottomrightwall:    .byte 0xe2, 0x94, 0x98 # ┘
apple:              .byte 0xe2, 0x98, 0x85 # ★
snakehead:          .byte 0xe2, 0x9a, 0x89 # ⚉
snakebody:          .byte 0xe2, 0x99, 0xbc # ♼
newline:            .ascii "\n"
clr:                .ascii "\033c"
blank:              .ascii " "
scoretext:          .ascii "Score: "
scoretextlen        = $ - scoretext
snakeheady:         .short SNAKE_HEAD_INITIAL_Y
snakeheadx:         .short SNAKE_HEAD_INITIAL_X
sleepreq:           .quad 1, 0
score:              .quad 0
currentdir:         .byte DIRECTION.RIGHT
    /* doubly-linked list to stores structs of snake's body parts */
    /* the C equivalent of the body part would look something like this
    /* struct BodyPart {
        short x;
        short y;
        struct BodyPart *pre;
        struct BodyPart *next;
    };
    */
snakebody1:
    .short SNAKE_HEAD_INITIAL_X - 1
    .short SNAKE_HEAD_INITIAL_Y
    .quad snakeparts
    .quad snakebody2
snakebody2:
    .short SNAKE_HEAD_INITIAL_X - 2
    .short SNAKE_HEAD_INITIAL_Y
    .quad snakebody1
    .quad NULL
tail:               .quad snakebody2
snakeparts:
    /* head of the linked list */
    .short SNAKE_HEAD_INITIAL_X
    .short SNAKE_HEAD_INITIAL_Y
    .quad NULL
    .quad snakebody1

.equ SIZEOF_BODYPART, SIZE_OF_SHORT + SIZE_OF_SHORT + SIZE_OF_INT + SIZE_OF_INT


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
    println
    lea         r12, [scoretext]
    mov         r13, scoretextlen
    call        print_string
    mov         r12, score
    call        print_usigned_int
    println
    println
    /* draw the top wall */
    printunicode_nopreserve [topleftwall]
    call        draw_horizontal_boundary
    printunicode_nopreserve [toprightwall]
    println
    printunicode_nopreserve [verticalwall]
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
    printunicode_nopreserve [bottomleftwall]
    call        draw_horizontal_boundary
    printunicode_nopreserve [bottomrightwall]
    println
    ret

move_new_row:
    inc         r14
    mov         r15, 1
    pushr       r12, r13, rax, rbx, rcx, rdx, rsi, rdi
    printunicode_nopreserve [verticalwall]
    println
    popr        rdi, rsi, rdx, rcx, rbx, rax, r13, r12
    cmp         r14, HEIGHT
    jge         draw_grid_done
    printunicode [verticalwall]
    jmp         draw_grid_start

print_space:
    printchar   [blank]
    jmp         draw_grid_cont

print_snake_head:
    printunicode [snakehead]
    jmp         draw_grid_cont

print_snake_body:
    printunicode [snakebody]
    jmp         draw_grid_cont

print_apple:
    printunicode [apple]
    jmp         draw_grid_cont

draw_horizontal_boundary:
    /* lea         r12, [blank]
    mov         r13, 1
    call        print_string */
    mov         rcx, WIDTH
draw_horizontal_boundary_loop:
    push        rcx
    printunicode [horizontalwall]
    pop         rcx
    loop        draw_horizontal_boundary_loop
    /* println */
    ret

    /* prepare teh grid, snake and apple */
prepare_grid:
    call        place_head
    mov         byte ptr [rsi + rbx - 1], SNAKE_BODY
    mov         byte ptr [rsi + rbx - 2], SNAKE_BODY
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
    mov         qword ptr [sleepreq + 8], 0
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
move_cont:
    /* allocate memory for a new body part */
    malloc      SIZEOF_BODYPART
    mov         rbx, rax
    /* new body's head is snake head */
    lea         rax, [snakeparts]
    mov         qword ptr [rbx + SIZE_OF_SHORT + SIZE_OF_SHORT], rax
    /* new body's next is head's original next */
    mov         rax, qword ptr [snakeparts + SIZE_OF_SHORT + SIZE_OF_SHORT + SIZE_OF_POINTER]
    mov         qword ptr [rbx + SIZE_OF_SHORT + SIZE_OF_SHORT + SIZE_OF_POINTER], rax
    /* update parent property of head's old next */
    mov         qword ptr [rax + SIZE_OF_SHORT + SIZE_OF_SHORT], rbx
    /*
        when body moves forward, set head's next element to a new body part
        so that, new bodypart1.x = oldhead.x, new bodypart1.y = oldhead.y
    */
    mov         ax, [snakeparts]
    mov         word ptr [rbx], ax
    mov         ax, [snakeparts + SIZE_OF_SHORT]
    mov         word ptr [rbx + SIZE_OF_SHORT], ax
    /* update the head in the linked list */
    mov         ax, [snakeheadx]
    mov         word ptr [snakeparts], ax
    mov         ax, [snakeheady]
    mov         word ptr [snakeparts + SIZE_OF_SHORT], ax
    mov         qword ptr [snakeparts + SIZE_OF_SHORT + SIZE_OF_SHORT + SIZE_OF_POINTER], rbx
    /* 
        remove the tail 
        1. remove the tail from the grid
        2. remove the tail from the linked list
        3. set new last body part as the tail
    */
    xor         rax, rax
    xor         rbx, rbx
    mov         rdx, [tail]
    mov         ax, [rdx]
    mov         bx, [rdx + SIZE_OF_SHORT]
    xor         rdx, rdx
    mov         dx, WIDTH
    /*  location = y * WIDTH + x */
    imul        bx, dx
    add         bx, ax
    lea         rsi, [grid]
    mov         byte ptr [rsi + rbx], NULL
    /* to remove the tail, we simply remove it from it's parent */
    xor         rbx, rbx
    mov         rax, [tail]
    mov         rax, [rax + SIZE_OF_SHORT + SIZE_OF_SHORT]
    mov         qword ptr [rax + SIZE_OF_SHORT + SIZE_OF_SHORT + SIZE_OF_POINTER], NULL
    /* set the new tail */
    mov         qword ptr [tail], rax
    ret

moveup:
    call        remove_head
    mov         byte ptr [currentdir], DIRECTION.UP
    dec         dword ptr [snakeheady]
    call        place_head
    jmp         move_cont

movedown:
    call        remove_head
    mov         byte ptr [currentdir], DIRECTION.DOWN
    inc         dword ptr [snakeheady]
    call        place_head
    jmp         move_cont

moveleft:
    call        remove_head
    mov         byte ptr [currentdir], DIRECTION.LEFT
    dec         dword ptr [snakeheadx]
    call        place_head
    jmp         move_cont

moveright:
    call        remove_head
    mov         byte ptr [currentdir], DIRECTION.RIGHT
    inc         dword ptr [snakeheadx]
    call        place_head
    jmp         move_cont

check_apple:
    cmp         byte ptr [rsi + rbx], APPLE
    je          eat_apple
    mov         byte ptr [rsi + rbx], SNAKE_HEAD
    ret

eat_apple:
    inc         qword ptr [score] 
    mov         byte ptr [rsi + rbx], SNAKE_HEAD
    /* append a new body part to the linked list */
    /* allocate memory for a new body part */
    malloc      SIZEOF_BODYPART
    mov         rbx, rax
    xor         rax, rax
    mov         rdx, [tail]
    mov         ax, [rdx]
    mov         [rbx], ax
    mov         ax, [rdx + SIZE_OF_SHORT]
    mov         [rbx + SIZE_OF_SHORT], ax
    /* set the new element's parent to the previous tail */
    mov         [rbx + SIZE_OF_SHORT + SIZE_OF_SHORT], rdx
    /* set the previous tail's next to the new element */
    mov         [rdx + SIZE_OF_SHORT + SIZE_OF_SHORT + SIZE_OF_POINTER], rbx
    mov         qword ptr [tail], rbx
here:
    lea         rbx, [tail]

    call        place_apple
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
