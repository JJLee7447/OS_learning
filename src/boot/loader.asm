%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR

dw 0x55aa                           ; 魔数

xchg bx,bx                           ; bochs 魔数断点
                                    ; 输出背景色绿色，前景色红色，并且跳动的字符串"1 MBR"
mov si ,loading
call print
xchg bx,bx                           ; bochs 魔数断点



detect_memory:
    xor ebx, ebx                    ; 将ebx清零 xor 效率高于 mov

                                    ; 将 es:edi 指向 adrs_buffer
    mov ax,0
    mov es,ax                       
    mov edi,adrs_buffer             

    mov edx, 0x534d4150             ; "SMAP" 固定签名

.next
    mov eax, 0xe820                 ; BIOS 中断 0x15 功能号
    mov ecx, 20                     ; adrs 大小 单位字节

    int 0x15                        ; 调用 BIOS 中断

                                    ; 检测返回值
    jc error                        ; 如果 CF=1 则发生错误，跳转到 error 标号处  
    add di,cx                       ; 将缓存指针指向下一个结构体

    inc word [adrs_count]           ; 将结构体数量加一

    cmp ebx,0                       ; ebx 为 0 说明已经遍历完所有结构体,检测结束
    jne .next                       ; 如果 ebx 不为 0 则继续循环

    mov si,detecting
    call print

    xchg bx,bx                      ; bochs 魔数断点


                                    ; 将adrs 缓冲区内容送入 eax, ebx ,edx 查看
    mov cx,[adrs_count]             ; 将结构体数量存入 ax

    mov si,0                         ; 初始化结构体指针

.show:
    mov eax, [adrs_buffer+si]       
    mov ebx, [adrs_buffer+si+8]
    mov edx, [adrs_buffer+si+16]
    add si, 20
    xchg bx,bx 
    loop .show

print:

    mov ah,0x0e
.next
    mov al,[si]
    cmp al,0
    jz .done
    int 0x10
    inc si
    jmp .next
.done
    ret

loading:
    db "Loading Jinix...",10,13,0
detecting:
    db "Detecting Memory Success...",10,13,0

error:
    mov si,.error_msg
    call print
    hlt
    jmp $

    .error_msg db "Loading Jinix Error !!!",10,13,0

adrs_count:
    dw 0
adrs_buffer:


jmp $		                        ; 通过死循环使程序悬停在此


