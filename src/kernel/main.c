#include <Jinix/Jinix.h>

int magic = JINIX_MAGIC;
char message[] = "Hello, Jinix!!!!"; // .data
char buffer[512];                    // .bss

void kernel_init() // 打印 Hello Jinix
{
    char *video = (char *)0xb8000; // 文本显示器内存地址
    for (int i = 0; i < sizeof(message); i++)
    {
        video[i * 2] = message[i]; // 字符
                                   // 黑底红字
        video[i * 2 + 1] = 0x04;
    }
}