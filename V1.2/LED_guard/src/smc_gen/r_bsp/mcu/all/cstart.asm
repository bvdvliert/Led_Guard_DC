;;/***********************************************************************************************************************
;;* DISCLAIMER
;;* This software is supplied by Renesas Electronics Corporation and is only intended for use with Renesas products. No 
;;* other uses are authorized. This software is owned by Renesas Electronics Corporation and is protected under all 
;;* applicable laws, including copyright laws. 
;;* THIS SOFTWARE IS PROVIDED "AS IS" AND RENESAS MAKES NO WARRANTIES REGARDING
;;* THIS SOFTWARE, WHETHER EXPRESS, IMPLIED OR STATUTORY, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, 
;;* FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. ALL SUCH WARRANTIES ARE EXPRESSLY DISCLAIMED. TO THE MAXIMUM 
;;* EXTENT PERMITTED NOT PROHIBITED BY LAW, NEITHER RENESAS ELECTRONICS CORPORATION NOR ANY OF ITS AFFILIATED COMPANIES 
;;* SHALL BE LIABLE FOR ANY DIRECT, INDIRECT, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES FOR ANY REASON RELATED TO THIS 
;;* SOFTWARE, EVEN IF RENESAS OR ITS AFFILIATES HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
;;* Renesas reserves the right, without notice, to make changes to this software and to discontinue the availability of 
;;* this software. By using this software, you agree to the additional terms and conditions found by accessing the 
;;* following link:
;;* http://www.renesas.com/disclaimer
;;*
;;* Copyright (C) 2021 Renesas Electronics Corporation. All rights reserved.
;;***********************************************************************************************************************/
;;/***********************************************************************************************************************
;;* File Name    : cstart.asm
;;* Description  : 
;;***********************************************************************************************************************/
;;/***********************************************************************************************************************
;;* History : DD.MM.YYYY Version  Description
;;*         : 08.03.2021 1.00     First Release
;;*         : 22.04.2021 1.10     Added the following include path.
;;*                                - r_bsp_config.inc
;;*                               Added the following external declaration of symbol for stack area.
;;*                                - __kernel_start
;;*                                - _ri78v4_hdw_init
;;*                                - __init_ri_stackarea
;;*                               Added register bank settings.
;;*                               Added hardware initialization for RTOS.
;;*                               Added initialization process for RTOS.
;;*         : 28.02.2022 1.20     Changed to always include r_bsp_config.inc.
;;*                               Added RAMSAR register setting.
;;*         : 31.01.2023 1.50     Added code for C++ project.
;;*                               Added code for RAM initialization table.
;;***********************************************************************************************************************/

$INCLUDE (r_bsp_config.inc)

$IFNDEF __RENESAS_VERSION__
__RENESAS_VERSION__ .EQU    0x01000000
$ENDIF

    .public _start
    .public _exit
    .public _atexit

;-----------------------------------------------------------------------------
; external declaration of symbol for stack area
;-----------------------------------------------------------------------------
$IFDEF BSP_RTOS
$IF (BSP_CFG_ASM_RTOS_USED == 0)      ; RTOS is not used.
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 1)  ; FreeRTOS is used.(This is not available.)
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 2)  ; embOS is used.(This is not available.)
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 3)  ; MicroC_OS is used.(This is not available.)
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 4)  ; Renesas ITRON is used.
    .extern __kernel_start
    .extern _ri78v4_hdw_init
    .extern __init_ri_stackarea
$ELSE
$ENDIF
$ELSE
$ENDIF

;-----------------------------------------------------------------------------
;   RAM section
;-----------------------------------------------------------------------------
.SECTION .dataR, DATA
.SECTION .sdataR, DATA
; .SECTION .datafR, DATAF
; .SECTION .textfR, TEXTF

$IF (__RENESAS_VERSION__ < 0x01010000)  ; for CC-RL V1.00
;-----------------------------------------------------------------------------
;   stack area
;-----------------------------------------------------------------------------
; !!! [CAUTION] !!!
; Set up stack size suitable for a project.
.SECTION .stack_bss, BSS
_stackend:
    .DS     0x200
_stacktop:
$ENDIF

;-----------------------------------------------------------------------------
;   RESET vector
;-----------------------------------------------------------------------------
_start  .VECTOR 0

;-----------------------------------------------------------------------------
;   startup
;-----------------------------------------------------------------------------
.SECTION .text, TEXT
_start:
    ;--------------------------------------------------
    ; setting register bank
    ;--------------------------------------------------
$IFDEF BSP_CFG_ASM_RAM_GUARD_START_ADDRESS
    MOV !RAMSAR, #BSP_CFG_ASM_RAM_GUARD_START_ADDRESS
$ENDIF
$IFDEF BSP_RTOS
$IF (BSP_CFG_ASM_RTOS_USED == 0)      ; RTOS is not used.
;   SEL RB0
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 1)  ; FreeRTOS is used.(This is not available.)
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 2)  ; embOS is used.(This is not available.)
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 3)  ; MicroC_OS is used.(This is not available.)
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 4)  ; Renesas ITRON is used.
    SEL RB0
$ELSE
$ENDIF
$ELSE
$ENDIF

    ;--------------------------------------------------
    ; setting mirror area
    ;--------------------------------------------------
;   ONEB    !PMC        ; mirror area = 10000-1FFFFH

    ;--------------------------------------------------
    ; setting the stack pointer
    ;--------------------------------------------------
$IF (__RENESAS_VERSION__ >= 0x01010000)
    MOVW    SP,#LOWW(__STACK_ADDR_START)
$ELSE   ; for CC-RL V1.00
    MOVW    SP,#LOWW(_stacktop)
$ENDIF

    ;--------------------------------------------------
    ; initializing stack area
    ;--------------------------------------------------
$IF (__RENESAS_VERSION__ >= 0x01010000)
    MOVW    AX,#LOWW(__STACK_ADDR_END)
$ELSE   ; for CC-RL V1.00
    MOVW    AX,#LOWW(_stackend)
$ENDIF
    CALL    !!_stkinit

    ;--------------------------------------------------
    ; bsp initialization
    ;--------------------------------------------------
    CALL    !!_bsp_init_system

$IFDEF __USE_RAM_INIT_TABLE
    ;--------------------------------------------------
    ; initializing RAM
    ;--------------------------------------------------
    MOVW    AX,#LOWW(STARTOF(.ram_init_table))
    BR      $.L5_RAM_INIT_TABLE
.L1_RAM_INIT_TABLE:
    PUSH    AX      ;table pointer
    MOVW    HL,AX
    MOV     ES,#HIGHW(STARTOF(.ram_init_table))
    MOVW    AX,ES:[HL+6]    ;dst
    MOVW    DE,AX
    MOVW    AX,ES:[HL+4]    ;size
    ADDW    AX,DE
    MOVW    BC,AX           ;end
    MOV     A,ES:[HL+2]     ;high(src)
    CMP     A,#0xF
    BZ      $.L3_RAM_INIT_TABLE_CLEAR

    PUSH    AX
    MOVW    AX,ES:[HL]      ;loww(src)
    MOVW    HL,AX
    POP     AX
    MOV     ES,A
    BR      $.L3_RAM_INIT_TABLE_COPY

.L2_RAM_INIT_TABLE_COPY:
    MOV     A,ES:[HL]
    INCW    HL
    MOV     [DE],A
    INCW    DE
.L3_RAM_INIT_TABLE_COPY:
    MOVW    AX,DE
    CMPW    AX,BC
    BC      $.L2_RAM_INIT_TABLE_COPY
    BR      $.L4_RAM_INIT_TABLE

.L2_RAM_INIT_TABLE_CLEAR:
    MOV     [DE],#0
    INCW    DE
.L3_RAM_INIT_TABLE_CLEAR:
    MOVW    AX,DE
    CMPW    AX,BC
    BC      $.L2_RAM_INIT_TABLE_CLEAR

.L4_RAM_INIT_TABLE:
    POP     AX          ;table pointer
    ADDW    AX,#8
.L5_RAM_INIT_TABLE:
    CMPW    AX,#LOWW(STARTOF(.ram_init_table)+SIZEOF(.ram_init_table))
    BC      $.L1_RAM_INIT_TABLE

$ELSE    ; __USE_RAM_INIT_TABLE
    ;--------------------------------------------------
    ; initializing BSS
    ;--------------------------------------------------
    ; clear external variables which doesn't have initial value (near)
    MOVW    HL,#LOWW(STARTOF(.bss))
    MOVW    AX,#LOWW(STARTOF(.bss) + SIZEOF(.bss))
    BR  $.L2_BSS
.L1_BSS:
    MOV [HL+0],#0
    INCW    HL
.L2_BSS:
    CMPW    AX,HL
    BNZ $.L1_BSS

    ; clear saddr variables which doesn't have initial value
    MOVW    HL,#LOWW(STARTOF(.sbss))
    MOVW    AX,#LOWW(STARTOF(.sbss) + SIZEOF(.sbss))
    BR  $.L2_SBSS
.L1_SBSS:
    MOV [HL+0],#0
    INCW    HL
.L2_SBSS:
    CMPW    AX,HL
    BNZ $.L1_SBSS

    ; clear external variables which doesn't have initial value (far)
;   MOV ES,#HIGHW(STARTOF(.bssf))
;   MOVW    HL,#LOWW(STARTOF(.bssf))
;   MOVW    AX,#LOWW(STARTOF(.bssf) + SIZEOF(.bssf))
;   BR  $.L2_BSSF
;.L1_BSSF:
;   MOV ES:[HL+0],#0
;   INCW    HL
;.L2_BSSF:
;   CMPW    AX,HL
;   BNZ $.L1_BSSF

    ;--------------------------------------------------
    ; ROM data copy
    ;--------------------------------------------------
    ; copy external variables having initial value (near)
    MOV ES,#HIGHW(STARTOF(.data))
    MOVW    BC,#LOWW(SIZEOF(.data))
    BR  $.L2_DATA
.L1_DATA:
    DECW    BC
    MOV A,ES:LOWW(STARTOF(.data))[BC]
    MOV LOWW(STARTOF(.dataR))[BC],A
.L2_DATA:
    CLRW    AX
    CMPW    AX,BC
    BNZ $.L1_DATA

    ; copy saddr variables having initial value
    MOV ES,#HIGHW(STARTOF(.sdata))
    MOVW    BC,#LOWW(SIZEOF(.sdata))
    BR  $.L2_SDATA
.L1_SDATA:
    DECW    BC
    MOV A,ES:LOWW(STARTOF(.sdata))[BC]
    MOV LOWW(STARTOF(.sdataR))[BC],A
.L2_SDATA:
    CLRW    AX
    CMPW    AX,BC
    BNZ $.L1_SDATA

    ; copy external variables having initial value (far)
;   MOVW    BC,#LOWW(SIZEOF(.dataf))
;   BR  $.L2_DATAF
;.L1_DATAF:
;   DECW    BC
;   MOV ES,#HIGHW(STARTOF(.dataf))
;   MOV A,ES:LOWW(STARTOF(.dataf))[BC]
;   MOV ES,#HIGHW(STARTOF(.datafR))
;   MOV ES:LOWW(STARTOF(.datafR))[BC],A
;.L2_DATAF:
;   CLRW    AX
;   CMPW    AX,BC
;   BNZ $.L1_DATAF

    ; copy .text to RAM
;   MOV C,#HIGHW(STARTOF(.textf))
;   MOVW    HL,#LOWW(STARTOF(.textf))
;   MOVW    DE,#LOWW(STARTOF(.textfR))
;   BR  $.L2_TEXT
;.L1_TEXT:
;   MOV A,C
;   MOV ES,A
;   MOV A,ES:[HL]
;   MOV [DE],A
;   INCW    DE
;   INCW    HL
;   CLRW    AX
;   CMPW    AX,HL
;   SKNZ
;   INC C
;.L2_TEXT:
;   MOVW    AX,HL
;   CMPW    AX,#LOWW(STARTOF(.text) + SIZEOF(.text))
;   BNZ $.L1_TEXT

$ENDIF    ; __USE_RAM_INIT_TABLE

    ;--------------------------------------------------
    ; call global constructor (_peace_global_ctor_0)
    ;--------------------------------------------------
    MOVW    BC,#LOWW(SIZEOF(.init_array))
    BR      $.L2_INIT
.L1_INIT:
    DECW    BC
    DECW    BC
    MOV     ES,#HIGHW(STARTOF(.init_array))
    MOVW    AX,ES:LOWW(STARTOF(.init_array))[BC]
    MOV     CS,#0x00
    PUSH    BC
    CALL    AX
    POP     BC
.L2_INIT:
    CLRW    AX
    CMPW    AX,BC
    BNZ     $.L1_INIT

    ;--------------------------------------------------
    ; hardware initialization
    ;--------------------------------------------------
    CALL    !!_bsp_init_hardware

$IFDEF BSP_RTOS
$IF (BSP_CFG_ASM_RTOS_USED == 0)      ; RTOS is not used.
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 1)  ; FreeRTOS is used.(This is not available.)
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 2)  ; embOS is used.(This is not available.)
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 3)  ; MicroC_OS is used.(This is not available.)
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 4)  ; Renesas ITRON is used.
    CALL    !!_ri78v4_hdw_init
$ELSE
$ENDIF
$ELSE
$ENDIF

    ;--------------------------------------------------
    ; call main function
    ;--------------------------------------------------
$IFDEF BSP_RTOS
$IF (BSP_CFG_ASM_RTOS_USED == 0)      ; RTOS is not used.
    CALL    !!_main     ; main();
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 1)  ; FreeRTOS is used.(This is not available.)
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 2)  ; embOS is used.(This is not available.)
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 3)  ; MicroC_OS is used.(This is not available.)
$ELSEIF (BSP_CFG_ASM_RTOS_USED == 4)  ; Renesas ITRON is used.
    ;-----------------------------------------------------------------------------
    ; initializing RI78V4 area(.kernel_data_init)
    ;-----------------------------------------------------------------------------
    MOVW    HL,#LOWW(STARTOF(.kernel_data_init))
    MOVW    AX,#LOWW(STARTOF(.kernel_data_init) + SIZEOF(.kernel_data_init))
    BR      $L2_KERNEL_DATA
L1_KERNEL_DATA:
    MOV     [HL+0], #0
    INCW    HL
L2_KERNEL_DATA:
    CMPW    AX,HL
    BNZ     $L1_KERNEL_DATA

    ;-----------------------------------------------------------------------------
    ; RI78V4 stack area initialization function
    ;  When the RAM parity error detection function is not used,
    ;  it is not necessary to call this function.
    ;-----------------------------------------------------------------------------
    CALL    !!__init_ri_stackarea

    ;-----------------------------------------------------------------------------
    ; RI78V4 initialization function
    ;-----------------------------------------------------------------------------
    BR      !!__kernel_start        ; kernel start
$ELSE
$ENDIF
$ELSE
    CALL    !!_main     ; main();
$ENDIF

    ;--------------------------------------------------
    ; call exit function
    ;--------------------------------------------------
    CLRW    AX      ; exit(0)
_exit:
    BR  $_exit

;-----------------------------------------------------------------------------
;   atexit (only ret)
;-----------------------------------------------------------------------------
_atexit:
    RET

;-----------------------------------------------------------------------------
;   section
;-----------------------------------------------------------------------------
$IF (__RENESAS_VERSION__ >= 0x01010000)
.SECTION .RLIB, TEXTF
.L_section_RLIB:
.SECTION .SLIB, TEXTF
.L_section_SLIB:
$ENDIF
.SECTION .textf, TEXTF
.L_section_textf:
.SECTION .const, CONST
.L_section_const:
.SECTION .constf, CONSTF
.L_section_constf:
.SECTION .data, DATA
.L_section_data:
;.SECTION .dataf, DATAF
;.L_section_dataf:
.SECTION .sdata, SDATA
.L_section_sdata:
.SECTION .bss, BSS
.L_section_bss:
;.SECTION .bssf, BSSF
;.L_section_bssf:
.SECTION .sbss, SBSS
.L_section_sbss:
.SECTION .init_array, CONSTF
.L_section_init_array:
