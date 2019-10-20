/**
 * tm4c.ld : TM4C linker script for use with the GNU Build System
 *
 * With credit to:
 *  - Lukasz Janyst (bit.ly/2pxKw8x)
 *  - TI's TivaWare
 *  - The uctools Project (bit.ly/2oIRO9y)
 *
 * Author:   Rahul Butani
 * Modified: February 27th, 2019
 */

ENTRY(reset_handler)

/* Memory Layout */
MEMORY
{
    /* 256 KiB of Flash starting at 0x00000000; read only */
    FLASH (rx) : ORIGIN = 0x00000000, LENGTH = 0x00040000
    /* 32 KiB of RAM starting at 0x20000000; read & write */
    SRAM (rwx) : ORIGIN = 0x20000000, LENGTH = 0x00008000
}

SECTIONS
{
    /* Code & friends; stored in flash and hence persistent. */
    .text :
    {
        /* Text Section starts here, expose a symbol for this memory address */
        __text_start_vma = .;

        /* As per the TM4C123GH6PM datasheet, the first 4 bytes of Flash
         * should be the initial (POR) stack pointer (SP).
         * We'll use the very end of our RAM as our initial SP since the
         * stack grows downwards (lower memory addresses). For some uses,
         * this apparently (http://bit.ly/2py8ikv) needs to be aligned on
         * an 8 byte boundary so we'll use 0x20007ff8.
         */
        LONG(0x20007ff8)

        /* Put the Interrupt Vector Table next.
         * Use KEEP to prevent the table from being optimized away.
         */
        KEEP(*(.nvic_table))

        /* Next, lets put in code and read-only (constant) data sections from
         * all the files at hand.
         */
        . = ALIGN(4);
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);

    } > FLASH /* As mentioned, this will go into Flash */

    /* Used for "exception winding" and stack traces, unclear if needed here.
     * (but it shouldn't hurt)
     * http://infocenter.arm.com/help/topic/com.arm.doc.ihi0044f/IHI0044F_aaelf.pdf
     * http://stackoverflow.com/questions/21527256/when-is-arm-exidx-is-used
     */
    .ARM.exidx :
    {
        /**(.ARM.exidx*)*/
        /**(.gnu.linkonce.armexidx*)*/

        /* This is the end of the text section, expose a symbol */
        __text_end_vma = .;

    } > FLASH

    /* Read-write data that exists at compile time (i.e. global/static vars
     * that are initialized).
     * Note that when we actually load the program onto the board, we can't
     * put anything in RAM (since anything in RAM doesn't persist across)
     * power cycles. So, we'll put this in Flash and load it into RAM once
     * the board powers on (in the reset handler - this is why we expose
     * memory addresses as link symbols).
     */
    .data : AT(ADDR(.text) + SIZEOF(.text) + SIZEOF(.ARM.exidx))
    {
        /* Data Section starts here, expose a symbol */
        __data_start_vma = .;

        . = ALIGN(4);

        /* Put the data sections from all the files we have in */
        *(.data*)

        /* Not sure if this is entirely needed (vtable is a C++ thing?) but
         * TivaWare apparently needs this in RAM, so we'll oblige.
         */
        *(vtable)

        . = ALIGN(4);

        /* Data Section ends here, expose a symbol */
        __data_end_vma = .;

    } > SRAM            /* As mentioned, we want to put this data into flash.
                         * However, we want our addresses in our symbols to
                         * point to the memory address for RAM, not flash.
                         * That's what "> SRAM AT" does; it sets our VMAs
                         * (virtual memory addresses) to RAM locations, even
                         * though our LMAs (load memory addresses - where we
                         * actually put the data in the binary ELF) point to
                         * flash locations.
                         *
                         * UPDATE: There seems to be something hokey going on;
                         * perhaps objcopy takes care of actually copying the
                         * contents of .data into flash. So, we'll just stick
                         * our stuff into 'SRAM' so that the addresses are
                         * right.
                         */

    /* Allocated (but blank) space for read-write data (i.e. global/static vars
     * that are declared but not initialized)
     * This also is meant to exist in RAM, however we don't bother saving it
     * into flash since it's all 0s; all we need are the memory locations.
     */
    .bss :
    {
        . = ALIGN(4);

        /* BSS Section starts here, expose a symbol */
        __bss_start_vma = .;

        /* Put the bss sections from all the file we have in */
        *(.bss*)

        /* Legacy FORTRAN (?) thing, for variables shared between compilation
         * units; not sure if actually needed, but it shouldn't hurt.
         */
        *(COMMON)

        . = ALIGN(4);

        /* BSS Section ends here, expose a symbol */
        __bss_end_vma = .;
    } > SRAM    /* Set to go into RAM so that our VMAs are correct. */

    /* Stuff that isn't needed for an embedded system */
    /DISCARD/ :
    {
        *(.init*)
        *(.fini*)
        *(.ARM.exidx)
    }
}
