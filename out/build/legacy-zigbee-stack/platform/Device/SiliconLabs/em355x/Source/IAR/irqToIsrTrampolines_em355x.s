;/**************************************************************************//**
; * @file     irqToIsrTrampolines_em355x.s
; * @brief    Device IRQ Handler trampoline functions to call Legacy ISRs
; *
; * @section License
; * <b>Copyright 2017 Silicon Laboratories, Inc. www.silabs.com</b>
; ******************************************************************************/


        MODULE  ?irqToIsrTrampolines

        EXTERN  halNmiIsr
        EXTERN  halHardFaultIsr
        EXTERN  halMemoryFaultIsr
        EXTERN  halBusFaultIsr
        EXTERN  halUsageFaultIsr
        EXTERN  halSvCallIsr
        EXTERN  halDebugMonitorIsr
        EXTERN  halPendSvIsr
        EXTERN  halInternalSysTickIsr
        EXTERN  halTimer1Isr
        EXTERN  halTimer2Isr
        EXTERN  halManagementIsr
        EXTERN  halBaseBandIsr
        EXTERN  halSleepTimerIsr
        EXTERN  halSc1Isr
        EXTERN  halSc2Isr
        EXTERN  halSecurityIsr
        EXTERN  halStackMacTimerIsr
        EXTERN  emRadioTransmitIsr
        EXTERN  emRadioReceiveIsr
        EXTERN  halAdcIsr
        EXTERN  halIrqAIsr
        EXTERN  halIrqBIsr
        EXTERN  halIrqCIsr
        EXTERN  halIrqDIsr
        EXTERN  halDebugIsr
        EXTERN  halSc3Isr
        EXTERN  halSc4Isr
        EXTERN  halUsbIsr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Define the IRQ handlers to be a simple branch to hal Isr routines.
;; This method allows CMSIS Device IRQs to remain as-is while supporting
;; legacy hal ISRs and not pushing/popping any stack behavior as a result
;; of interrupt routines.
;;

;; A trampoline function from Reset_Handler to halEntryPoint is not necessary.
;; The Source/IAR startup code must instantiate the Reset_Handler and as
;; a consequence the functon halEntryPoint is not used.

        PUBWEAK NMI_Handler
        SECTION .text:CODE:REORDER:NOROOT(2)
NMI_Handler
        LDR R0, =halNmiIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK HardFault_Handler
        SECTION .text:CODE:REORDER:NOROOT(2)
HardFault_Handler
        LDR R0, =halHardFaultIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK MemManage_Handler
        SECTION .text:CODE:REORDER:NOROOT(2)
MemManage_Handler
        LDR R0, =halMemoryFaultIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK BusFault_Handler
        SECTION .text:CODE:REORDER:NOROOT(2)
BusFault_Handler
        LDR R0, =halBusFaultIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK UsageFault_Handler
        SECTION .text:CODE:REORDER:NOROOT(2)
UsageFault_Handler
        LDR R0, =halUsageFaultIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK SVC_Handler
        SECTION .text:CODE:REORDER:NOROOT(2)
SVC_Handler
        LDR R0, =halSvCallIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK DebugMon_Handler
        SECTION .text:CODE:REORDER:NOROOT(2)
DebugMon_Handler
        LDR R0, =halDebugMonitorIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK PendSV_Handler
        SECTION .text:CODE:REORDER:NOROOT(2)
PendSV_Handler
        LDR R0, =halPendSvIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK SysTick_Handler
        SECTION .text:CODE:REORDER:NOROOT(2)
SysTick_Handler
        LDR R0, =halInternalSysTickIsr
        ORR R0, R0, #1
        BX  R0

        ; Device specific interrupt handlers

        PUBWEAK TIM1_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
TIM1_IRQHandler
        LDR R0, =halTimer1Isr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK TIM2_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
TIM2_IRQHandler
        LDR R0, =halTimer2Isr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK MGMT_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
MGMT_IRQHandler
        LDR R0, =halManagementIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK BB_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
BB_IRQHandler
        LDR R0, =halBaseBandIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK SLEEPTMR_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
SLEEPTMR_IRQHandler
        LDR R0, =halSleepTimerIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK SC1_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
SC1_IRQHandler
        LDR R0, =halSc1Isr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK SC2_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
SC2_IRQHandler
        LDR R0, =halSc2Isr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK AESCCM_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
AESCCM_IRQHandler
        LDR R0, =halSecurityIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK MACTMR_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
MACTMR_IRQHandler
        LDR R0, =halStackMacTimerIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK MACTX_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
MACTX_IRQHandler
        LDR R0, =emRadioTransmitIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK MACRX_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
MACRX_IRQHandler
        LDR R0, =emRadioReceiveIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK ADC_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
ADC_IRQHandler
        LDR R0, =halAdcIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK IRQA_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
IRQA_IRQHandler
        LDR R0, =halIrqAIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK IRQB_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
IRQB_IRQHandler
        LDR R0, =halIrqBIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK IRQC_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
IRQC_IRQHandler
        LDR R0, =halIrqCIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK IRQD_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
IRQD_IRQHandler
        LDR R0, =halIrqDIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK DEBUG_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
DEBUG_IRQHandler
        LDR R0, =halDebugIsr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK SC3_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
SC3_IRQHandler
        LDR R0, =halSc3Isr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK SC4_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
SC4_IRQHandler
        LDR R0, =halSc4Isr
        ORR R0, R0, #1
        BX  R0

        PUBWEAK USB_IRQHandler
        SECTION .text:CODE:REORDER:NOROOT(2)
USB_IRQHandler
        LDR R0, =halUsbIsr
        ORR R0, R0, #1
        BX  R0

        END
