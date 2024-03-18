%ifndef __malloc_asm__
%define __malloc_asm__


%define page_size 4096

%define mmap_prot_flag   3
%define mmap_anon_flag   34

%define tiny_heap_allocation_size   4 * page_size
%define tiny_block_size             tiny_heap_allocation_size/128
%define small_heap_allocation_size  32 * page_size
%define small_block_size            small_heap_allocation_size/128

%define true    1
%define false   0

%define tiny    1
%define small   2
%define large   3

%define __base_pointer          rbp
%define __stack_pointer         rsp
%define __address_size          8 ;bytes


%macro __stack_push 0
    push __base_pointer
    mov __base_pointer, __stack_pointer
%endmacro

%macro __stack_pop 0
    mov __stack_pointer, __base_pointer
    pop __base_pointer
    ret
%endmacro

%macro __mmap 6
mov __second_sys_reg, %2
mov __third_sys_reg, %3
mov __fourth_sys_reg, %4
mov __fifth_sys_reg, %5
mov __sixth_sys_reg, %6
mov __first_sys_reg, %1
syscall(SYS_MMAP)
%endmacro

%macro __munmap 2
mov __second_sys_reg, %2
mov __first_sys_reg, %1
syscall(SYS_MUNMAP)
%endmacro

%macro __write 3
    mov __first_sys_reg,    %1
    mov __second_sys_reg,   %2
    mov __third_sys_reg,    %3
    syscall(1)
%endmacro

%macro __exit 1
    mov __first_sys_reg,    %1
    syscall(SYS_EXIT)
%endmacro sys_exit

%macro __syscall 1
    push r11
    push rcx
    mov __sys_call_number_reg,  %1
    syscall
    pop rcx
    pop r11
%endmacro

; syscalls
%define     SYS_EXIT            60
%define     SYS_OPEN            2
%define     SYS_CLOSE           3
%define     SYS_LSEEK           8
%define     SYS_READ            0
%define     SYS_WRITE           1
%define     SYS_MMAP            9
%define     SYS_MUNMAP          11

; constants
%define     EXIT SUCCESS        0
%define     EXIT_FAIL           1


%define     option_read_only           0
%define     option_write_only          1
%define     option_read_write          2
%define     option_create              64
%define     option_append              1024

%define     seek_curr         1
%define     seek_set          0
%define     seek_end          2

; reg

%define __first_sys_reg         rdi
%define __second_sys_reg        rsi
%define __third_sys_reg         rdx
%define __fourth_sys_reg        r10
%define __fifth_sys_reg         r8
%define __sixth_sys_reg       r9

%define __sys_call_number_reg   rax

%define syscall(num) __syscall num

%macro __return 1
    mov rax, %1
    __stack_pop
%endmacro

%define sys_exit(status) __exit status

%define sys_write(fd, ptr, len) __write fd, ptr, len

%define sys_open(name, option, permission) __open name, option, permission

%define sys_mmap(a, b, c, d, e, f) __mmap a, b, c, d, e, f

%define sys_munmap(a, b) __munmap a, b

%macro __align_up_16 1
        mov rax, %1
        add rax, 15
        and rax, ~15
%endmacro

%define alignforward16(a) __align_up_16 a

%macro __putsimm 1
section .data
align 16
%%str:  db %1, 10
%%len:  equ $ - %%str
align 16
section .text
        sys_write(1, %%str, %%len)
        xor rax, rax
%endmacro

%define print_string_immediate(char) __putsimm char

struc Heap
    hprev:           resq   1
    hnext:           resq   1
    group:           resd   1
    block_count:     resd   1
    total_size:      resd   1
    free_size:       resd   1
endstruc

struc Block
    bprev:            resq  1
    bnext:            resq  1
    data_size:        resd  1
    freed:            resd  1
endstruc


%macro __heap_shift     1
        add %1, Heap_size
%endmacro

%macro __heap_unshift   1
        sub %1, Heap_size
%endmacro

%macro __block_shift    1
        add %1, Block_size
%endmacro

%macro __block_unshift 1
sub %1, Block_size
%endmacro

%define heap_shift(a)       __heap_shift a
%define heap_unshift(a)     __heap_unshift a
%define block_shift(a)      __heap_shift a
%define block_unshift(a)    __heap_unshift a

section .bss
HeapAnchor: resq 1
section .text

;; block ptr in rdi
GetLastBlock:
        __stack_push
.L1:    cmp qword [rdi+8], 0
        je .L2
        mov rdi, qword [rdi+8]
        jmp .L1
.L2:    __return rdi

;; heap in rdi
;; block in rsi
;; uses rcx
MergePrevBlock:
        __stack_push
        cmp rdi, 0 ;check if heap is null
        je .EXT
        cmp rsi, 0 ;check if block is null
        je .EXT
        cmp qword [rsi+bprev], 0 ;check if block has prev
        je .EXT 
        mov rax, [rsi+bprev] ; mov block prev
        ;%define block_prev rax
        cmp qword [rax + freed], 0 ; check if prev is free
        je .EXT
        mov rcx, [rsi+bnext] ; mov block next
        ;%define block_next rcx
        mov [rax + bnext], rcx ;prev-> next = block->next 
        cmp rcx, 0 ; check if block has next
        je .L1
        mov [rcx+bnext], rax
.L1:    mov esi, dword [rsi + data_size]
        add dword[rax + data_size], esi
        add dword[rax + data_size], Block_size
        dec dword[rdi +block_count]
        __return rax

.EXT:   __return 0



;; heap in rdi
;; block in rsi
;; uses rcx
MergeNextBlock:
        __stack_push
        cmp rdi, 0 ;check if heap is null
        je .EXT
        cmp rsi, 0 ;check if block is null
        je .EXT
        cmp qword [rsi+bnext], 0 ;check if block has next
        je .EXT 
        mov rcx, [rsi+bnext] ; mov block next
        ;%define block_next rcx
        cmp qword [rcx + freed], 0 ; check if next is free
        je .EXT
        mov eax, dword[rcx+data_size]
        add dword[rsi + data_size], eax
        add dword[rsi +data_size], Block_size
        cmp qword[rsi + bnext], 0
        je .L1
        mov rax, [rcx+bnext] ;;move next->next
        cmp rax, 0
        je .L1
        mov [rax + bprev], rsi ;; next->next->prev
.L1:    mov [rsi+bnext], rax
        dec dword[rdi + block_count]
.EXT:   __return 0

;; heap in rdi
;; block in rsi
;; uses rcx
MergeBlock:
        __stack_push
        push rdi
        push rsi
        call MergeNextBlock
        pop rsi
        pop rdi
        call MergePrevBlock
        __return rax

;; heap in rdi
;; block in rsi
;; uses rcx
RemoveBlockIfLast:
        __stack_push
        cmp dword[rsi+freed], 0
        je .EXT
        cmp qword[rsi+bnext], 0
        jne .EXT
        cmp qword[rsi+bprev], 0
        je .L1  
        mov rcx, [rsi+bprev]
        mov qword[rcx+bnext], 0
.L1:    mov ecx, dword[rsi + data_size]
        add ecx, Block_size

        add dword[rdi+free_size], ecx
        dec dword[rdi+block_count]
.EXT:   __return 0


;; block in rdi
%macro __setup_block 2
        mov qword[%1+bprev], 0
        mov qword[%1+bnext], 0
        mov dword[%1+data_size], %2
        mov dword[%1+freed], 0
%endmacro

%define setup_block(block, size) __setup_block block, size

;; block in rdi %1
;; size in rsi %2
;; heap in rdx %3
;; uses rcx
DivideBlock:
        __stack_push
        push rdi ;push block
        block_shift(rdi) ;; shift
        add rdi, rsi ;; add size
        ;;rdi-> new free block
        mov rcx, [rsp]; pop block
        mov rcx, [rcx+bnext] ;; load block->next
        sub rcx, rdi ; block->next - free_block
        setup_block(rdi, ecx) ;; setup block
        mov dword[rdi+freed], true
        mov rcx, [rsp]; load block
        mov [rdi + bprev], rcx ;
        mov rcx, [rcx+bnext]
        mov [rdi+bnext], rcx
        inc dword[rdx+block_count]
        mov rcx, [rsp]
        mov [rcx+bnext], rdi
        mov dword[rcx+data_size], esi
        mov dword[rcx+freed], false
        __return 0

;; store result in %2
%macro __get_heap_group_from_block_size 2
        cmp %1, tiny_block_size
        jg .%%L2
        mov %2, tiny
        jmp .%%EXT
.%%L2:  cmp %1, small_block_size
        jg .%%L3
        mov %2, small
        jmp .%%EXT
.%%L3:  mov %2, large
.%%EXT:
%endmacro

%define get_heap_group_from_block_size(a, b) __get_heap_group_from_block_size a, b

%macro __get_heap_size_from_block_size 2
        ;; %1 not used
        get_heap_group_from_block_size(%1, %2)
        cmp %2, tiny
        jne .%%L1
        mov %2, tiny_heap_allocation_size
        jmp .%%EXT
.%%L1:  cmp %2, small
        jne .%%L3
        mov %2, small_heap_allocation_size
        jmp .%%EXT
.%%L3:  add %1, Heap_size
        add %1, Block_size 
        mov %2, %1
.%%EXT:
%endmacro

%define get_heap_size_from_block_size(a, b) __get_heap_size_from_block_size a, b


;rdi -> heap pointer pointer
;rsi -> block pointer pointer
;rdx -> heap pointer
;rcx -> void pointer
SearchPtr:
        __stack_push
        push rdx ;; save heap
        push 0 ;; push a null block ptr
.WO:    mov rdx, [rsp + 8] ;; heap in rdx
        cmp rdx, 0
        je .EXTWO
        heap_shift(rdx) ;; rdx now heapshifted
        ;; rdx now is block
        mov qword[rsp], rdx ;; store the block
.WI:    cmp qword [rsp], 0 ;; check if block is null
        je .EXTWI ;; if null exit loop
        mov rdx, qword [rsp] ;; store block in rdx
        block_shift(rdx) ;; shitf block
        cmp rcx, rdx ;; compare block with ptr
        jne .WINEXT ;; go next if not equal
.EXTWIRET:
        mov rdx, [rsp + 8] ;; heap
        mov qword[rdi], rdx ;; heap
        mov rdx, [rsp] ;; block
        ;cmp dword[rdx+freed], 0
        ;sys_exit(56)
        mov qword[rsi], rdx ;; block
        ;; return from here
        __return 0
.WINEXT:
        mov rdx, qword[rsp] ; block in rdx
        mov rdx, [rdx+bnext] ; block->next in rdx
        mov qword[rsp], rdx  ; store block
        jmp .WI ;; jump to loop begining
.EXTWI: ;; exit inner loop
        mov rdx, [rsp + 8] ; heap in rdx
        mov rdx, [rdx+hnext] ; heap->next in rdx
        mov qword[rsp + 8], rdx
        jmp .WO
.EXTWO: mov qword[rdi], 0
        mov qword[rsi], 0
        __return 0


;; heap in rdi
;; use rax
IsLastOfPreallocated:
        __stack_push
        push 0 ;; heap_el
        push 0 ;; group
        push 0 ;; i
        mov qword[rsp + 16], HeapAnchor
        mov eax, dword[rdi+group]
        mov [rsp + 8], rax
        cmp rax, large
        jne .L1
        __return 0
.L1:    cmp qword[rsp + 16], 0
        je .EXT
        mov rax, [rsp+16]
        mov eax, dword[rax+group]
        cmp eax, dword[rsp+8]
        jne .NXT
        inc qword[rsp]
.NXT:   mov rax, [rsp+16]
        mov rax, [rax+hnext]
        mov [rsp+16], rax
        jmp .L1
.EXT:   cmp qword[rsp], 1
        jne .RF
        __return true
.RF:    __return false


;; rdi list_start
;; rsi group
;; rdx required size
GetAvailableHeap:
        __stack_push
        push 0
        mov qword[rsp], rdi
.L1:    cmp qword[rsp], 0
        je .EXT
        ;========loop body ============
        mov rax, qword[rsp]
        cmp dword[rax+group], esi
        jne .ADV
        cmp dword[rax+free_size], edx
        jl .ADV
        __return rax
;==========advance==========
.ADV:   mov rax, qword[rsp]
        mov rax, [rax+hnext]
        mov qword[rsp], rax
        jmp .L1
.EXT:   __return 0


;; heap in rdi
GetLastHeap:
        __stack_push
        cmp rdi, 0
        jne .L1
        __return 0
.L1:    cmp rdi, 0
        je .EXT
        mov rdi, [rdi+hnext]
        jmp .L1
.EXT:   __return 0


;; heap in rdi
;; size in rsi
AppendEmptyBlock:
        __stack_push
        push rdi;; save heap
        push 0 ;new block
        push 0 ;last block
        heap_shift(rdi)
        mov qword[rsp+8], rdi ; save new block
        heap_unshift(rdi)
        cmp dword[rdi+block_count], 0
        ;mov r15d, dword[rdi+block_count];================
        jle .L2 ;; skip to l2
        mov rdi, [rsp+8]
        call GetLastBlock
        mov [rsp], rax ;save last block
        mov rdi, [rax+data_size]
        mov [rsp+8], rdi
        block_shift(rax)
        add [rsp+8], rax
.L2:    mov rax, [rsp+8]
        setup_block(rax, esi)
        mov rax, [rsp+16] ;; heap
        cmp dword[rax+block_count], 0
        jle .L3 ;skip to l3
        mov rax, [rsp]  ; last block
        mov rdi, [rsp+8] ;new block
        mov [rax+bnext], rdi
        mov [rdi+bprev], rax
.L3:    mov rax, [rsp+16] ;;heap
        inc dword[rax+block_count]
        mov rdi, [rsp+8] ;; new block
        mov esi, dword[rdi+data_size] ;; data size
        sub dword[rax+free_size], esi
        sub dword[rax+free_size], Block_size
        ;mov rax, [rsp+8]
        block_shift(rdi)
        __return rdi




;; size in rdi
GetHeapOfBlockSize:
        __stack_push
        push rdi
        push qword[HeapAnchor] ;default heap
        push 0 ;heap group
        push 0 ;heap
        get_heap_group_from_block_size(rdi, rax)
        mov dword[rsp+8], eax ;; store group
        mov rdi, [rsp + 16] ;; heap
        mov esi, dword[rsp + 8] ;; group
        mov rdx, [rsp + 24]
        add rdx, Block_size
        call GetAvailableHeap
        mov [rsp], rax ;; save heap
        cmp rax, 0
        jne .L1
        mov edi, dword[rsp+8] ; group
        mov esi, dword[rsp+24] ; size
        call CreateHeap
        cmp rax, 0
        jne .L2
        __return 0
.L2:    mov [rsp], rax ;; save heap
        mov rdi, [HeapAnchor]
        mov qword[rax+hnext], rdi ;; change
        cmp qword[rax+hnext], 0
        je .L3  
        mov rdi, [rax+hnext] ;; ptr to next
        mov [rdi+hprev], rax
.L3:    mov [HeapAnchor], rax
.L1:    __return [rsp]



;rdi group
;rsi block size
CreateHeap:
__stack_push
        push rdi
        push 0 ;heap_size
        push 0 ;heap
        get_heap_size_from_block_size(rsi, rax)
        mov [rsp+8], rax
        sys_mmap(0, rax, mmap_prot_flag, mmap_anon_flag, -1, 0)
        mov [rsp], rax
        cmp rax, -1
        jne .L1
        __return 0
.L1:
;; zero heap here(TODO)
        mov edi, dword[rsp+16]
        mov dword[rax + group], edi;rdi
        mov rdi, [rsp + 8] ;; heap size
        mov [rax + total_size], rdi
        mov [rax + free_size], rdi
        sub qword[rax + free_size], Heap_size
        __return rax



;; heap in rdi
DeleteHeapIfEmpty:
        __stack_push
        push rdi
        cmp dword[rdi+block_count], 0
        ;mov r15d, dword[rdi+block_count]
        jne .L1
        __return 0
.L1:    cmp qword[rdi+hprev], 0
        jne .L2 
        mov rdi, [rdi+hprev]
        mov rax, [rdi+hnext]
        mov [rdi+hnext], rax
.L2:    mov rdi, [rsp]
        cmp qword[rdi+hnext], 0
        jne .L4
        mov rdi, [rdi+hnext]
        mov rax, [rdi+hprev]
        mov [rdi+hprev], rax
.L4:    mov rdi, [rsp]
        call IsLastOfPreallocated
        cmp rax, 0
        jne .L5
        mov rdi, [rsp]
        cmp rdi, HeapAnchor
        jne .SKP
        mov rdi, [rdi+hnext]
        mov [HeapAnchor], rdi
.SKP:   mov rdi, [rsp]
        mov rax, [rdi+total_size]
        sys_munmap(rdi, rax)
.L5:    __return 0

;size in rdi
TryFillingAvailableBlock:
__stack_push
        push rdi
        push 0 ;block
        push 0 ;heap
        lea rsi, [rsp]
        lea rdx, [rsp+8]
        call FindAvailableBlock
        cmp qword[rsp], 0
        je .EXT
        cmp qword[rsp+8], 0
        je .EXT
        mov rdi, [rsp+8]
        mov esi, dword[rsp+16]
        mov rdx, [rsp]
        call DivideBlock
        mov rax, [rsp+ 8]
        __return rax

.EXT:   __return 0

;; rdi -> size
;; rsi -> heap result ptr
;; rdx -> block result ptr
FindAvailableBlock:
        __stack_push
        push HeapAnchor ; heap anchor
        push 0 ; block
        push 0 ; group
        get_heap_group_from_block_size(rdi, rax)
        mov [rsp], rax
.OUTERLOOP:
        cmp qword[rsp+16], 0
        je .EXITOUTER
        mov rax, [rsp+16]
        heap_shift(rax)
        mov [rsp+8], rax ;; block
.INNERLOOP:
        mov rax, [rsp+16]
        mov rax, [rax+group] ;; heap group in rax
        cmp rax, qword[rsp]  ;; compare
        jne .EXITINNER
        cmp qword[rsp+8], 0 ;; check if block is null
        je .EXITINNER
        ;=============================loop body
        cmp dword[rsp+freed], true ;; source of error
        jne .ADVINNER
        mov eax, edi
        add eax, Block_size
        cmp eax, dword[rsp+data_size] ;; error
        jl .ADVINNER
        mov rax, [rsp+16]
        mov [rsi], rax
        mov rax, [rsp+8]
        mov [rdx], rax
        __return 0
        ;=============================
.ADVINNER:
        mov rax, [rsp+8]
        mov rax, [rax+bnext]
        mov [rsp+8], rax
        jmp .INNERLOOP
.EXITINNER:

.ADVOUTER:
        mov rax, [rsp+16]
        mov rax, [rax+hnext]
        mov [rsp+16], rax
        jmp .OUTERLOOP
.EXITOUTER:
        mov qword[rsi], 0
        mov qword[rdx], 0

        __return 0

;size in rdi
StartMalloc:
        __stack_push
        push 0 ;; heap
        push 0 ;; block
        push 0 ;; res ptr
        cmp rdi, 0 ;; check if size is zero
        jne .L1
        __return 0
.L1:    alignforward16(rdi) ;; aligned size in rax
        push rax
        mov rdi, rax
        call TryFillingAvailableBlock
        cmp rax, 0
        je .L2
        block_shift(rax)
        __return rax
.L2:    mov rdi, [rsp]
        call GetHeapOfBlockSize
        cmp rax, 0
        jne .L3
        __return 0
 .L3:   mov qword[rsp+16], rax ;; store heap
        mov rdi, rax
        mov esi, dword[rsp];size
        call AppendEmptyBlock
        ;; block returned in rax
        __return rax




;; ptr in rdi
StartFree:
        __stack_push
        push qword[HeapAnchor];heap
        push 0 ; block
        push 0 ; ret
        cmp qword[HeapAnchor], 0
        jne .L1
        __return 0
.L1:    cmp rdi, 0
        jne .L2
        __return 0
.L2:    mov rcx, rdi ; ptr to searxh
        lea rdi, [rsp+16] ; heap ptr
        lea rsi, [rsp+8] ; block ptr
        mov rdx, [rsp+16] ; heap
        call SearchPtr
        cmp qword[rsp+8], 0 ;check if block is null
        jne .L3
        ;sys_exit(45)
        __return 0
.L3:    cmp qword[rsp+16], 0 ; check if heap is null
        jne .L4
        __return 0
.L4:    mov rax, [rsp+8]
        mov eax, dword[rax+freed]
        cmp eax, true
        jne .L5
        print_string_immediate("Double free detected");
        sys_exit(69)
.L5:    mov rax, [rsp+8]
        mov dword[rax+freed], true
        mov rdi, [rsp+16]
        mov rsi, [rsp+8]
        call MergeBlock
        cmp rax, 0
        je .L6
        mov [rsp+8], rax ;; source of error
.L6:    mov rdi, [rsp+16]
        mov rsi, [rsp+8]
        call RemoveBlockIfLast
        mov rdi, [rsp+16]
        call DeleteHeapIfEmpty

    __return 0


%macro __malloc 1
        mov rdi, %1
        call StartMalloc
        cmp rax, 0
        jne .%%L1
        print_string_immediate("malloc failed")
        sys_exit(1)

.%%L1:
%endmacro

%macro __free 1
        mov rdi, %1
        call StartFree
%endmacro

%define malloc(a)   __malloc a
%define free(a)     __free   a

%endif