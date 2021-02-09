package Tokenizer8bits;

import FIFO::*;
import Vector::*;
import Serializer::*;
import BRAM::*;
import BRAMFIFO::*;
import FIFOLI::*;

interface Tokenizer8bitsIfc;
    method Action put(Bit#(64) data);
    method ActionValue#(Tuple2#(Bit#(1), Bit#(128))) get_word;
    method ActionValue#(Tuple3#(Bit#(1), Bit#(8), Bit#(8))) get_hash;
endinterface

function Bit#(8) rand_generator (Bit#(8) old_rand);
    Bit#(8) a = 133;
    Bit#(8) b = 237;
    Bit#(8) c = 255;
	return ((a*old_rand) + b) % c;
endfunction

function Bit#(8) cuckoohash_1 (Bit#(8) idx, Bit#(8) temp);
	return (((idx ^ temp) * (idx + temp)) + idx);
endfunction

function Bit#(8) cuckoohash_2 (Bit#(8) idx, Bit#(8) temp);
	Bit#(8) rd = rand_generator(idx);
	return ((idx ^ (temp + rd)) * rd);
endfunction

(* synthesize *)
module mkTokenizer8bits (Tokenizer8bitsIfc);
    FIFOLI#(Bit#(64), 3) inputQ <- mkFIFOLI;
    FIFO#(Bit#(8)) toTokenizingQ <- mkFIFO;
    FIFO#(Bit#(8)) toHashingQ <- mkFIFO;
    FIFOLI#(Vector#(2, Bit#(8)), 5) hashQ <- mkFIFOLI;
    FIFOLI#(Bit#(128), 5) wordQ <- mkFIFOLI;
    FIFOLI#(Bit#(1), 5) linespaceQ <- mkFIFOLI;
    FIFOLI#(Bit#(1), 5) wordendQ <- mkFIFOLI;

    Reg#(Bit#(128)) token_buff <- mkReg(0);
    Reg#(Bit#(4)) char_cnt <- mkReg(0);
    Reg#(Bit#(8)) hash_a <- mkReg(0);
    Reg#(Bit#(8)) hash_b <- mkReg(33);

    Reg#(Bit#(1)) token_handle <- mkReg(0);

    SerializerIfc#(64, 8) serial_inputQ <- mkSerializer; 

    rule serial8Bits;
        inputQ.deq;
        Bit#(64) d = inputQ.first;
        serial_inputQ.put(d);
    endrule

    rule get8Bits;
        Bit#(8) serialized <- serial_inputQ.get;
        toTokenizingQ.enq(serialized);
        toHashingQ.enq(serialized);
    endrule

    rule doTokenizing(token_handle == 0);
        toTokenizingQ.deq;
        Bit#(8) d = toTokenizingQ.first;

        Bit#(4) cnt = char_cnt;
        Bit#(128) t_buff = token_buff;

        if (d == 32 || d == 10) begin
            if (d == 10) begin
                linespaceQ.enq(1);
            end else begin
                linespaceQ.enq(0);
            end
            token_buff <= 0;
            char_cnt <=0;
            wordendQ.enq(1);
            wordQ.enq(t_buff);
        end else if (cnt == 15) begin
            t_buff = (t_buff << 8) | zeroExtend(d);

            token_buff <= 0;
            char_cnt <= 0;
            wordQ.enq(t_buff);
            token_handle <= 1;
            /* wordendQ.enq(0); */
        end else begin
            t_buff = (t_buff << 8) | zeroExtend(d);

            token_buff <= t_buff;
            char_cnt <= char_cnt + 1;
        end
    endrule

    rule bytes16Exception(token_handle == 1);
        Bit#(8) d = toTokenizingQ.first;
        toTokenizingQ.deq;
        if (d == 32 || d == 10) begin
            token_buff <= 0;
            char_cnt <= 0;
            wordendQ.enq(1);
            if (d == 10) begin
                linespaceQ.enq(1);
            end else begin
                linespaceQ.enq(0);
            end
        end else begin
            wordendQ.enq(0);
            token_buff <= zeroExtend(d);
            char_cnt <= 1;
        end
        token_handle <= 0;
    endrule

    rule doHash;
        toHashingQ.deq;
        Bit#(8) d = toHashingQ.first;
        Vector#(2, Bit#(8)) hash = replicate(0);
        hash[0] = hash_a;
        hash[1] = hash_b;

        if (d == 32 || d == 10) begin
            hash_a <= 0;
            hash_b <= 33;
            hashQ.enq(hash);
        end else begin
            hash_a <= cuckoohash_1(hash[0], d);
            hash_b <= cuckoohash_2(hash[1], d);
        end
    endrule

    method Action put(Bit#(64) data);
        inputQ.enq(data);
    endmethod
    method ActionValue#(Tuple2#(Bit#(1), Bit#(128))) get_word;
        wordendQ.deq;
        wordQ.deq;
        return tuple2(wordendQ.first, wordQ.first);
    endmethod
    method ActionValue#(Tuple3#(Bit#(1), Bit#(8), Bit#(8))) get_hash;
        hashQ.deq;
        linespaceQ.deq;
        return tuple3(linespaceQ.first, hashQ.first[0], hashQ.first[1]);
    endmethod
endmodule
endpackage
