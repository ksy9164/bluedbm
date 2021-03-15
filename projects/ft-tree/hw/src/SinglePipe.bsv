/* 
 * For log-analyzing 128 Bits/cycle, this module composed of three kinds of modules
 * decompressor -> tokenizer -> detector
 *  */
package SinglePipe;
import FIFO::*;
import Vector::*;

import LZAH::*;
import Serializer::*;
import Tokenizer::*;
import Detector::*;
import FIFOLI::*;
import DividedFIFO::*;
import MultiN::*;

import BRAM::*;
import BRAMFIFO::*;

interface GetIfc;
    method ActionValue#(Bit#(128)) get;
endinterface
interface SinglePipeIfc;
    method Action putHashTable(Bit#(152) data);
    method Action putSubHashTable(Bit#(129) data);
    method Action putData(Bit#(128) data);
    interface Vector#(8, GetIfc) get;
endinterface

(* synthesize *)
module mkSinglePipe(SinglePipeIfc);
    Vector#(2, DetectorIfc) detector <- replicateM(mkDetector);
    LZAHIfc#(128, 10) lzah_decompressor <- mkLZAH128_10;
    Vector#(8 ,TokenizerIfc) tokenizer <- replicateM(mkTokenizer);
    Reg#(Bit#(3)) tokenizer_input_handle <- mkReg(0);
    Vector#(2, FIFO#(Bit#(2))) tokenizerSignalQ <- replicateM(mkSizedBRAMFIFO(5000));
    Vector#(2, Reg#(Bit#(2))) tokenizer_output_handle <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(2))) tokenizer_hash_handle <- replicateM(mkReg(0));
    Vector#(8, FIFO#(Bit#(128))) outputQ <- replicateM(mkSizedBRAMFIFO(100)); 
    Vector#(8, Reg#(Bit#(1))) output_merge_handle <- replicateM(mkReg(0));

    Vector#(8, FIFO#(Tuple2#(Bit#(2), Bit#(128)))) tokenQ <- replicateM(mkSizedBRAMFIFO(500));
    Vector#(8, FIFO#(Tuple2#(Bit#(8), Bit#(8)))) hashQ <- replicateM(mkSizedBRAMFIFO(500));
    Vector#(8, FIFO#(Bit#(1))) hashFlagQ <- replicateM(mkSizedBRAMFIFO(500));

    Vector#(4, FIFO#(Tuple2#(Bit#(2), Bit#(128)))) tokenQ_st1 <- replicateM(mkSizedBRAMFIFO(500));
    Vector#(4, FIFO#(Tuple3#(Bit#(8), Bit#(8), Bit#(1)))) hashQ_st1 <- replicateM(mkSizedBRAMFIFO(500));
    Vector#(4, Reg#(Bit#(1))) st1_d_handle <- replicateM(mkReg(0));
    Vector#(4, Reg#(Bit#(1))) st1_h_handle <- replicateM(mkReg(0));

    Vector#(2, FIFO#(Tuple2#(Bit#(2), Bit#(128)))) tokenQ_st2 <- replicateM(mkSizedBRAMFIFO(500));
    Vector#(2, FIFO#(Tuple2#(Bit#(8), Bit#(8)))) hashQ_st2 <- replicateM(mkSizedBRAMFIFO(500));
    Vector#(2, Reg#(Bit#(1))) st2_d_handle <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(1))) st2_h_handle <- replicateM(mkReg(0));

    rule getDecompAndPutTokenizer;
        lzah_decompressor.deq;
        Bit#(128) d = lzah_decompressor.first;
        if (d[127:120] == 10 || d[127:120] == 0 || d[7:0] == 0 || d[7:0] == 10) begin
            tokenizer_input_handle <= tokenizer_input_handle + 1;
        end 
        tokenizer[tokenizer_input_handle].put(d);
    endrule

    for (Bit#(8) i = 0; i < 8; i = i + 1) begin
        rule getrid;
            Tuple2#(Bit#(8), Bit#(8)) d <- tokenizer[i].get_hash;
            hashQ[i].enq(d);
        endrule
        rule getriddd;
            Tuple2#(Bit#(2), Bit#(128)) d <- tokenizer[i].get_word;
            if (tpl_1(d) == 1) begin
                hashFlagQ[i].enq(0);
            end else if (tpl_1(d) == 2) begin
                hashFlagQ[i].enq(1);
            end
            tokenQ[i].enq(d);
        endrule
    end

    for (Bit#(8) i = 0; i < 4; i = i + 1) begin
        rule merge_d_one;
            Tuple2#(Bit#(2), Bit#(128)) d;
            if (st1_d_handle[i] == 0) begin
                tokenQ[i].deq;
                d = tokenQ[i].first;
            end else begin
                tokenQ[i + 4].deq;
                d = tokenQ[i + 4].first;
            end
            if (tpl_1(d) == 2) begin
                st1_d_handle[i] <= st1_d_handle[i] + 1;
            end
            tokenQ_st1[i].enq(d);
        endrule
        rule merge_h_one;
            Tuple2#(Bit#(8), Bit#(8)) d;
            Bit#(1) handle = 0;
            if (st1_h_handle[i] == 0) begin
                hashQ[i].deq;
                hashFlagQ[i].deq;
                d = hashQ[i].first;
                handle = hashFlagQ[i].first;
            end else begin
                hashQ[i + 4].deq;
                hashFlagQ[i + 4].deq;
                d = hashQ[i + 4].first;
                handle = hashFlagQ[i + 4].first;
            end
            if (handle == 1) begin
                st1_h_handle[i] <= st1_h_handle[i] + 1;
            end
            hashQ_st1[i].enq(tuple3(tpl_1(d), tpl_2(d), handle));
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule merge_d_one;
            Tuple2#(Bit#(2), Bit#(128)) d;
            if (st2_d_handle[i] == 0) begin
                tokenQ_st1[i].deq;
                d = tokenQ_st1[i].first;
            end else begin
                tokenQ_st1[i + 2].deq;
                d = tokenQ_st1[i + 2].first;
            end
            if (tpl_1(d) == 2) begin
                st2_d_handle[i] <= st2_d_handle[i] + 1;
            end
            tokenQ_st2[i].enq(d);
        endrule
        rule merge_h_one;
            Tuple3#(Bit#(8), Bit#(8), Bit#(1)) d;
            Bit#(1) handle = 0;
            if (st2_h_handle[i] == 0) begin
                hashQ_st1[i].deq;
                d = hashQ_st1[i].first;
            end else begin
                hashQ_st1[i + 2].deq;
                d = hashQ_st1[i + 2].first;
            end
            if (tpl_3(d) == 1) begin
                st2_h_handle[i] <= st2_h_handle[i] + 1;
            end
            hashQ_st2[i].enq(tuple2(tpl_1(d), tpl_2(d)));
        endrule
    end

    for (Bit#(3) i = 0; i < 2; i = i + 1) begin
        rule getTokenized;
            tokenQ_st2[i].deq;
            Tuple2#(Bit#(2), Bit#(128)) d = tokenQ_st2[i].first;
            detector[i].put_word(d);
        endrule

        rule getHash;
            hashQ_st2[i].deq;
            Tuple2#(Bit#(8), Bit#(8)) d = hashQ_st2[i].first;
            detector[i].put_hash(d);
        endrule
    end

/*     for (Bit#(3) i = 0; i < 2; i = i + 1) begin
 *         rule getTokenized;
 *             tokenQ[zeroExtend(tokenizer_output_handle[i]) + i * 4].deq;
 *             Tuple2#(Bit#(2), Bit#(128)) d = tokenQ[zeroExtend(tokenizer_output_handle[i]) + i * 4].first;
 *             Bit#(2) wordflag = tpl_1(d);
 *             Bit#(128) word = tpl_2(d);
 *             if (wordflag != 0) begin
 *                 tokenizerSignalQ[i].enq(wordflag);
 *             end
 *             if (wordflag == 2) begin
 *                 tokenizer_output_handle[i] <= tokenizer_output_handle[i] + 1;
 *             end
 *             [> detector[i].put_word(d); <]
 *         endrule
 *
 *         rule getHash;
 *             tokenizerSignalQ[i].deq;
 *             Bit#(2) flag = tokenizerSignalQ[i].first;
 *             hashQ[zeroExtend(tokenizer_hash_handle[i]) + i * 4].deq;
 *             Tuple2#(Bit#(8), Bit#(8)) d = hashQ[zeroExtend(tokenizer_hash_handle[i]) + i * 4].first;
 *             [> detector[i].put_hash(d); <]
 *             if (flag == 2) begin
 *                 tokenizer_hash_handle[i] <= tokenizer_hash_handle[i] + 1;
 *             end
 *         endrule
 *     end */

    
    for (Bit#(4) i = 0; i < 8; i = i + 1) begin
        rule outputMergingOne;
            Bit#(128) d <- detector[0].get[i].get;
            Bit#(1) check = 0;
            if (d == 10) begin
                output_merge_handle[i] <= output_merge_handle[i] + 1;
            end
            outputQ[i].enq(d);
        endrule

        rule outputMergingTwo;
            Bit#(128) d <- detector[1].get[i].get;
            Bit#(1) check = 0;
            if (d == 10) begin
                output_merge_handle[i] <= output_merge_handle[i] + 1;
            end
            outputQ[i].enq(d);
        endrule
    end

    Vector#(8, GetIfc) get_;
    for (Integer i = 0; i < 8; i = i+1) begin
        get_[i] = interface GetIfc;
            method ActionValue#(Bit#(128)) get;
                outputQ[i].deq;
                return outputQ[i].first;
            endmethod
        endinterface;
    end
    interface get = get_;

    method Action putHashTable(Bit#(152) data);
        detector[0].put_table(data);
        detector[1].put_table(data);
    endmethod
    method Action putSubHashTable(Bit#(129) data);
        detector[0].put_sub_table(data);
        detector[1].put_sub_table(data);
    endmethod
    method Action putData(Bit#(128) data);
        lzah_decompressor.enq(data);
    endmethod
endmodule
endpackage
