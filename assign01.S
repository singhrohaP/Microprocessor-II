// Submitted by: 
//              Prachi Singhroha
//                 (21355131)

#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout

.equ    GPIO_BTN_DN_MSK, 0x00040000   @ Bit-18 for falling-edge event on GP20
.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21
.equ    GPIO_BTN_UP_MSK, 0x04000000   @ Bit-26 for falling-edge event on GP22

.equ    GPIO_BTN_DN,  20              @ Specify pin for the "down" button
.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_BTN_UP,  22              @ Specify pin for the "up" button
.equ    GPIO_LED_PIN, 25              @ Specify pin for the built-in LED
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    LED_VAL_ON,    1              @ Specify value that turns the LED "on"
.equ    LED_VAL_OFF,   0              @ Specify value that turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)

@ Entry point to the ASM portion of the program
//
// Main entry point into the ASM portion of the code
//
main_asm:
    bl    init_leds           // Same as previous labs
    bl    init_btns           // Use asm_gpio_set_irq C function to setup falling-edge interrutps
    bl    install_alrm_isr    // See below
    bl    install_gpio_isr    // See below
loop:
    bl    set_alarm            // Set a new alarm
    wfi                       // Wait here until any interrupt fires
    b     loop                // Always branch back to loop


@MODIFIED
install_alrm_isr:
    // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    // Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    // Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    // Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    // Exit subroutine
    @Set the IRQ handler to our subroutine
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)    @ loads value of r2 with the sum of  base address of the CPU in RP2040 to vector offset address to find out where vector table is
    ldr     r1, [r2]                                @ loads the address r2 is pointing to in r1
    movs    r2, #ALRM_ISR_OFFSET                    @ Move address of ALRM_ISR_OFFSET to r2
    add     r2, r1                                  @ Adds addresses of r1 and r2 and storing to r2
    ldr     r0, =alrm_isr                           @ Loads the value of the address of alrm_isr to r0
    str     r0, [r2]                                @ Store the adrress r2 is pointing to in r0 
    @ Enable the ALARM 0 IRQ(disabling(clear) and the anbling(set))
    movs    r0,#1                                       @ Moves 1 to r0
    ldr     r1,=(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)    @ Loads the sum of the addresses of PPB_BASE and M0PLUS_NVIC_ICPR_OFFSET to r1
    str     r0,[r1]                                     @ Stores the adrress r1 is pointing to in r0 
    ldr     r1,=(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)    @ Loads the sum of the addresses of PPB_BASE and M0PLUS_NVIC_ISER_OFFSET to r1
    str     r0,[r1]                                     @ Stores the adrress r1 is pointing to in r0 
    bx      lr                                          @ Branch to the lr (link register)

install_gpio_isr:

    // Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    // Store the address of the gpio_isr handler to the correct offset for GPIO in the vector table
    // Disable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    // Enable the GPIO IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    // Exit subroutine
    
    ldr  r2, =PPB_BASE                  @ Loads the value of the address of PPB_BASE to r2
    ldr  r1, =M0PLUS_VTOR_OFFSET        @ Loads the value of the address of M0PLUS_VTOR_OFFSET to r1
    add  r2, r1                         @ Adds addresses of r1 and r2 and storing to r2
    ldr  r1, [r2]                       @ Loads the value of the address of r2 to r1
    movs r2, #GPIO_ISR_OFFSET           @ Move address of GPIO_ISR_OFFSET to r2
    add  r2, r1                         @ Adds addresses of r1 and r2 and storing to r2
    ldr  r0, =gpio_isr                  @ Loads the value of the address of gpio_isr to r0
    str  r0, [r2]                       @ Stores the adrress r2 is pointing to in r0 
    ldr  r0, =8192                      @ Loads the value 8192 (2^13) to r0
    ldr  r2, =PPB_BASE                  @ Loads the value of the address of PPB_BASE to r2
    ldr  r1, =M0PLUS_NVIC_ICPR_OFFSET   @ Loads the value of the address of M0PLUS_NVIC_ICPR_OFFSET to r1
    add  r1, r2                         @ Adds addresses of r1 and r2 and storing to r1
    str  r0, [r1]                       @ Stores the adrress r1 is pointing to in r0 
    ldr  r1, =M0PLUS_NVIC_ISER_OFFSET   @ Loads the value of the address of M0PLUS_NVIC_ICPR_OFFSET to r1
    add  r1, r2                         @ Adds addresses of r1 and r2 and storing to r1
    str  r0, [r1]                       @ Stores the adrress r1 is pointing to in r0 
    bx   lr                             @ Branch to the lr (link register)

//
// Enable alarm timer interrupts and set an alarm
//
@MODIFIED
set_alarm:
    // Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register
    // Add the time delay you want to wait for to the current timer count
    // Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)
    // Exit subroutine
    ldr  r2,=TIMER_BASE                 @ Loads the value of the address of TIMER_BASE to r2
    movs r1, #1                         @ Move the value 1 to r1
    str  r1, [r2, #TIMER_INTE_OFFSET]   @ Stores sum of r2 and TIMER_INTE_OFFSET in r1
    ldr  r1, [r2, #TIMER_TIMELR_OFFSET] @ Load the sum of the addresses of r2 and TIMER_TIMELR_OFFSET in r1
    ldr  r4,=ltimer                     @ Loads the value of the address of the ltimer to r4
    ldr  r3,[r4]                        @ Loads the value of the address of r4 to r3
    add  r1, r3                         @ Adds addresses of r1 and r3 and storing to r1
    str  r1, [r2, #TIMER_ALARM0_OFFSET] @ Stores sum of r2 and TIMER_ALARM0_OFFSET in r1
    bx   lr                             @ Branch to the lr (link register)

.thumb_func                     @ Required for all interrupt service routines
@MODIFIED
alrm_isr:
    // Perform required functionality (e.g. toggle the LED)
    // Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)
    // Exit ISR
    push {lr}                        @ Stores link register in the stack

    @clearing the interrupt

    ldr  r2, =TIMER_BASE                @ Loads the value of the address of the TIMER_BASE to r2
    movs r1, #1                         @ Move the value 1 to r2
    str  r1, [r2, #TIMER_INTR_OFFSET]   @ Stores sum of r2 and TIMER_INTE_OFFSET in r1

    @Toggling LED

    bl   sub_toggle                 @ Branches link to sub_toggle
    ldr  r0,=ltimer                 @ Loads the value of the address of the ltimer to r0
    bl   set_alarm                  @ Branch link to set_alarm
    ldr  r0, =al_msg                @ Loads the value of the address of the al_msg to r0
    bl   printf                     @ Prints message: toggling of the LED via a periodic alarm timer interrupt
    pop  {pc}                       @ Pop the link register from the stack to the program counter

 @subroutine used by the alrm_isr
sub_toggle:
    push    {lr}                        @ Stores link register in the stack
    ldr     r0,=lstate                  @ Loads the value of the address of the lstate to r0
    ldr     r4,[r0]                     @ Loads the value of the address of the r0 to r4
    cmp     r4, DFLT_STATE_STOP         @ Compare values of r4 with DFLT_STATE_STOP
    beq     finish_toggle               @ Branches if equal to finish_toggle
    movs    r0, #GPIO_LED_PIN           @ Set the LED GPIO pin number to r0 for use by asm_gpio_get
    bl      asm_gpio_get                @ Get current the value of the LED GPIO pin (returns to r0)
    cmp     r0, #LED_VAL_OFF            @ Compare values of r0 with LED_VAL_OFF
    beq     led_set_on                  @ If it is "off" then then jump code to to turn it on

init_leds:
    push    {lr}                        @ Stores link register in the stack
    movs    r0, #GPIO_LED_PIN           @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_init               @ Get current the value of the LED GPIO pin (returns to r0)
    movs    r0, #GPIO_LED_PIN           @ This value is the GPIO LED pin on the PI PICO board
    movs    r1, #GPIO_DIR_OUT           @ We want this GPIO pin to be setup as an output pin
    bl      asm_gpio_set_dir            @ Call the subroutine to set the GPIO pin specified by r0 to state specified by r1
    pop     {pc}

init_btns:
    push    {lr}                       @ Stores link register in the stack
    movs    r0, #GPIO_BTN_DN           @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_init              @ Get current the value of the LED GPIO pin (returns to r0)
    movs    r0, #GPIO_BTN_DN           @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_set_irq           @ Get current the value of the LED GPIO pin (returns to r0)

    movs    r0, #GPIO_BTN_EN           @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_init              @ Get current the value of the LED GPIO pin (returns to r0)
    movs    r0, #GPIO_BTN_EN           @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_set_irq           @ Get current the value of the LED GPIO pin (returns to r0)

    movs    r0, #GPIO_BTN_UP           @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_init              @ Get current the value of the LED GPIO pin (returns to r0)
    movs    r0, #GPIO_BTN_UP           @ This value is the GPIO LED pin on the PI PICO board
    bl      asm_gpio_set_irq           @ Get current the value of the LED GPIO pin (returns to r0)

    pop     {pc}                       @ Pop the link register from the stack to the program counter

led_set_off:
    movs    r1, #LED_VAL_OFF            @ Move the value of LED_VAL_OFF to r2
    b       led_set_state               @ Jump to portion of code where we set the state of the LED
led_set_on:
    movs    r1, #LED_VAL_ON             @ Move the value of LED_VAL_ON to r2
led_set_state:
    movs    r0, #GPIO_LED_PIN           @ Set the LED GPIO pin number to r0 for use by asm_gpio_put
    bl      asm_gpio_put                @ Update the the value of the LED GPIO pin (based on value in r1)
finish_toggle:
    pop     {pc}                        @ Pop the link register from the stack to the program counter

.thumb_func
gpio_isr:
    push {lr}                                               @ Stores link register in the stack                                              
    ldr r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)  @ Load the sum of the addresses of IO_BANK0_BASE and IO_BANK0_PROC0_INTS2_OFFSET in r2
    ldr r1, [r2]                                            @ Loads the value of the address pointing to r2 to r1
    ldr r0, =8192                                           @ Loads the value 8192 (2^13) to r0
    str r0, [r2]                                            @ Stores the adrress r2 is pointing to in r0 
    ldr r0, =GPIO_BTN_DN_MSK                                @ Loads the value of the address of GPIO_BTN_EN_MSK to r0
    cmp r1, r0                                              @ Compare values of r1 with r0
    beq turnDownOn                                          @ Branches if equal to turnDownOn
    ldr r0, =GPIO_BTN_EN_MSK                                @ Loads the value of the address of GPIO_BTN_EN_MSK to r0
    cmp r1, r0                                              @ Compare values of r1 with r0
    beq turnEnOn                                            @ Branches if equal to turnEnOn
    ldr r0, =GPIO_BTN_UP_MSK                                @ Loads the value of the address of GPIO_BTN_EN_MSK to r0
    cmp r1, r0                                              @ Compare values of r1 with r0
    beq turn_up_on

gpio_isr_done:
    pop {pc}        @ Pop the link register from the stack to the program counter

turnDownOn:
    ldr  r2, =lstate        @ Loads the value of the address of lstate to r2
    ldr  r1, [r2]           @ Loads the value of the address pointing to r2 to r1
    movs r0, #0             @ Move the value 0 to r0
    cmp  r0, r1             @ Compare values of r0 with r1
    beq  setDefaultDown     @ Branches if equal to setDefaultDown
    ldr  r0, =dn_msg        @ Loads the value of the address of dn_msg to r0
    bl   printf             @ Prints message
    ldr  r2, =ltimer        @ Loads the value of the address of ltimer to r2
    ldr  r1, [r2]           @ Loads the value of the address pointing to r2 to r1
    movs r0, r1             @ Moves the address pointing to r1 to r0
    b    half               @ branch back to half

setDefaultDown:
    ldr r2, =ltimer                                     @ Loads the value of the address of ltimer to r2
    ldr r1, =DFLT_ALARM_TIME                            @ Loads the value of the address of DFLT_ALARM_TIME to r1
    str r1, [r2]                                        @ Stores the adrress r2 is pointing to r2 in r1
    ldr r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)    @ Loads the sum of the addresses of IO_BANK0_BASE and IO_BANK0_INTR2_OFFSET to r2
    ldr r1, =GPIO_BTN_DN_MSK                            @ Loads the value of the address of GPIO_BTN_DN_MSK to r1
    str r1, [r2]                                        @ Stores the adrress r2 is pointing to in r1
    ldr r0, =rst_msg                                    @ Loads the value of the address of rst_msg to r0
    bl  printf                                          @ Prints message
    b   gpio_isr_done                                   @ branch back to gpio_isr_done

half:
    subs r0, #1             @ Subtract 1 from r0 and store in r0
    movs r2, r0             @ Moves the address pointing to r0 to r2
    adds r2, r2             @ Adds the addresses of r2 to r2 and store in  r2
    cmp  r2, r1             @ Compare values of r2 with r1
    beq  valueUpdateDown    @ Branches if equal to valueUpdateDown
    b    half               @ branch back to half

valueUpdateDown:
    ldr r2, =ltimer                                     @ Loads the value of the address of ltimer to r2
    str r0, [r2]                                        @ Stores the adrress r2 is pointing to in r0 
    ldr r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)    @ Loads the sum of the addresses of IO_BANK0_BASE and IO_BANK0_INTR2_OFFSET to r2
    ldr r1, =GPIO_BTN_DN_MSK                            @ Loads the value of the address of GPIO_BTN_DN_MSK to r1
    str r1, [r2]                                        @ Stores the adrress r2 is pointing to in r1
    b   gpio_isr_done                                   @ branch back to gpio_isr_done

turnEnOn:
    ldr  r2, =lstate        @ Loads the value of the address of lstate to r2
    ldr  r1, [r2]           @ Loads the value of the address pointing to r2 to r1
    movs r0, #1             @ Move the value 1 to r0
    cmp  r0, r1             @ Compare values of r0 with r1
    beq  store              @ Branches if equal to store
    str  r0, [r2]           @ Stores the adrress r2 is pointing to in r0 
    ldr  r0, =en_msg_s      @ Loads the value of the address of en_msg_s to r0
    bl   printf             @ Prints message
    movs r0, #1             @ Moves the value 1 to r0
    b    valueUpdateEn      @ branch back to valueUpdateUp

valueUpdateEn:
    ldr r2, =lstate                                     @ Loads the value of the address of lstate to r2
    str r0, [r2]                                        @ Stores the adrress r2 is pointing to in r0 
    ldr r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)    @ Loads the sum of the addresses of IO_BANK0_BASE and IO_BANK0_INTR2_OFFSET to r2
    ldr r1, =GPIO_BTN_EN_MSK                            @ Loads the value of the address of GPIO_BTN_EN_MSK to r1
    str r1, [r2]                                        @ Stores the adrress r2 is pointing to in r1
    b   gpio_isr_done                                   @ branch back to gpio_isr_done

store:
    ldr  r0, =en_msg_p      @ Loads the value of the address of en_msg_p to r0
    bl   printf             @ Prints message
    movs r0, #0             @ Move the value 0 to r0
    b    valueUpdateEn      @ branch back to valueUpdateUp

turn_up_on:
    ldr  r2, =lstate        @ Loads the value of the address of lstate to r2
    ldr  r1, [r2]           @ Stores the adrress r2 is pointing to in r1
    movs r0, #0             @ Move the value 0 to r0
    cmp  r0, r1             @ Compare values of r0 with r1
    beq  setDefaultUp       @ Branches if equal to setDefaultUp
    ldr  r2, =ltimer        @ Loads the value of the address of ltimer to r2
    ldr  r1, [r2]           @ Stores the adrress r2 is pointing to in r1
    adds r1, r1             @ Adds r1 with r1 and store in r1
    str  r1, [r2]           @ Stores the adrress r2 is pointing to in r1
    ldr  r0, =up_msg        @ Loads the value of the address of up_msg to r2
    bl   printf             @ Prints message
    b    valueUpdateUp      @ branch back to valueUpdateUp

valueUpdateUp:
    ldr r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)    @ Loads the sum of the addresses of IO_BANK0_BASE and IO_BANK0_INTR2_OFFSET to r2
    ldr r1, =GPIO_BTN_UP_MSK                            @ Loads the value of the address of GPIO_BTN_UP_MSK to r1
    str r1, [r2]                                        @ Stores the adrress r2 is pointing to in r1
    b   gpio_isr_done                                   @ branch back to gpio_isr_done

setDefaultUp:               
    ldr r0, =rst_msg                                     @ Loads the value of the address of rst_msg to r0
    bl  printf                                           @ Prints message
    ldr r2, =ltimer                                      @ Loads the value of the address of ltimer to r2
    ldr r1, =DFLT_ALARM_TIME                             @ Loads the value of the address of DFLT_ALARM_TIME to r1
    str r1, [r2]                                         @ Stores the adrress r2 is pointing to in r1
    ldr r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)     @ Loads the sum of the addresses of IO_BANK0_BASE and IO_BANK0_INTR2_OFFSET to r2
    ldr r1, =GPIO_BTN_UP_MSK                             @ Loads the value of the address of GPIO_BTN_UP_MSK to r1
    str r1, [r2]                                         @ Stores the adrress r2 is pointing to in r1
    b   gpio_isr_done                                    @ branch back to gpio_isr_done

.align 4
up_msg: .asciz "LED flash rate doubles.\n"
dn_msg: .asciz "LED flash rate halves.\n"
en_msg_p: .asciz "LED stops flashing.\n"
en_msg_s: .asciz "LED restarts flashing.\n"
rst_msg: .asciz "LED flash rate resets.\n"
al_msg: .asciz "toggling of the LED via a periodic alarm timer interrupt.\n"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME
