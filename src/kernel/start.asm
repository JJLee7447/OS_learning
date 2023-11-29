[bits 32]

global _start
_start:
                                          ; 打印字符 kernel
    mov byte [0xb8000], 'k'
    mov byte [0xb8002], 'e'
    mov byte [0xb8004], 'r'
    mov byte [0xb8006], 'n'
    mov byte [0xb8008], 'e'
    mov byte [0xb800a], 'l'

    jmp $