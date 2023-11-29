[org 0x1000]                        ; 设置程序入口地址为 0x1000
dw 0x55aa                           ; 魔数


mov si,loading
call print

detect_memory:
    xor ebx, ebx                    ; 将ebx清零 xor 效率高于 mov

                                    ; 将 es:edi 指向 adrs_buffer
    mov ax,0
    mov es,ax                       
    mov edi,adrs_buffer             

    mov edx, 0x534d4150             ; "SMAP" 固定签名

.next:
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
    jmp prepare_protect_mode



prepare_protect_mode:
    
    cli                             ; 关闭中断

                                    ; 打开 A20 地址线
    in al,0x92                      ; 读取 0x92 端口
    or al,2                         ; 设置 al 的第二位为 1
    out 0x92,al                     ; 写入 0x92 端口

                                    ; 加载 GDT 表
    lgdt [gdt_ptr]                  

                                    ; 启动保护模式
    mov eax,cr0                     ; 读取 cr0
    or eax,0x1                      ; 设置 cr0 的第一位为 1
    mov cr0,eax                     ; 写入 cr0

                                    ; 用调转刷新缓存 
                                    ; 跳转到保护模式代码段
    jmp dword code_selector:protect_mode       
                                    
                                    ; 实模式下的打印函数 ds:si 指向字符串以 0 结尾
print:

    mov ah,0x0e
.next:
    mov al,[si]
    cmp al,0
    jz .done
    int 0x10
    inc si
    jmp .next
.done:
    ret
                                    ; 打印的字符串
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



[bits 32]                            ; 进入保护模式
protect_mode:
    xchg bx,bx                      ; bochs 魔数断点 
                                    ; 初始化段寄存器
    mov ax,data_selector            ; 设置数据段选择子
    mov ds,ax                       ; 将数据段选择子写入 ds
    mov es,ax                       ; 将数据段选择子写入 es
    mov fs,ax                       ; 将数据段选择子写入 fs
    mov gs,ax                       ; 将数据段选择子写入 gs
    mov ss,ax                       ; 将数据段选择子写入 ss

    mov esp,0x10000                 ; 设置栈顶指针

    mov byte [0xb8000],'P'         ; 在屏幕上输出字符 'P' 用于测试

    mov byte [0x200000], 'J'        ; 在内存上输出字符 'J' 用于测试
    xchg bx,bx                      ; bochs 魔数断点
    jmp $                           ; 通过死循环使程序悬停在此


                                    ;数据准备包括 GPT gpt_ptr selector
code_selector equ (1 << 3) | 0      ; 代码段选择子
data_selector equ (2 << 3) | 0      ; 数据段选择子

                                    ; 内存开始的基址 0x00
                                    ; 内存界限 ((4G / 4k ) -1 )
                                    ; 这个表达式的含义是将整个4GB的物理内存划分为4KB的页，
                                    ; 然后从中减去1，以确保 Memory_Limit 表示的是最大合法地址。
Memory_Base equ 0
Memory_Limit equ ((1024* 1024* 1024* 4 ) / (1024 *4)) - 1


                                    ; 定义gdt_ptr
gdt_ptr:
    dw (gdt_end - gdt_base - 1)     ; GDT 表界限
    dd gdt_base                     ; GDT 表基址


                                    ; 定义 GDT 表
                                    ; 第一个描述符必须为 0 (8bytes)
gdt_base:
    dd 0,0                          
                                    ; 代码段与数据段共享同一个内存区域
                                    ; 定义代码段描述符
gdt_code:
    dw Memory_Limit & 0xffff        ; 段界限 0~15 位
    dw Memory_Base & 0xffff         ; 段基址 0~15 位 
    db (Memory_Base >> 16 )& 0xff   ; 段基址 16~23 位
                                    ; P(1) DPL(00) S(1) Type(1010) 代码 - 非依从 - 可读 - 没有被访问过 
    db 0b_1_00_1_1_0_1_0              
                                    ; G(1) D(1) 0(1) AVL(0) Limit(16 ~ 19)
    db 0b1_1_0_0_0000 | (Memory_Limit>>16 )& 0x0f
    db (Memory_Base >> 24 )& 0xff   ; 段基址 24~31 位
                                    

                                    ; 定义数据段描述符
gdt_data:
    dw Memory_Limit & 0xffff        ; 段界限 0~15 位
    dw Memory_Base & 0xffff         ; 段基址 0~15 位 
    db (Memory_Base >> 16 )& 0xff   ; 段基址 16~23 位
                                    ; P(1) DPL(00) S(1) Type(0010) 数据 - 向下扩展- 可读 - 没有被访问过 
    db 0b_1_00_1_0_0_1_0              
                                    ; G(1) D(1) 0(1) AVL(0) Limit(16 ~ 19)
    db 0b1_1_0_0_0000 | (Memory_Limit>>16 )& 0x0f
    db (Memory_Base >> 24 )& 0xff   ; 段基址 24~31 位

gdt_end:


adrs_count:
    dw 0
adrs_buffer:



