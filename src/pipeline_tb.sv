`timescale 1ns/1ps

module IE2025005_pipeline_tb;

    top uut();

    wire [63:0] cycles      = uut.mips.pmu_inst.cycle_count;
    wire [63:0] instrs      = uut.mips.pmu_inst.instr_count;
    wire [63:0] mem_acc     = uut.mips.pmu_inst.mem_count;
    wire [63:0] branches    = uut.mips.pmu_inst.branch_count;
    wire [63:0] mispredicts = uut.mips.pmu_inst.mispredict_count;
    wire [63:0] stalls      = uut.mips.pmu_inst.stall_count;

    real cpi, mem_pct, branch_pct, predict_acc, efficiency;

    initial begin
        $dumpfile("IE2025005_pipeline.vcd");
        $dumpvars(0, uut);

        // Wait until HALT reaches Writeback — no hardcoded count, works for any program
        wait(uut.mips.dp.haltW === 1'b1);
        #1;

        cpi         = $itor(cycles)   / $itor(instrs);
        mem_pct     = $itor(mem_acc)  / $itor(instrs) * 100.0;
        branch_pct  = $itor(branches) / $itor(instrs) * 100.0;
        predict_acc = (branches > 0) ?
                      ($itor(branches - mispredicts) / $itor(branches) * 100.0) : 100.0;
        efficiency  = $itor(cycles - stalls - mispredicts) / $itor(cycles) * 100.0;

        $display("Simulation complete: HALT reached Writeback.");

        $display("==================================================");
        $display("       IE2025005 -- PMU Performance Report        ");
        $display("==================================================");
        $display("  Pipeline: 5-stage in-order, static not-taken");
        $display("--------------------------------------------------");
        $display("  EXECUTION SUMMARY");
        $display("    CPU Cycles           : %0d",   cycles);
        $display("    Instructions Retired : %0d",   instrs);
        $display("    CPI                  : %.2f",  cpi);
        $display("--------------------------------------------------");
        $display("  MEMORY");
        $display("    Memory Accesses      : %0d",   mem_acc);
        $display("    Memory Access Rate   : %.1f%%", mem_pct);
        $display("--------------------------------------------------");
        $display("  BRANCH ANALYSIS");
        $display("    Branch Count         : %0d",   branches);
        $display("    Branch Frequency     : %.1f%%", branch_pct);
        $display("    Mispredictions       : %0d",   mispredicts);
        $display("    Prediction Accuracy  : %.1f%%", predict_acc);
        $display("--------------------------------------------------");
        $display("  HAZARD ANALYSIS");
        $display("    Load-Use Stall Cycles: %0d",   stalls);
        $display("    Branch Flush Cycles  : %0d",   mispredicts);
        $display("    Useful Cycles        : %0d",   cycles - stalls - mispredicts);
        $display("    Pipeline Efficiency  : %.1f%%", efficiency);
        $display("==================================================");

        $finish;
    end

endmodule
