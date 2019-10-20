.syntax unified
.p2align 2

.global DisableInterrupts
.type   DisableInterrupts,%function
DisableInterrupts:
    .fnstart
    CPSID   I
    BX      LR
    .fnend

.global EnableInterrupts
.type   EnableInterrupts,%function
EnableInterrupts:
    .fnstart
    CPSIE   I
    BX      LR
    .fnend

# *********** StartCritical ************************
# make a copy of previous I bit, disable interrupts
.global StartCritical
.type   StartCritical,%function
StartCritical:
    .fnstart
    MRS     R0, PRIMASK @ save old status
    CPSID   I           @ mask all (except faults)
    BX      LR
    .fnend

# *********** EndCritical ************
# restore I bit to its previous value
.global EndCritical
.type   EndCritical,%function
EndCritical:
    .fnstart
    MSR     PRIMASK, R0 @ restore
    BX      LR
    .fnend
