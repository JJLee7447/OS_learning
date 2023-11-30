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

loading_kernel:
    db "Loading Kernel...",10,13,0
error:
    mov si,.error_msg
    call print
    hlt
    jmp $

    .error_msg db "Loading Jinix Error !!!",10,13,0


 


[bits 32]                            ; 进入保护模式
protect_mode:
                                    ; 初始化段寄存器
    mov ax,data_selector            ; 设置数据段选择子
    mov ds,ax                       ; 将数据段选择子写入 ds
    mov es,ax                       ; 将数据段选择子写入 es
    mov fs,ax                       ; 将数据段选择子写入 fs
    mov gs,ax                       ; 将数据段选择子写入 gs
    mov ss,ax                       ; 将数据段选择子写入 ss

    mov esp,0x10000                 ; 设置栈顶指针


    mov edi, 0x10000                ; 读取的目标内存
    mov ecx, 10                     ; 起始扇区
    mov bl, 200                     ; 扇区数量
    call read_disk

    jmp code_selector:0x10000       ; 跳转到内核入口地址
    ud2                             ; 未定义指令，表示出错
rd_disk_m_16:	   
                                    ;-------------------------------------------------------------------------------
				                    ; eax=LBA扇区号
				                    ; ebx=将数据写入的内存地址
				                    ; ecx=读入的扇区数
    mov esi,eax	                    ;备份eax
    mov di,cx		                ;备份cx
                                    ;读写硬盘:
                                    ;第1步：选择特定通道的寄存器(sector count)，设置要读取的扇区数 (1)
    mov dx,0x1f2                    ;见 primary 通道设置为 0x1f2 选择的是sector count 寄存器
    mov al,cl                       ; cl = 1
    out dx,al                       ;读取的扇区数

    mov eax,esi	                    ;恢复exa 即 loader 存放扇区的地址( 0x900) 

                                    ;第2步：在特定通道寄存器中放入要读取扇区的地址(0x900)，将LBA地址存入0x1f3 ~ 0x1f6
                                    ;LBA地址7~0位写入端口0x1f3
    mov dx,0x1f3                       
    out dx,al                          

                                    ;LBA地址15~8位写入端口0x1f4
    mov cl,8                        
    shr eax,cl                      ; shr 将exa右移 cl(8) 位, 
    mov dx,0x1f4
    out dx,al

                                    ;LBA地址23~16位写入端口0x1f5
    shr eax,cl
    mov dx,0x1f5
    out dx,al
                                    ;设置device寄存器的值，LBA地址的24 ~ 27位放入device 的低四位，高四位设置为1110
    shr eax,cl
    and al,0x0f	                    ;LBA第24~27位 LBA 地址长度28 所以这里只有低四位有意义 
    or al,0xe0	                    ;设置7～4位为1110,表示LBA模式且选择主盘
    mov dx,0x1f6
    out dx,al

                                    ;第3步：向0x1f7端口写入 读命令(0x20) 
    mov dx,0x1f7
    mov al,0x20                        
    out dx,al

                                    ;第4步：检测硬盘状态
.not_ready:
                                    ;同一端口，写时表示写入命令字，读时表示读入硬盘状态
    nop
    in al,dx
    and al,0x88	                    ;第4位为1表示硬盘控制器已准备好数据传输，第7位为1表示硬盘忙
    cmp al,0x08
    jnz .not_ready	                ;若未准备好，继续等。

                                    ;第5步：从0x1f0端口读数据
    mov ax, di                      ;di当中存储的是要读取的扇区数(1)
    mov dx, 256                     ;每个扇区512字节，一次读取两个字节，所以一个扇区就要读取256次，与扇区数相乘，就等得到总读取次数
    mul dx                          ;8位乘法与16位乘法知识查看书p133,注意：16位乘法会改变dx的值！！！！
    mov cx, ax	                    ; 得到了要读取的总次数，然后将这个数字放入cx中
    mov dx, 0x1f0                   ;设置读端口寄存器
.go_on_read:
    in ax,dx
    mov [ds:bx],ax
    add bx,2		  
    loop .go_on_read
    ret



read_disk:
                                    ; -------------------------------------------
                                    ; 读取硬盘
                                    ; mov edi, 0x1000; 读取的目标内存
                                    ; mov ecx, 2; 起始扇区
                                    ; mov bl, 4; 扇区数量
    ; 设置读写扇区的数量
    mov dx, 0x1f2
    mov al, bl
    out dx, al

    inc dx; 0x1f3
    mov al, cl; 起始扇区的前八位
    out dx, al

    inc dx; 0x1f4
    shr ecx, 8
    mov al, cl; 起始扇区的中八位
    out dx, al

    inc dx; 0x1f5
    shr ecx, 8
    mov al, cl; 起始扇区的高八位
    out dx, al

    inc dx; 0x1f6
    shr ecx, 8
    and cl, 0b1111; 将高四位置为 0

    mov al, 0b1110_0000;
    or al, cl
    out dx, al; 主盘 - LBA 模式

    inc dx; 0x1f7
    mov al, 0x20; 读硬盘
    out dx, al

    xor ecx, ecx; 将 ecx 清空
    mov cl, bl; 得到读写扇区的数量

    .read:
        push cx; 保存 cx
        call .waits; 等待数据准备完毕
        call .reads; 读取一个扇区
        pop cx; 恢复 cx
        loop .read

    ret

    .waits:
        mov dx, 0x1f7
        .check:
            in al, dx
            jmp $+2; nop 直接跳转到下一行
            jmp $+2; 一点点延迟
            jmp $+2
            and al, 0b1000_1000
            cmp al, 0b0000_1000
            jnz .check
        ret

    .reads:
        mov dx, 0x1f0
        mov cx, 256; 一个扇区 256 字
        .readw:
            in ax, dx
            jmp $+2; 一点点延迟
            jmp $+2
            jmp $+2
            mov [edi], ax
            add edi, 2
            loop .readw
        ret

                                    ;数据准备包括 GPT gpt_ptr selector
code_selector equ (1 << 3) | 0      ; 代码段选择子 0000 0000 0000 1000 (RPL = 0) (TI = 0) (index = 1)
data_selector equ (2 << 3) | 0      ; 数据段选择子 0000 0000 0001 0000 (RPL = 0) (TI = 0) (index = 2)

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



