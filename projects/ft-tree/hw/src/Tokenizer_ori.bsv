package Tokenizer;

import FIFO::*;
import Vector::*;
import Serializer::*;
import BRAM::*;
import BRAMFIFO::*;
import FIFOLI::*;

interface TokenizerIfc;
    method Action put(Bit#(128) data);
    method ActionValue#(Tuple2#(Bit#(2), Bit#(128))) get_word;
    method ActionValue#(Tuple2#(Bit#(8), Bit#(8))) get_hash;
endinterface

function Bit#(8) cuckoohash (Bit#(8) idx, Bit#(8) temp);
    return (idx ^ temp) * 3;
endfunction

(* synthesize *)
module mkTokenizer (TokenizerIfc);
    FIFO#(Bit#(128)) inputQ <- mkSizedFIFO(100);
    FIFOLI#(Vector#(2, Bit#(8)), 5) toTokenizingQ <- mkFIFOLI;
    FIFOLI#(Vector#(2, Bit#(8)), 5) toHashingQ <- mkFIFOLI;
    FIFOLI#(Vector#(2, Bit#(8)), 5) hashQ <- mkFIFOLI;
    FIFO#(Bit#(128)) wordQ <- mkFIFO;
    FIFO#(Bit#(1)) linespaceQ <- mkFIFO;
    FIFO#(Bit#(2)) wordflagQ <- mkFIFO;

    Reg#(Bit#(128)) token_buff <- mkReg(0);
    Reg#(Bit#(4)) char_cnt <- mkReg(0);
    Reg#(Bit#(8)) hash_a <- mkReg(0);
    Reg#(Bit#(8)) hash_b <- mkReg(23);

    Reg#(Bit#(1)) token_handle <- mkReg(0);

    SerializerIfc#(128, 8) serial_inputQ <- mkSerializer; 

    rule serial16Bits;
        inputQ.deq;
        Bit#(128) d = inputQ.first;
        serial_inputQ.put(d);
    endrule

    rule get16Bits;
        Bit#(16) serialized <- serial_inputQ.get;
        Vector#(2, Bit#(8)) d = replicate(0);

        d[0] = serialized[7:0];
        d[1] = serialized[15:8];

        toTokenizingQ.enq(d);
        toHashingQ.enq(d);
    endrule

    rule doTokenizing(token_handle == 0);
        toTokenizingQ.deq;
        Vector#(2, Bit#(8)) d = toTokenizingQ.first;
        Bit#(4) cnt = char_cnt;
        Bit#(128) t_buff = token_buff;

        if (d[0] == 32 || d[0] == 10) begin // If it has space or lineSpace
            token_buff <= zeroExtend(d[1]);
            char_cnt <= 1;
            if (d[0] == 10) begin
                wordflagQ.enq(2);
            end else begin
                wordflagQ.enq(1);
            end

            wordQ.enq(t_buff);

        end else if (d[1] == 32|| d[1] == 10) begin
            t_buff = (t_buff << 8) | zeroExtend(d[0]);
            token_buff <= 0;
            char_cnt <= 0;
            if (d[1] == 10) begin
                wordflagQ.enq(2);
            end else begin
                wordflagQ.enq(1);
            end

            wordQ.enq(t_buff);

        end else if (cnt == 14) begin // maximum word length is 16
            t_buff = (t_buff << 16) | (zeroExtend(d[0]) << 8) | zeroExtend(d[1]);
            token_buff <= 0;
            char_cnt <= 0;
            wordQ.enq(t_buff);
            token_handle <= 1;

        end else if (cnt == 15) begin
            t_buff = (t_buff << 8) | zeroExtend(d[0]);
            token_buff <= zeroExtend(d[1]);
            char_cnt <= 1;
            wordQ.enq(t_buff);
            wordflagQ.enq(0);

        end else begin              // append to Buffer
            t_buff = (t_buff << 16) | (zeroExtend(d[0]) << 8) | zeroExtend(d[1]);
            token_buff <= t_buff;
            char_cnt <= cnt + 2;

        end
    endrule

    rule bytes16Exception(token_handle == 1);
        Vector#(2, Bit#(8)) d = toTokenizingQ.first;
        if (d[0] == 32 || d[0] == 10) begin
            toTokenizingQ.deq;
            token_buff <= zeroExtend(d[1]);
            char_cnt <= 1;
            if (d[0] == 10) begin
                wordflagQ.enq(2);
            end else begin
                wordflagQ.enq(1);
            end
        end else begin
            wordflagQ.enq(0);
        end
        token_handle <= 0;
    endrule

    rule doHash;
        toHashingQ.deq;
        Vector#(2, Bit#(8)) d = toHashingQ.first;
        Vector#(2, Bit#(8)) hash = replicate(0);
        Bit#(8) rd = 0;
        hash[0] = hash_a;
        hash[1] = hash_b;

        if (d[0] == 32 || d[0] == 10) begin // If d[0] = ' ' or '\n'
            hash_a <= cuckoohash(0, d[1]);

            hash_b <= cuckoohash(23, d[1]);

            hashQ.enq(hash);
        end else if (d[1] == 32|| d[1] == 10) begin // If d[0] = ' ' or '\n'
            hash[0] = cuckoohash(hash[0], d[0]);

            hash[1] = cuckoohash(hash[1], d[0]);

            hash_a <= 0;
            hash_b <= 23;

            hashQ.enq(hash);
        end else begin
            hash[0] = cuckoohash(hash[0], d[0]);
            hash[0] = cuckoohash(hash[0], d[1]);

            hash[1] = cuckoohash(hash[1], d[0]);
            hash[1] = cuckoohash(hash[1], d[1]);

            hash_a <= hash[0];
            hash_b <= hash[1];
        end
    endrule

    method Action put(Bit#(128) data);
        inputQ.enq(data);
    endmethod
    method ActionValue#(Tuple2#(Bit#(2), Bit#(128))) get_word;
        wordflagQ.deq;
        wordQ.deq;
        return tuple2(wordflagQ.first, wordQ.first);
    endmethod
    method ActionValue#(Tuple2#(Bit#(8), Bit#(8))) get_hash;
        hashQ.deq;
        return tuple2(hashQ.first[0], hashQ.first[1]);
    endmethod

endmodule
endpackage
