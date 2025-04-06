[org 0x0010]
global get_key

;-----------------------------------------
; get_key: Get a single character input
;-----------------------------------------
get_key:
    mov ah, 0x00
    int 0x16
    mov ah, 0x0E
    int 0x10
    ret


;-----------------------------------------
; get_line: Read a full line of input
;-----------------------------------------

global get_line

get_line:
    mov si, line_buffer
.loop:
    call get_key
    cmp al, 0x0D
    je .done
    stosb
    jmp .loop
.done:
    mov al, 0
    stosb
    ret

section .bss
line_buffer resb 256
