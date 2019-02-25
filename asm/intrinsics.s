.syntax unified

.global DisableInterrupts
DisableInterrupts:
    CPSID   I
    BX      LR


.global EnableInterrupts
EnableInterrupts:
    CPSIE   I
    BX      LR

# *********** StartCritical ************************
# make a copy of previous I bit, disable interrupts
.global StartCritical
StartCritical:
    MRS     R0, PRIMASK @ save old status
    CPSID   I           @ mask all (except faults)
    BX      LR

# *********** EndCritical ************
# restore I bit to its previous value
.global EndCritical
EndCritical:
    MSR     PRIMASK, R0 @ restore
    BX      LR