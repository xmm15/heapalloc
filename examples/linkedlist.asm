%include "../src/alloc.asm"

struc Node
    Next: resq  1
    Val:  resq  1
endstruc

%define void    0
%macro __list_init 1
        mov rdi, %1
        call ListInit
%endmacro

%macro __list_append 2
        mov rdi, %1
        mov rsi, %2
        call ListAppend
%endmacro

%macro __delete_list 1
mov rdi, %1
call ListDelete
%endmacro

%define list_init(a)        __list_init a
%define list_append(a, b)   __list_append a, b
%define delete_list(a)      __delete_list a


section .text
global _start
_start:

        list_init(20) ;1
        push rax

        list_append(qword[rsp], 4)
        list_append(qword[rsp], 3)
        list_append(qword[rsp], 25)
        list_append(qword[rsp], 1)

        
        delete_list(qword[rsp])

        sys_exit(0)


ListInit:
__stack_push
        push rdi
        malloc(Node_size)
        pop rdi
        mov qword[rax+Val], rdi
        mov qword[rax+Next], 0
        __return rax

ListAppend:
        __stack_push
        push rdi
        push rsi
        malloc(Node_size)
        pop rsi
        pop rdi

        mov qword[rax+Val], rsi
        mov qword[rax+Next], 0
.L1:
        cmp qword[rdi+Next], 0
        je .L2
        mov rdi, [rdi+Next]
        jmp .L1
.L2:
        mov [rdi+Next], rax
        __return 0

ListDelete:
        __stack_push
.L1:    
        push qword[rdi+Next]
        free(rdi)
        pop rdi
        cmp rdi, 0
        je .L2
        jmp .L1
.L2:
        __return 0


