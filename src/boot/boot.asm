                                    ;主引导程序 
                                    ;------------------------------------------------------------
%include "boot.inc"
SECTION MBR vstart=0x7c00         
    mov ax,cs                       ; cs = 0
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov fs,ax
    mov sp,0x7c00
    mov ax,0xb800
    mov gs,ax

                                    ; 清屏
                                    ;利用0x06号功能，上卷全部行，则可清屏。
                                    ; -----------------------------------------------------------
                                    ;INT 0x10   功能号:0x06	   功能描述:上卷窗口
                                    ;------------------------------------------------------
                                    ;输入：
                                    ;AH 功能号= 0x06
                                    ;AL = 上卷的行数(如果为0,表示全部)
                                    ;BH = 上卷行属性
                                    ;(CL,CH) = 窗口左上角的(X,Y)位置
                                    ;(DL,DH) = 窗口右下角的(X,Y)位置
                                    ;无返回值：
;    mov ax, 0600h
;    mov bx, 0700h
;    mov cx, 0                       ; 左上角: (0, 0)
;    mov dx, 184fh		            ; 右下角: (80,25),
;				                    ; 因为VGA文本模式中，一行只能容纳80个字符,共25行。
;				                    ; 下标从0开始，所以0x18=24,0x4f=79
;    int 10h                         ; int 10h

                                    ; 输出字符串:MBR
;    mov byte [gs:0x00],'1'
;    mov byte [gs:0x01],0xA4
;
;    mov byte [gs:0x02],' '
;    mov byte [gs:0x03],0xA4
;
;    mov byte [gs:0x04],'M'
;    mov byte [gs:0x05],0xA4	        ;A表示绿色背景闪烁，4表示前景色为红色
;
;    mov byte [gs:0x06],'B'
;    mov byte [gs:0x07],0xA4
;
;    mov byte [gs:0x08],'R'
;    mov byte [gs:0x09],0xA4
                                    ; 设置屏幕模式为文本模式，清除屏幕
    mov ax,3
    int 0x10

    mov si, booting
    call print
	 
    mov eax,LOADER_START_SECTOR	    ; 起始扇区LBA模式地址 LBA地址长度为28
    mov bx,LOADER_BASE_ADDR         ; 写入的地址
    mov cx,4			            ; 待读入的扇区数
    call rd_disk_m_16		        ; 以下读取程序的起始部分（一个扇区）
    
    cmp word [LOADER_BASE_ADDR],0x55aa         ; 判断是否为有效的引导扇区
    jnz error                       ; 如果不是则跳转到error
    jmp LOADER_BASE_ADDR            ; 跳转到loader

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
booting:
    db "booting...",10,13,0
error:
    mov si, .msg
    call print
    hlt ; 让cpu 停止
    .msg db "loading error !!!",10,13,0
                                    ;-------------------------------------------------------------------------------
                                    ;功能:读取硬盘n个扇区
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


    times 510-($-$$) db 0
    db 0x55,0xaa

