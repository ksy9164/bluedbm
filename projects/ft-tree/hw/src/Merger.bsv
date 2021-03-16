package Merger;

import FIFO::*;
import FIFOLI::*;
import Vector::*;

typedef Bit#(128) Input_t;

interface MergerIfc;
    method Input_t first;
    method Action deq;
    method Action enqOne(Input_t d);
    method Action enqTwo(Input_t d);
endinterface

module mkMerger (MergerIfc);
    Input_t spl = 10;

    Vector#(2, FIFOLI#(Input_t, 2)) inQ <- replicateM(mkFIFOLI);
    FIFO#(Input_t) outQ <- mkFIFO;
    Reg#(Bit#(1)) handle <- mkReg(0);
    Reg#(Bit#(1)) mergeFlag <- mkReg(0);
    Reg#(Bit#(1)) merging_target <- mkReg(0);

    rule roulette;
        handle <= handle + 1;
    endrule

    rule mergingOutputStepOne(mergeFlag == 0);
        inQ[handle].deq;
        Input_t d = inQ[handle].first;
        outQ.enq(d);
        mergeFlag <= 1;
        merging_target <= handle;
    endrule

    rule mergingOutputStepTwo(mergeFlag == 1);
        inQ[merging_target].deq;
        Bit#(128) d = inQ[merging_target].first;
        outQ.enq(d);
        if (d == spl) begin
            mergeFlag <= 0;
        end
    endrule

    method Action enqOne(Input_t d);
        inQ[0].enq(d);
    endmethod
    method Action enqTwo(Input_t d);
        inQ[1].enq(d);
    endmethod
    method Input_t first;
        return outQ.first;
    endmethod
    method Action deq;
        outQ.deq;
    endmethod
endmodule
endpackage
