/**
 * startup.c : TM4C startup code for use with the GNU Build System
 * (Will likely work with other Tiva/Stellaris boards as well)
 *
 * With credit to:
 *     Lukasz Janyst (bit.ly/2pxKw8x)
 *     TI's TivaWare
 *     The uctools Project (bit.ly/2oIRO9y)
 *
 * Author:   Rahul Butani
 * Modified: February 27th, 2019
 */

// Dependencies:
#include <stdint.h>

// Some preprocessor symbols and macros borrowed from TivaWare so we can avoid
// having real dependencies:

// From hw_types.h:
#define HWREG(x) (*((volatile unsigned long *)(x)))

// From hw_nvic.h:
#define NVIC_CPAC               0xE000ED88  // Coprocessor Access Control
#define NVIC_CPAC_CP11_M        0x00C00000  // CP11 Coprocessor Access
                                            // Privilege:
#define NVIC_CPAC_CP11_FULL     0x00C00000  // Full Access
#define NVIC_CPAC_CP10_M        0x00300000  // CP10 Coprocessor Access
                                            // Privilege:
#define NVIC_CPAC_CP10_FULL     0x00300000  // Full Access

// Prototypes/Declarations:
void __default_int_handler(void);
void __default_rst_handler(void);

// Macros:

// Macro to create a weakly aliased placeholder interrupt that points to the
// default interrupt handler.
// This allows us to define proper strongly defined interrupt handlers
// anywhere in the project and have them override the default interrupt
// handler (taken care of by the linker) without us having to edit this file.
#define DEFINE_HANDLER(NAME) void NAME ## _handler() __attribute__ ((used, weak, alias ("__default_int_handler")))

// Macro to generate function name of an aliased placeholder interrupt.
// (Generating these allows us to avoid hardcoding the function names)
#define HANDLER(NAME) NAME ## _handler


// Define weakly aliased interrupt handlers:

// Reset is a special case:
void reset_handler() __attribute__ ((used, weak, alias ("__default_rst_handler")));

DEFINE_HANDLER(nmi);
DEFINE_HANDLER(hard_fault);
DEFINE_HANDLER(mman);
DEFINE_HANDLER(bus_fault);
DEFINE_HANDLER(usage_fault);
DEFINE_HANDLER(svcall);
DEFINE_HANDLER(debug_monitor);
DEFINE_HANDLER(pendsv);
DEFINE_HANDLER(systick);

DEFINE_HANDLER(gpio_porta);
DEFINE_HANDLER(gpio_portb);
DEFINE_HANDLER(gpio_portc);
DEFINE_HANDLER(gpio_portd);
DEFINE_HANDLER(gpio_porte);
DEFINE_HANDLER(uart0);
DEFINE_HANDLER(uart1);
DEFINE_HANDLER(ssi0);
DEFINE_HANDLER(i2c0);
DEFINE_HANDLER(pwm0_fault);
DEFINE_HANDLER(pwm0_gen0);
DEFINE_HANDLER(pwm0_gen1);
DEFINE_HANDLER(pwm0_gen2);
DEFINE_HANDLER(qei0);
DEFINE_HANDLER(adc0_seq0);
DEFINE_HANDLER(adc0_seq1);
DEFINE_HANDLER(adc0_seq2);
DEFINE_HANDLER(adc0_seq3);
DEFINE_HANDLER(watchdog);
DEFINE_HANDLER(timer0a_32);
DEFINE_HANDLER(timer0b_32);
DEFINE_HANDLER(timer1a_32);
DEFINE_HANDLER(timer1b_32);
DEFINE_HANDLER(timer2a_32);
DEFINE_HANDLER(timer2b_32);
DEFINE_HANDLER(analog_comp0);
DEFINE_HANDLER(analog_comp1);
DEFINE_HANDLER(sysctl);
DEFINE_HANDLER(flashctl);
DEFINE_HANDLER(gpio_portf);
DEFINE_HANDLER(uart2);
DEFINE_HANDLER(ssi1);
DEFINE_HANDLER(timer3a_32);
DEFINE_HANDLER(timer3b_32);
DEFINE_HANDLER(i2c1);
DEFINE_HANDLER(qei1);
DEFINE_HANDLER(can0);
DEFINE_HANDLER(can1);
DEFINE_HANDLER(hibernation);
DEFINE_HANDLER(usb);
DEFINE_HANDLER(pwm0_gen3);
DEFINE_HANDLER(udma_soft);
DEFINE_HANDLER(udma_error);
DEFINE_HANDLER(adc1_seq0);
DEFINE_HANDLER(adc1_seq1);
DEFINE_HANDLER(adc1_seq2);
DEFINE_HANDLER(adc1_seq3);
DEFINE_HANDLER(ssi2);
DEFINE_HANDLER(ssi3);
DEFINE_HANDLER(uart3);
DEFINE_HANDLER(uart4);
DEFINE_HANDLER(uart5);
DEFINE_HANDLER(uart6);
DEFINE_HANDLER(uart7);
DEFINE_HANDLER(i2c2);
DEFINE_HANDLER(i2c3);
DEFINE_HANDLER(timer4a_32);
DEFINE_HANDLER(timer4b_32);
DEFINE_HANDLER(timer5a_32);
DEFINE_HANDLER(timer5b_32);
DEFINE_HANDLER(timer0a_64);
DEFINE_HANDLER(timer0b_64);
DEFINE_HANDLER(timer1a_64);
DEFINE_HANDLER(timer1b_64);
DEFINE_HANDLER(timer2a_64);
DEFINE_HANDLER(timer2b_64);
DEFINE_HANDLER(timer3a_64);
DEFINE_HANDLER(timer3b_64);
DEFINE_HANDLER(timer4a_64);
DEFINE_HANDLER(timer4b_64);
DEFINE_HANDLER(timer5a_64);
DEFINE_HANDLER(timer5b_64);
DEFINE_HANDLER(sysexcept);
DEFINE_HANDLER(pwm1_gen0);
DEFINE_HANDLER(pwm1_gen1);
DEFINE_HANDLER(pwm1_gen2);
DEFINE_HANDLER(pwm1_gen3);
DEFINE_HANDLER(pwm1_fault);


// The Nested Vectored Interrupt Controller (NVIC) Table:
// Mark with .nvic_table (as in the linker script) so it'll be placed correctly
void(* nvic_table[])(void) __attribute__ ((used, section (".nvic_table"))) =
{
    HANDLER(reset),         // The reset handler
    HANDLER(nmi),           // The NMI handler
    HANDLER(hard_fault),    // The hard fault handler
    HANDLER(mman),          // The MPU fault handler
    HANDLER(bus_fault),     // The bus fault handler
    HANDLER(usage_fault),   // The usage fault handler
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    HANDLER(svcall),        // SVCall handler
    HANDLER(debug_monitor), // Debug monitor handler
    0,                      // Reserved
    HANDLER(pendsv),        // The PendSV handler
    HANDLER(systick),       // The SysTick handler
    HANDLER(gpio_porta),    // GPIO Port A
    HANDLER(gpio_portb),    // GPIO Port B
    HANDLER(gpio_portc),    // GPIO Port C
    HANDLER(gpio_portd),    // GPIO Port D
    HANDLER(gpio_porte),    // GPIO Port E
    HANDLER(uart0),         // UART0 Rx and Tx
    HANDLER(uart1),         // UART1 Rx and Tx
    HANDLER(ssi0),          // SSI0 Rx and Tx
    HANDLER(i2c0),          // I2C0 Master and Slave
    HANDLER(pwm0_fault),    // PWM Fault
    HANDLER(pwm0_gen0),     // PWM Generator 0
    HANDLER(pwm0_gen1),     // PWM Generator 1
    HANDLER(pwm0_gen2),     // PWM Generator 2
    HANDLER(qei0),          // Quadrature Encoder 0
    HANDLER(adc0_seq0),     // ADC Sequence 0
    HANDLER(adc0_seq1),     // ADC Sequence 1
    HANDLER(adc0_seq2),     // ADC Sequence 2
    HANDLER(adc0_seq3),     // ADC Sequence 3
    HANDLER(watchdog),      // Watchdog timer
    HANDLER(timer0a_32),    // Timer 0 subtimer A
    HANDLER(timer0b_32),    // Timer 0 subtimer B
    HANDLER(timer1a_32),    // Timer 1 subtimer A
    HANDLER(timer1b_32),    // Timer 1 subtimer B
    HANDLER(timer2a_32),    // Timer 2 subtimer A
    HANDLER(timer2b_32),    // Timer 2 subtimer B
    HANDLER(analog_comp0),  // Analog Comparator 0
    HANDLER(analog_comp1),  // Analog Comparator 1
    0,                      // Analog Comparator 2
    HANDLER(sysctl),        // System Control (PLL, OSC, BO)
    HANDLER(flashctl),      // FLASH Control
    HANDLER(gpio_portf),    // GPIO Port F
    0,                      // GPIO Port G
    0,                      // GPIO Port H
    HANDLER(uart2),         // UART2 Rx and Tx
    HANDLER(ssi1),          // SSI1 Rx and Tx
    HANDLER(timer3a_32),    // Timer 3 subtimer A
    HANDLER(timer3b_32),    // Timer 3 subtimer B
    HANDLER(i2c1),          // I2C1 Master and Slave
    HANDLER(qei1),          // Quadrature Encoder 1
    HANDLER(can0),          // CAN0
    HANDLER(can1),          // CAN1
    0,                      // Reserved
    0,                      // Reserved
    HANDLER(hibernation),   // Hibernate
    HANDLER(usb),           // USB0
    HANDLER(pwm0_gen3),     // PWM Generator 3
    HANDLER(udma_soft),     // uDMA Software Transfer
    HANDLER(udma_error),    // uDMA Error
    HANDLER(adc1_seq0),     // ADC1 Sequence 0
    HANDLER(adc1_seq1),     // ADC1 Sequence 1
    HANDLER(adc1_seq2),     // ADC1 Sequence 2
    HANDLER(adc1_seq3),     // ADC1 Sequence 3
    0,                      // Reserved
    0,                      // Reserved
    0,                      // GPIO Port J
    0,                      // GPIO Port K
    0,                      // GPIO Port L
    HANDLER(ssi2),          // SSI2 Rx and Tx
    HANDLER(ssi3),          // SSI3 Rx and Tx
    HANDLER(uart3),         // UART3 Rx and Tx
    HANDLER(uart4),         // UART4 Rx and Tx
    HANDLER(uart5),         // UART5 Rx and Tx
    HANDLER(uart6),         // UART6 Rx and Tx
    HANDLER(uart7),         // UART7 Rx and Tx
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    HANDLER(i2c2),          // I2C2 Master and Slave
    HANDLER(i2c3),          // I2C3 Master and Slave
    HANDLER(timer4a_32),    // Timer 4 subtimer A
    HANDLER(timer4b_32),    // Timer 4 subtimer B
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    0,                      // Reserved
    HANDLER(timer5a_32),    // Timer 5 subtimer A
    HANDLER(timer5b_32),    // Timer 5 subtimer B
    HANDLER(timer0a_64),    // Wide Timer 0 subtimer A
    HANDLER(timer0b_64),    // Wide Timer 0 subtimer B
    HANDLER(timer1a_64),    // Wide Timer 1 subtimer A
    HANDLER(timer1b_64),    // Wide Timer 1 subtimer B
    HANDLER(timer2a_64),    // Wide Timer 2 subtimer A
    HANDLER(timer2b_64),    // Wide Timer 2 subtimer B
    HANDLER(timer3a_64),    // Wide Timer 3 subtimer A
    HANDLER(timer3b_64),    // Wide Timer 3 subtimer B
    HANDLER(timer4a_64),    // Wide Timer 4 subtimer A
    HANDLER(timer4b_64),    // Wide Timer 4 subtimer B
    HANDLER(timer5a_64),    // Wide Timer 5 subtimer A
    HANDLER(timer5b_64),    // Wide Timer 5 subtimer B
    HANDLER(sysexcept),     // FPU
    0,                      // Reserved
    0,                      // Reserved
    0,                      // I2C4 Master and Slave
    0,                      // I2C5 Master and Slave
    0,                      // GPIO Port M
    0,                      // GPIO Port N
    0,                      // Quadrature Encoder 2
    0,                      // Reserved
    0,                      // Reserved
    0,                      // GPIO Port P (Summary or P0)
    0,                      // GPIO Port P1
    0,                      // GPIO Port P2
    0,                      // GPIO Port P3
    0,                      // GPIO Port P4
    0,                      // GPIO Port P5
    0,                      // GPIO Port P6
    0,                      // GPIO Port P7
    0,                      // GPIO Port Q (Summary or Q0)
    0,                      // GPIO Port Q1
    0,                      // GPIO Port Q2
    0,                      // GPIO Port Q3
    0,                      // GPIO Port Q4
    0,                      // GPIO Port Q5
    0,                      // GPIO Port Q6
    0,                      // GPIO Port Q7
    0,                      // GPIO Port R
    0,                      // GPIO Port S
    HANDLER(pwm1_gen0),     // PWM 1 Generator 0
    HANDLER(pwm1_gen1),     // PWM 1 Generator 1
    HANDLER(pwm1_gen2),     // PWM 1 Generator 2
    HANDLER(pwm1_gen3),     // PWM 1 Generator 3
    HANDLER(pwm1_fault)     // PWM 1 Fault
};


// External Links:

// Link to linker symbols (memory boundaries)
// text : __text_start_vma :: __text_end_vma
// data : __data_start_vma :: __data_end_vma
// bss  : __bss_start_vma  ::   _bss_end_vma
// (see tm4c.ld for more details)
extern unsigned long __text_start_vma;
extern unsigned long __text_end_vma;
extern unsigned long __data_start_vma;
extern unsigned long __data_end_vma;
extern unsigned long __bss_start_vma;
extern unsigned long __bss_end_vma;

// Link to project's entry point
extern int main();


// Interrupt Handlers:

// Declare a dummy interrupt handler that does nothing (essentially gets
// trapped in a loop). This works as the default interrupt handler as it
// retains the system state and stops execution when it is called; this
// interrupt handler will only ever be called if an unexpected interrupt
// (i.e. one that does not have a strongly defined interrupt handler) is
// triggered.
void __default_int_handler(void)
{
    while(1);
}

// A default reset handler. Configured in the same manner as the default
// handler above (reset_handler() is weakly aliased to this function) so
// that (if needed) this function can be overriden in a project using this
// file (shouldn't be necessary though).
void __default_rst_handler(void)
{
    // Set pointers to address of end of text section in flash and destination
    // address in SRAM:
    unsigned long *srcPtr = &__text_end_vma;
    unsigned long *dstPtr = &__data_start_vma;

    // Copy bytes from the flash copy of data until we reach __data_end_vma
    while(dstPtr < &__data_end_vma)
        *dstPtr++ = *srcPtr++;

    // Next, do the BSS section:
    dstPtr = &__bss_start_vma; // Start at the start VMA of the BSS section

    // Write 0s until we hit the end of the bss section:
    while(dstPtr < &__bss_end_vma)
        *dstPtr++ = 0;

    // (Shamelessly lifted from TivaWare - much thanks to TI)
    // Enable the floating-point unit.  This must be done here to handle the
    // case where main() uses floating-point and the function prologue saves
    // floating-point registers (which will fault if floating-point is not
    // enabled). Any configuration of the floating-point unit using DriverLib
    // APIs must be done here prior to the floating-point unit being enabled.
    //
    // Note that this does not use DriverLib since it might not be included in
    // this project.
    //
    HWREG(NVIC_CPAC) = ((HWREG(NVIC_CPAC) &
                         ~(NVIC_CPAC_CP10_M | NVIC_CPAC_CP11_M)) |
                        NVIC_CPAC_CP10_FULL | NVIC_CPAC_CP11_FULL);

    // Call main (start the program)!
    // Disgusting hacks to get LTO to behave until we have a better way:
    volatile int i = 1;
    while (i) { main(); i=0; }

    nvic_table[i]();
}

