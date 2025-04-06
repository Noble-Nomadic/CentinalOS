;-----------------------------------------
; print_char: Print a single character
;-----------------------------------------
[org 0x0010]
global print_char

print_char:
    mov ah, 0x0E
    int 0x10
    ret

;-----------------------------------------
; print_string: Print a full string
;-----------------------------------------

global print_string

print_string:
    push si
.loop:
    lodsb
    test al, al
    jz .done
    call print_char
    jmp .loop
.done:
    pop si
    ret
