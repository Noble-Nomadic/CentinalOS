[org 0x0020]               ; Updated segment offset
global print_char
global print_string

print_char:
    mov ah, 0x0E
    int 0x10
    ret

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
