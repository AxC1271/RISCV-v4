# RV32I Dual-Core Out-of-Order Processor with MESI

A dual-core out-of-order RISC-V processor designed to explore dynamic instruction scheduling, speculative execution, register renaming, and cache coherence.

This project builds on my previous 2-way in-order superscalar processor. RISC-V v3 demonstrated that widening the pipeline can approach 2 IPC when enough independent instructions are available. RISC-V v4 explores the next problem: **what happens when useful instruction-level parallelism exists, but it is hidden behind dependencies in program order?**

The target architecture combines an out-of-order execution engine with private per-core caches and a MESI-based coherence protocol.

---

## Motivation: Moving Beyond In-Order Superscalar

**The problem with a 2-way in-order pipeline:**

RISC-V v3 can fetch and execute up to two instructions per cycle.

On a long stream of independent ALU instructions, the processor reaches approximately:

```text
RISC-V v3:

Measured IPC:          ~1.85
Theoretical maximum:    2.00
```

This demonstrates that the datapath is capable of sustaining close to its theoretical 2-wide throughput when the instruction stream provides enough instruction-level parallelism.

Real programs are not made entirely of independent instructions.

Consider:

```asm
lw   x5, 0(x1)
add  x6, x5, x2
sub  x10, x8, x9
and  x11, x12, x13
```

The `add` depends on the result of the load and cannot execute until `x5` becomes available.

The `sub` and `and`, however, are independent.

An in-order processor still has to respect instruction issue order. If an older instruction is waiting on an operand, useful younger instructions may be unable to move ahead even though their operands and execution units are ready.

The problem is therefore not necessarily a lack of instruction-level parallelism.

Sometimes the ILP already exists, but it is located **later in the instruction stream**.

RISC-V v4 is designed to explore this limitation by allowing ready instructions to execute independently of stalled older instructions while still preserving the appearance of in-order architectural execution.

---

# Architecture Overview

## Target Core Design

**ISA:** RV32I

**Cores:** 2

**Execution:** Out-of-order

**Issue:** Superscalar

**Register Renaming:** Physical register based

**Instruction Scheduling:** Reservation stations

**Instruction Completion:** Out of order

**Architectural Retirement:** In order

**Retirement Tracking:** Reorder buffer

**Result Broadcast:** Common Data Bus

**Memory System:** Private per-core caches

**Cache Coherence:** MESI

At a high level, each core separates **when an instruction executes** from **when it becomes architecturally visible**.

Instructions can wait in the scheduling structures until their operands become available.

A younger instruction whose operands are ready may therefore execute before an older instruction that is still waiting on a dependency.

The reorder buffer then restores architectural ordering at retirement.

This is the central idea behind the project:

> **Execute when ready. Commit in order.**

---

# Out-of-Order Execution

In an in-order pipeline, program order strongly constrains execution order.

Consider:

```asm
lw   x5, 0(x1)
add  x6, x5, x2
xor  x10, x11, x12
sub  x13, x14, x15
```

The first two instructions form a dependency chain.

The final two do not depend on that chain.

Instead of forcing the independent instructions to wait behind the stalled `add`, an out-of-order processor places instructions into scheduling structures and executes them when their required operands become available.

Conceptually:

```text
Program Order:

lw   x5, ...
add  x6, x5, x2    <- waiting for x5
xor  x10, x11, x12 <- ready
sub  x13, x14, x15 <- ready
```

Possible execution order:

```text
lw
xor
sub
add
```

Architectural retirement still occurs in the original program order:

```text
lw -> add -> xor -> sub
```

This allows the processor to exploit instruction-level parallelism across a larger instruction window rather than only between instructions that happen to appear next to each other.

---

# Register Renaming

Out-of-order execution creates another problem: not every register dependency represents a true flow of data.

There are three important dependency types:

```text
RAW    Read After Write
WAR    Write After Read
WAW    Write After Write
```

A **RAW dependency** is a true data dependency.

```asm
add x5, x1, x2
sub x6, x5, x3
```

The `sub` genuinely requires the value produced by the `add`.

That dependency cannot be removed.

WAR and WAW dependencies are different.

They exist because multiple instructions happen to use the same architectural register name.

### WAW — Write After Write

```asm
add x5, x1, x2
sub x5, x3, x4
```

Both instructions write `x5`.

### WAR — Write After Read

```asm
add x6, x5, x1
sub x5, x2, x3
```

The older instruction must read the old value of `x5` before the younger instruction replaces it.

These are **name dependencies**, not true data dependencies.

Register renaming removes them by mapping architectural registers onto a larger set of physical registers.

Conceptually:

```text
Architectural:

add x5, x1, x2
sub x5, x3, x4
```

may become:

```text
Physical:

add P17, P3, P8
sub P22, P5, P9
```

The two writes no longer target the same physical storage location.

This eliminates WAR and WAW hazards from the execution engine and allows instructions that would otherwise appear dependent to execute independently.

RAW dependencies remain because they represent actual dataflow.

---

# Reservation Stations

After rename and dispatch, instructions wait in **reservation stations** associated with the execution hardware.

A reservation-station entry tracks information such as:

```text
Operation
Destination tag
Source operand 1 / tag
Source operand 2 / tag
Operand-ready state
```

For example:

```text
ADD   dst=P18   src1=P7 READY   src2=P12 WAIT
SUB   dst=P21   src1=P4 READY   src2=P9  READY
```

The `ADD` cannot execute because one operand is still unavailable.

The `SUB` is completely ready.

Instead of blocking the pipeline behind the `ADD`, the scheduler can issue the `SUB` to an available execution unit.

When the missing value for the `ADD` eventually arrives, its reservation-station entry becomes ready and it can execute as well.

The reservation stations therefore form the core of the processor's **dynamic scheduling** mechanism.

---

# Common Data Bus

Execution units need a way to communicate completed results to instructions waiting on those values.

The architecture uses a **Common Data Bus (CDB)** for result broadcast.

A completed operation broadcasts both its value and the physical-register or destination tag associated with that value.

Reservation stations compare the broadcast tag against operands they are waiting for.

If the tag matches:

```text
waiting tag = P12

CDB:
    tag   = P12
    value = 42
```

the reservation station captures the value and marks that operand as ready.

This allows dependent instructions to wake up as soon as their inputs become available without waiting for the producing instruction to retire architecturally.

The CDB therefore connects **execution completion** with **dependency resolution**.

---

# Reorder Buffer

Allowing instructions to execute out of order improves scheduling freedom, but the processor must still behave as though instructions executed in program order.

The **Reorder Buffer (ROB)** provides that boundary.

Instructions receive ROB entries in program order during dispatch.

An entry tracks the state required to eventually retire the instruction, such as:

```text
Instruction / operation state
Destination
Completion status
Result information
Exception state
```

Instructions may finish execution in any order:

```text
Instruction 1    waiting
Instruction 2    complete
Instruction 3    complete
Instruction 4    complete
```

but instructions retire from the head of the ROB in program order.

Even though instructions 2–4 have completed, they cannot become architecturally committed before instruction 1.

This provides **precise architectural state** and creates a clear point where speculative execution becomes permanent.

The ROB also becomes important for branch recovery. If a branch is mispredicted, younger speculative instructions can be identified and discarded before they modify architectural state.

---

# Putting the OoO Datapath Together

The major structures work together as a dependency-tracking system.

Register renaming determines **which value** an instruction depends on.

Reservation stations determine **when its operands are ready**.

The CDB distributes **newly produced values**.

The ROB determines **when completed work can safely become architectural state**.

Together, these structures allow execution to occur dynamically while retirement remains ordered.

---

# Dual-Core Architecture

RISC-V v4 extends the problem beyond instruction-level parallelism by introducing a second processor core.

Each core executes its own instruction stream and maintains its own private cache state.

Private caches improve locality and reduce the need for every memory operation to access a shared lower-level memory structure.

They also create a new problem.

The same memory address can now exist in **multiple caches at the same time**.

Those copies have to remain coherent.

---

# MESI Cache Coherence

RISC-V v4 uses the MESI protocol as the target coherence model for the private caches.

Each cache line can exist in one of four states:

```text
M    Modified
E    Exclusive
S    Shared
I    Invalid
```

### Modified

The cache contains the only valid copy of the line, and that copy has been modified relative to memory.

```text
Core 0: M
Core 1: I
```

The modified data must eventually be written back before another agent can rely on the older memory copy.

### Exclusive

The cache contains the only cached copy, but the data still matches memory.

```text
Core 0: E
Core 1: I
```

Because no other cache currently shares the line, the core can transition from Exclusive to Modified when it writes the line without first invalidating another cached copy.

### Shared

Multiple caches may hold clean copies of the same line.

```text
Core 0: S
Core 1: S
```

Both cores can read the data, but a core must obtain exclusive ownership before modifying it.

### Invalid

The cache line does not contain a valid copy of the block.

```text
Core 0: M
Core 1: I
```

If Core 1 later wants the same address, the coherence system must coordinate access so that Core 1 observes the correct value.

The important idea is that MESI tracks both **whether a cache line is valid** and **what ownership rights a core currently has over that line**.

This allows each core to benefit from private caching while maintaining a coherent view of shared memory.

---

# Why MESI Matters

Consider two cores accessing the same address:

```text
Core 0:
    load A

Core 1:
    load A
```

Both may eventually hold the line in the Shared state.

```text
Core 0: S
Core 1: S
```

Now Core 0 wants to write `A`.

Core 0 cannot simply modify its local copy while Core 1 continues reading the old value.

The coherence protocol must invalidate the other shared copy before Core 0 obtains write ownership.

```text
Before:

Core 0: S
Core 1: S

After Core 0 obtains ownership and writes:

Core 0: M
Core 1: I
```

This is the fundamental problem cache coherence solves.

The processor now has two different forms of ordering to maintain:

```text
Inside each core:
    Out-of-order execution
    In-order architectural retirement

Between cores:
    Coherent shared-memory behavior
```

Combining these correctly is one of the main architectural challenges of RISC-V v4.

---

# Design Challenges

## Challenge 1: Finding ILP Beyond Program Order

RISC-V v3 demonstrated that a 2-way pipeline can approach 2 IPC when given independent instructions.

The harder problem is finding that independence in real instruction streams.

A blocked instruction should not necessarily block every younger instruction behind it.

The OoO scheduler therefore has to identify which instructions are actually dependent and which can safely execute while older operations wait.

---

## Challenge 2: Register Renaming

Architectural register names create WAR and WAW dependencies that unnecessarily constrain out-of-order scheduling.

The rename stage must maintain a correct mapping between architectural and physical registers while allocating new destinations and eventually recovering old physical registers.

Correct rename state also becomes important when speculative execution is rolled back after a branch misprediction.

---

## Challenge 3: Dynamic Scheduling

Reservation stations must track operand availability and determine which ready instructions should receive limited execution resources.

This turns issue from a fixed pipeline operation into a scheduling problem.

The design must balance:

* Instruction age
* Operand readiness
* Execution-unit availability
* Result-broadcast bandwidth
* Structural hazards

---

## Challenge 4: Precise Retirement

Execution may happen out of order, but architectural state cannot become visible arbitrarily.

The reorder buffer must ensure that completed instructions retire in program order and that exceptions or branch mispredictions can recover to a precise architectural state.

---

## Challenge 5: Result Broadcast

Multiple instructions may complete near the same time while many reservation-station entries are waiting for their results.

The Common Data Bus therefore introduces its own bandwidth and timing constraints.

As the execution engine gets wider, result broadcast can become a significant hardware cost rather than simply a logical connection between blocks.

---

## Challenge 6: Cache Coherence

With two private caches, correctness can no longer be considered from the perspective of only one core.

Loads, stores, evictions, cache misses, and coherence transactions can all change the state of a cache line.

The MESI controller must keep both caches consistent while minimizing unnecessary coherence traffic.

---

# Verification

Verification will be divided between single-core OoO behavior and multicore coherence behavior.

## Out-of-Order Verification

Planned tests include:

* RAW dependency chains
* Independent instructions executing around blocked instructions
* WAR/WAW elimination through register renaming
* Reservation-station wakeup
* Common Data Bus result forwarding
* ROB completion and in-order retirement
* Branch misprediction recovery
* Physical-register allocation and recovery
* Precise architectural state

A particularly important invariant is:

```text
Out-of-order execution must produce the same
architectural state as correct sequential execution.
```

Performance does not matter if dynamic scheduling changes program semantics.

## MESI Verification

Coherence testing will exercise transitions between:

```text
Modified
Exclusive
Shared
Invalid
```

including scenarios where both cores access the same cache line.

Planned tests include:

* Read sharing between cores
* Write ownership acquisition
* Shared-line invalidation
* Modified-line intervention/writeback
* Cache eviction
* Repeated ownership transfer
* Simultaneous accesses to shared data
* Correct data visibility after coherence transactions

SystemVerilog Assertions and formal verification will also be used where practical to check architectural and coherence invariants.

---

# Performance Analysis

RISC-V v3 primarily measures how effectively a fixed 2-way in-order pipeline can exploit ILP already visible at dispatch.

RISC-V v4 will instead measure how much additional parallelism can be recovered by looking across a larger instruction window.

Important metrics will include:

* IPC
* Instructions issued per cycle
* Instructions committed per cycle
* ROB occupancy
* Reservation-station occupancy
* Execution-unit utilization
* Cycles stalled on true RAW dependencies
* Rename stalls
* ROB-full stalls
* Reservation-station-full stalls
* CDB utilization
* Branch misprediction penalty
* Cache hit/miss behavior
* MESI coherence traffic

The key comparison is not simply:

```text
In-order IPC vs. OoO IPC
```

but **why** the OoO machine performs differently.

A larger instruction window and dynamic scheduler add substantial hardware complexity. The goal is to measure how much useful ILP that complexity actually recovers.

---

# Timing Analysis

The processor will be synthesized and analyzed separately from functional simulation.

The implementation flow will evaluate:

* Critical-path delay
* Maximum clock frequency
* Register-renaming logic
* Reservation-station wakeup/select timing
* Common Data Bus timing and fanout
* Reorder-buffer logic
* Cache and MESI-controller timing
* Standard-cell count
* Synthesized area

This is especially important for an out-of-order processor.

Increasing IPC by adding scheduling structures, associative tag comparisons, larger instruction windows, and result-broadcast networks also increases implementation complexity.

For that reason, final performance should consider both:

```text
IPC
```

and:

```text
Instructions/second = IPC × clock frequency
```

A higher-IPC architecture is only useful if the additional hardware required to achieve that IPC does not reduce clock frequency enough to eliminate the throughput gain.

---

# Repository Structure

```text
/0-rtl/    - SystemVerilog implementation of the processor
/1-sim/    - directed tests, workloads, and performance benchmarks
/2-formal/ - SystemVerilog assertions and formal verification
/3-sta/    - synthesis and static timing analysis
/4-images/ - architecture and implementation diagrams
```

---

# Build & Simulate

## Compile

```bash
# Commands will be added as the RTL implementation develops.
```

## Run

```bash
# Workload and regression commands will be added here.
```

---

# Project Goals

The first goal is to build and verify a single out-of-order execution engine capable of dynamically scheduling independent instructions around stalled dependencies while preserving precise in-order architectural retirement.

The design will then be extended into a dual-core system with private coherent caches using MESI.

Performance characterization will compare the OoO architecture against my previous 2-way in-order superscalar processor to measure how much additional instruction-level parallelism can actually be recovered from the same workloads.

The final design will be synthesized and timed to evaluate the tradeoff between higher IPC and the hardware cost of register renaming, dynamic scheduling, result broadcast, speculative execution, and cache coherence.

The broader goal is the same as my previous processor projects: not just to build a more complicated architecture, but to measure **which architectural mechanisms actually translate into useful performance once their hardware cost is included.**

---

Thanks for stopping by!
