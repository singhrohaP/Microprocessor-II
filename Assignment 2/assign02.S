#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                                                 @ Specify unified assembly syntax
.cpu    cortex-m0plus                                           @ Specify CPU type is Cortex M0+
.thumb                                                          @ Specify thumb assembly for RP2040
.global main_asm                                                @ Provide program starting address to the linker
.align 4                                                        @ Specify code alignment

.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout


.equ    GPIO_BTN,  21                 @ Specify pin for the "enter" button
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    GPIO_FALLING,   0x00400000
.equ    GPIO_RISING,    0x00800000

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

main_asm:
    ldr     r0, =button_addr                            @ set r0 to the address of button_addr variable
    str     r1, [r0]                                    @ store the button_state address in r1 as the value of button_addr 
    ldr     r0, =num_bits_addr                          @ set r0 to the address of num_bits_addr variable
    str     r2, [r0]                                    @ store the number_of_bits address in r2 as the value of button_addr 
    ldr     r0, =is_space_addr
    str     r3, [r0]
    bl      init_btns                                   @ Use asm_gpio_set_irq C function to setup falling-edge interrutps
    bl      install_gpio_isr                            @ See below
    bl      install_alrm_isr
    bl      set_alarm
    bl loop

loop:  

    wfi                                                 @ Wait for interrupt     
    b       loop                                        @ Loop forever

init_btns:
    push    {lr}
    movs    r0, #GPIO_BTN               @ Move value of the button pin to r0  
    bl      asm_gpio_init               @ Initialize pin
    movs    r0, #GPIO_BTN               @ Move value of the button pin to r0
    movs    r1, #GPIO_DIR_IN            @ Set direction as input
    bl      asm_gpio_set_dir            @ Set the direction of the input pin
    movs    r0, #GPIO_BTN               @ Move value of the button pin to r0
    bl      asm_gpio_set_irq            @ Set the falling edge inturrupt on the pin
    pop     {pc}

install_gpio_isr:
    ldr r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Put the address location of the VTOR into r2
    ldr r1, [r2]                                @ Fetch the memory contents of the VTOR and store to r1
    movs r2, #GPIO_ISR_OFFSET                   @ Specify the GPIO interrupt that we're interested in
    add r2, r1                                  @ Add the entry offset to the VTOR base address location
    ldr r0, =gpio_isr                           @ Load the address of the updated ALARM ISR to r0
    str r0, [r2]                                @ Store the updated SVC ISR back to the correct VTOR entry
    @ Enable ALARM0 IRQ by clearing and then setting it
    movs r1, #1                                 @ Set a single bit to use to clear and then set the correct interrupt
    lsls r1, #13                                @ GPIO is interrupt number 13 so in this case we shift left by zero
    ldr r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) @ Put the value of the NVIC ICPR register into r2 (disables interrupts)
    str r1, [r2]                                @ Disable GPIO interrupt (bit offset previously stored in r1)
    ldr r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET) @ Put the value of the NVIC ICPR register into r2 (enables interrupts
    str r1, [r2]                                @ Enable GPIO interrupt (bit offset previously stored in r1)
    bx lr                                       @ Exit the subroutin



set_alarm:
    push {lr}                                   @ Push LR to stack as we will be using nested subroutines
    movs r1, #1                                 @ Target ALARM0 stored in r1
    ldr r2, =TIMER_BASE                         @ Set the base address of the TIMER module in r2
    str r1, [r2, #TIMER_INTE_OFFSET]            @ Enable the interrupt functionality for ALARM0 (stored in r1)
    ldr r1, [r2, #TIMER_TIMELR_OFFSET]          @ Get the lower 32-bit timer value and store it to r1
    ldr r0, =timer
    ldr r0, [r0]
    add r1, r0                                  @ Add the delay we want to the timer value we already fetched
    str r1, [r2, #TIMER_ALARM0_OFFSET]          @ Store the new time we want the alarm to trigger at (current + delay)
    pop {pc}
    
install_alrm_isr:
    push {r2, lr}                               @ Push LR to stack as well as any registers that will be modified
    ldr r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ Put the address location of the VTOR into r2
    ldr r1, [r2]                                @ Fetch the memory contents of the VTOR and store to r1
    movs r2, #ALRM_ISR_OFFSET                   @ Specify the ALARM interrupt that we're interested in (ALARM0 here)
    add r2, r1                                  @ Add the entry offset to the VTOR base address location
    ldr r0, =alrm_isr                           @ Load the address of the updated ALARM ISR to r0
    str r0, [r2]                                @ Store the updated SVC ISR back to the correct VTOR entry
    movs r1, #1                                 @ Set a single bit to use to clear and then set the correct interrupt
    lsls r1, #0                                 @ ALARM0 is interrupt number 0 so in this case we shift left by 0
    ldr r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET) @ Put the value of the NVIC_ICPR register into r2 (disables interrupts)
    str r1, [r2]                                @ Disable the ALARM0 interrupt (bit offset previously stored in r1)
    ldr r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET) @ Put the value of the NVIC_ISER register into r2 (enables interrupts)
    str r1, [r2]                                @ Enable the ALARM0 interrupt (bit offset previously stored in r1)
    pop {r2, pc}

.thumb_func @ Required for interrupt service routines
alrm_isr:
    push    {lr}                                @ Push LR to stack as we will be using nested subroutines
    movs    r1, #1                              @ Target ALARM0 stored in r1
    ldr     r2, =TIMER_BASE                     @ Set the base address of the TIMER module in r2
    str     r1, [r2, #TIMER_INTR_OFFSET]        @ Write to the TIMER_INTR register to clear the pending interrupt
    bl      set_space
    bl      set_alarm
    pop     {pc}                                @ Pop the LR back from the stack to the PC to exit the ISR


.thumb_func
gpio_isr:

    push {lr}
    @ Fetch the interrupt event from the status register
    ldr r4, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) @ Set the address of the INTS2 register in the IO Bank
    ldr r3, [r4]                                           @ Read the interrupt status register to fetch the event
    movs r1, r3                                            @ load its value to r3

    ldr r5, =GPIO_RISING                                   @ Get the mask value used to detect falling-edge event on "down" button
    tst r3, r5                                             @ Test the stored event to see if it matches for the "down" button
    beq gpio_rising

    ldr r5, =GPIO_FALLING                                  @ Get the mask value used to detect falling-edge event on "down" button
    tst r3, r5                                             @ Test the stored event to see if it matches for the "down" button
    beq gpio_falling

gpio_rising:
    push    {r0-r7}
    bl      set_alarm
    ldr     r0, = init_time
    ldr     r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET)         @ set r1 to the address of TIMELR (system timestamp)
    ldr     r1, [r1]                                        @ set r1 to the value of TIMELR
    str     r1, [r0]
    b       gpio_isr_done 

gpio_falling:
    push    {r0-r7}
    bl      set_alarm
    ldr     r0, = final_time
    ldr     r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET)                   @ set r1 to the address of TIMELR (system timestamp)
    ldr     r1, [r1]                                                  @ set r1 to the value of TIMELR
    str     r1, [r0]
    ldr     r0, [r0]
    ldr     r2, =init_time
    ldr     r2, [r2]
    subs    r0,r0,r2
    ldr     r1, =treshhold
    ldr     r1, [r1]
    cmp     r0, r1
    bhi     set_dash
    bls     set_dot

set_dash:
    ldr     r0, =button_addr                                          @ set r0 to the address of button_addr variable
    ldr     r2, [r0]                                                  @ set r2 to the value of button_addr (address of button_state)
    ldr     r1, [r2]
    lsls    r1, #1
    movs    r3, #0
    add     r1, r1, r3
    str     r1, [r2]                                                  @ store the TIMELR value to button_state variable 
    b       increment_num_bits

set_dot:
    ldr     r0, =button_addr                                          @ set r0 to the address of button_addr variable
    ldr     r2, [r0]                                                  @ set r2 to the value of button_addr (address of button_state)
    ldr     r1, [r2]
    lsls    r1, #1
    movs    r3, #1
    add     r1, r1, r3
    str     r1, [r2]                                                  @ store the TIMELR value to button_state variable 
    b       increment_num_bits

increment_num_bits:
    ldr     r0, =num_bits_addr                                        @ set r0 to the address of button_addr variable
    ldr     r2, [r0]                                                  @ set r2 to the value of button_addr (address of button_state)
    ldr     r1, [r2]
    movs    r0, #1
    add     r1, r1, r0
    str     r1, [r2]
    b       gpio_isr_done

gpio_isr_done:
    pop {r0-r7} 
    ldr r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)        @ Set the address of the INTR2 register in the IO Bank
    str r1, [r2]                                            @ Write to the GPIO_INTR2 register to clear all pending interrupts
    pop {pc} 

set_space:
    push {lr}
    ldr  r0, =is_space_addr
    ldr  r0,[r0]
    movs r1, #1
    str  r1, [r0]
    pop  {pc}

    


@ Set data alignment
.data
button_addr:    .word   1
num_bits_addr:  .word   1
is_space_addr:  .word   1
final_time:     .word   0
init_time:      .word   0
treshhold:      .word   150000
timer:          .word   DFLT_ALARM_TIME
    .align 4
