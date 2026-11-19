;文件头配置
;======================================================================
NES_16KB_PRG_SIZE           =   1
NES_8KB_CHR_SIZE            =   1
PRG_BANK8_MASK              =   NES_16KB_PRG_SIZE * 2 - 1     ;bank号掩码
PRG_BANK16_MASK             =   NES_16KB_PRG_SIZE - 1         ;bank号掩码
PRG_BANK8_C000              =   NES_16KB_PRG_SIZE * 2 - 2
PRG_BANK16_C000             =   NES_16KB_PRG_SIZE - 1
PRG_BANK8_E000              =   NES_16KB_PRG_SIZE * 2 - 1
PRG_BANK16_E000             =   NES_16KB_PRG_SIZE - 1

;文件头
;======================================================================
    .INESPRG NES_16KB_PRG_SIZE ;16KB PRG 数量
    .INESCHR NES_8KB_CHR_SIZE  ;8KB CHR 数量
    .INESMAP 4                 ;Mapper号
    .INESSUBMAP 0              ;子Mapper号
    .INESMIR 0                 ;命名表镜像 0: 水平 1: 垂直 2: 硬连线四屏
    ;.INESPRGRAM 7              ;PRG RAM 大小
    ;.INESPRGNVRAM 7            ;PRG NVRAM（非易失性）的大小。
    ;.INESCHRRAM 0              ;CHR RAM大小
    ;.INESCHRNVRAM 0            ;CHR NVRAM（非易失性）大小
    ;.INESBAT 0                 ;电池 和其他非易失性存储器 0: 无, 1: 存在
    ;.INESTIM 0                 ;CPU/PPU 时间 0: NTSC 1: PAL 2: 多区域 3: Dendy
    
;======================================================================
    RSSET $0040
PPU_Ctrl        .RS 1       ;PPU控制
PPU_Mask        .RS 1       ;PPU掩码
Data_L          .RS 1       ;数据地址低位
Data_H          .RS 1       ;数据地址高位
PPU_Buffer_Pos  .RS   1     ;PPU缓冲位置

;内存分配
    RSSET $0300
PPU_Buffer      .RS   $80   ;PPU缓冲区

;======================================================================
    .BANK8 NES_16KB_PRG_SIZE * 2
    .INCBIN "chr_data.chr"

    .BANK8 NES_16KB_PRG_SIZE * 2 + NES_8KB_CHR_SIZE - 1
    .ORG $9FFF
    .HEX 00
    
;======================================================================
    .BANK8 PRG_BANK8_E000
    .ORG $FC00
;======================================================================
;NMI中断处理
NMI_Proc
    PHA
    TXA
    PHA
    TYA
    PHA
    
    ;读取一次取消VBlank标志
    LDA $2002
    
    ;禁用NMI中断
    LDA PPU_Ctrl
    AND #$7F
    STA $2000
    
    ;关闭屏幕显示
    LDA #$00
    STA $2001

    ;PPU缓冲处理
    JSR PPU_Proc
    
    ;重置命名表位置
    LDA $2002
    LDA #$00
    STA $2006
    STA $2006
    ;重置屏幕滚动
    STA $2005
    STA $2005

    ;恢复屏幕控制
    LDA PPU_Ctrl
    STA $2000
    
    ;恢复屏幕显示
    LDA PPU_Mask
    STA $2001

    PLA
    TAY
    PLA
    TAX
    PLA
    RTI
    
;======================================================================
;请求中断处理
IRQ_Proc
    RTI

;======================================================================
;重置中断处理
RESET_Proc
    SEI
    CLD
    LDA #$00
    STA $2000
    STA $2001
    
    ;禁用MMC3的IRQ中断
    STA $E000

    ;等待Vblank到来
    LDX #$02
.Wait_Vblank
    LDA $2002
    BPL .Wait_Vblank
    DEX
    BNE .Wait_Vblank
    
;清空调色板
    LDA #$3F
    STA $2006
    LDA #$00
    STA $2006
    LDX #$1F
    LDA #$0F
.Palette_Clear
    STA $2007
    DEX
    BPL .Palette_Clear
    
;调色板初始化
    LDA #$3F
    STA $2006
    LDA #$00
    STA $2006
    LDX #$00
.Palette_Init
    LDA Palette_Data,X
    STA $2007
    INX
    CPX #$20
    BCC .Palette_Init

;初始化内存
    LDA #$00
    STA $00
    STA $01
    LDX #$08
    LDY #$00
.RAM_Init
    STA [$00],Y
    INY
    BNE .RAM_Init
    INC $01
    DEX
    BNE .RAM_Init
    
    ;设置栈底
    LDX #$FF
    TXS
    
    ;映射一下MMC3 CHR
    JSR MMC3_CHR_Mapping
    
    ;写一句文字到屏幕
    LDA #<Text_Data
    STA Data_L
    LDA #>Text_Data
    STA Data_H
    JSR Text_Write_Proc
    
    ;开启NMI中断和屏幕显示
    LDA #$1E
    STA PPU_Mask
    LDA #$80
    STA PPU_Ctrl
    STA $2000
    
;======================================================================
;循环等待
Main_Loop
    JMP Main_Loop

;======================================================================
MMC3_CHR_Mapping
    LDX #$00
.Write
    STX $8000
    LDA .Chr_Bank,X
    STA $8001
    INX
    CPX #$06
    BCC .Write
    RTS
.Chr_Bank
    .HEX 00 02 04 05 06 07

;======================================================================
;PPU缓冲处理
PPU_Proc
    
    LDX PPU_Buffer_Pos
    BEQ .End
    
    LDA #$00
    STA PPU_Buffer,X
    STA PPU_Buffer_Pos
    
    LDX #$00
    
.Start
    ;写入地址高位
    LDA PPU_Buffer,X
    BEQ .End
    STA $2006
    INX
    
    ;写入地址低位
    LDA PPU_Buffer,X
    STA $2006
    INX
    
    ;获取文本长度
    LDA PPU_Buffer,X
    TAY
    INX

.Write
    LDA PPU_Buffer,X
    STA $2007
    INX
    DEY
    BNE .Write
    JMP .Start
.End
    RTS

;======================================================================
;文本写处理
Text_Write_Proc
    LDY #$00
.Start
    ;检查数据长度
    LDA [Data_L],Y
    BEQ .End
    TAX
    INY
    INY
    ;写入PPU高位
    LDA [Data_L],Y
    STA $2006
    DEY
    ;写入PPU低位
    LDA [Data_L],Y
    STA $2006
    INY
    INY
.Write
    LDA [Data_L],Y
    STA $2007
    INY
    DEX
    BNE .Write
    JMP .Start
.End
    RTS

;==================================================
;调色板数据
Palette_Data
    .HEX 0F 20 21 22 0F 20 21 22 0F 20 21 22 0F 20 21 22
    .HEX 0F 20 21 22 0F 20 21 22 0F 20 21 22 0F 20 21 22

;==================================================
;宏文本数据宏
    .MACRO MACRO_USTR_ADDR_DATA
    .DB End_\@ - Begin_\@       ;数据长度
    .DW \1                      ;写入PPU地址
Begin_\@                        ;文本数据
    .USTR \2
End_\@
    .ENDM

;==================================================
;文本数据
Text_Data
    MACRO_USTR_ADDR_DATA $204A, "NES Tutorial"
    MACRO_USTR_ADDR_DATA $20A5, "Author: FlameCyclone"
    MACRO_USTR_ADDR_DATA $20E7, "Date: 2025.12.09"
    .HEX 00 ;结束符号

;======================================================================
    .ORG $FFFA
    .DW NMI_Proc
    .DW RESET_Proc
    .DW IRQ_Proc