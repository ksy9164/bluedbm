package Detector;
import FIFO::*;
import Vector::*;

import BramCtl::*;
import FIFOLI::*;
import DividedFIFO::*;
import MultiN::*;

import BRAM::*;
import BRAMFIFO::*;

interface GetIfc;
    method ActionValue#(Bit#(128)) get;
endinterface
interface DetectorIfc;
    method Action put_hash(Tuple2#(Bit#(8), Bit#(8)) hash);
    method Action put_word(Tuple2#(Bit#(2), Bit#(128)) word);
    method Action put_table(Bit#(152) word);
    method Action put_sub_table(Bit#(129) word);
    interface Vector#(8, GetIfc) get;
endinterface

(* synthesize *)
module mkDetector(DetectorIfc);
    Vector#(2, BramCtlIfc#(152, 256, 8)) bram_main <- replicateM(mkBramCtl);
    Vector#(2, BramCtlIfc#(129, 256, 8)) bram_sub <- replicateM(mkBramCtl);
    Reg#(Bit#(8)) bram_main_addr <- mkReg(0);
    Reg#(Bit#(8)) bram_sub_addr <- mkReg(1);
    Vector#(2, Reg#(Bit#(2))) sub_flag <- replicateM(mkReg(0));
    Vector#(2, Reg#(Bit#(8))) sub_link <- replicateM(mkReg(0));
    Vector#(8 ,FIFOLI#(Bit#(128), 2)) outputQ <- replicateM(mkFIFOLI);

    FIFO#(Bit#(128)) wordout_saveQ <- mkSizedBRAMFIFO(250);
    FIFO#(Bit#(2)) wordflagSaveQ <- mkSizedBRAMFIFO(250);

    MultiOneToEightIfc#(Bit#(128)) wordoutQ <- mkMultiOnetoEight;
    MultiOneToEightIfc#(Bit#(2)) wordflagoutQ <- mkMultiOnetoEight;

    Vector#(2,MultiOneToEightIfc#(Tuple3#(Bool, Bit#(16), Bit#(8)))) toDetectTemplateQ <- replicateM(mkMultiOnetoEight);

    FIFO#(Bit#(152)) tableinputQ <- mkFIFO;

    Vector#(2, FIFO#(Bit#(128))) mainWordQ <- replicateM(mkFIFO);
    Vector#(2, FIFO#(Bit#(8))) mainLinkQ <- replicateM(mkFIFO);

    FIFO#(Bit#(129)) subtableinputQ <- mkFIFO;
    FIFO#(Tuple2#(Bit#(2), Bit#(128))) wordInputQ <- mkFIFO;
    FIFO#(Tuple2#(Bit#(8), Bit#(8))) hashInputQ <- mkFIFO;

    Vector#(3, FIFO#(Bit#(2))) wordflagQ <- replicateM(mkFIFO);
    Vector#(3, FIFO#(Bit#(128))) wordQ <- replicateM(mkFIFO);

    Vector#(2, FIFO#(Tuple2#(Bool, Bool))) compareQ <- replicateM(mkFIFO);
    Vector#(2, FIFO#(Bit#(16))) svbitsQ <- replicateM(mkSizedFIFO(11));
    Vector#(4, FIFO#(Bit#(8))) hashQ <- replicateM(mkSizedFIFO(11));
    Vector#(2, Reg#(Bit#(2))) compare_handle <- replicateM(mkReg(0));

    Vector#(8, Bit#(256)) answer_table = replicate(0);
    Vector#(2, Vector#(8, Reg#(Bit#(256)))) current_line_hit <- replicateM(replicateM(mkReg(0)));
    Vector#(2,Vector#(8, Reg#(Bit#(1)))) current_status <- replicateM(replicateM(mkReg(1)));

    Vector#(2, Vector#(8, FIFO#(Bit#(256)))) hit_compareQ <- replicateM(replicateM(mkFIFO));
    Vector#(2, Vector#(8, FIFO#(Bit#(1)))) resultQ <- replicateM(replicateM(mkFIFO));
    Vector#(8, FIFO#(Bit#(1))) detectionQ <- replicateM(mkFIFO);

    Vector#(8, Reg#(Bit#(2))) output_handle <- replicateM(mkReg(0));
    Vector#(8, Reg#(Bit#(1))) template_flag <- replicateM(mkReg(0));

    answer_table[0][98] = 1;
    answer_table[0][135] = 1;
    answer_table[0][236] = 1;
    answer_table[0][93] = 1;
    answer_table[0][113] = 1;
    answer_table[0][103] = 1;
    answer_table[0][104] = 1;
    answer_table[0][62] = 1;
    answer_table[0][197] = 1;
    answer_table[0][131] = 1;
    answer_table[0][134] = 1;
    answer_table[0][172] = 1;
    answer_table[0][44] = 1;
    answer_table[0][51] = 1;
    answer_table[0][84] = 1;
    answer_table[0][24] = 1;
    answer_table[0][196] = 1;
    answer_table[0][4] = 1;
    answer_table[0][96] = 1;
    answer_table[0][199] = 1;
    answer_table[0][80] = 1;

    answer_table[1][98] = 1;
    answer_table[1][135] = 1;
    answer_table[1][236] = 1;
    answer_table[1][93] = 1;
    answer_table[1][79] = 1;
    answer_table[1][103] = 1;
    answer_table[1][160] = 1;
    answer_table[1][104] = 1;
    answer_table[1][62] = 1;
    answer_table[1][197] = 1;
    answer_table[1][145] = 1;
    answer_table[1][122] = 1;
    answer_table[1][148] = 1;
    answer_table[1][40] = 1;
    answer_table[1][243] = 1;
    answer_table[1][182] = 1;
    answer_table[1][87] = 1;
    answer_table[1][108] = 1;
    answer_table[1][25] = 1;
    answer_table[1][64] = 1;
    answer_table[1][76] = 1;

    answer_table[2][98] = 1;
    answer_table[2][135] = 1;
    answer_table[2][236] = 1;
    answer_table[2][93] = 1;
    answer_table[2][79] = 1;
    answer_table[2][103] = 1;
    answer_table[2][104] = 1;
    answer_table[2][62] = 1;
    answer_table[2][197] = 1;
    answer_table[2][131] = 1;
    answer_table[2][134] = 1;
    answer_table[2][145] = 1;
    answer_table[2][172] = 1;
    answer_table[2][44] = 1;
    answer_table[2][51] = 1;
    answer_table[2][84] = 1;
    answer_table[2][24] = 1;
    answer_table[2][196] = 1;
    answer_table[2][4] = 1;
    answer_table[2][208] = 1;
    answer_table[2][186] = 1;
    answer_table[2][64] = 1;
    answer_table[2][86] = 1;

    answer_table[3][98] = 1;
    answer_table[3][135] = 1;
    answer_table[3][236] = 1;
    answer_table[3][121] = 1;
    answer_table[3][105] = 1;
    answer_table[3][203] = 1;
    answer_table[3][153] = 1;
    answer_table[3][94] = 1;
    answer_table[3][158] = 1;
    answer_table[3][164] = 1;
    answer_table[3][163] = 1;
    answer_table[3][119] = 1;
    answer_table[3][19] = 1;
    answer_table[3][129] = 1;

    answer_table[4][98] = 1;
    answer_table[4][135] = 1;
    answer_table[4][93] = 1;
    answer_table[4][54] = 1;
    answer_table[4][103] = 1;
    answer_table[4][147] = 1;
    answer_table[4][63] = 1;
    answer_table[4][238] = 1;
    answer_table[4][152] = 1;
    answer_table[4][228] = 1;

    answer_table[5][98] = 1;
    answer_table[5][135] = 1;
    answer_table[5][93] = 1;
    answer_table[5][5] = 1;
    answer_table[5][194] = 1;
    answer_table[5][54] = 1;
    answer_table[5][103] = 1;
    answer_table[5][160] = 1;
    answer_table[5][149] = 1;
    answer_table[5][254] = 1;
    answer_table[5][15] = 1;
    answer_table[5][229] = 1;
    answer_table[5][123] = 1;
    answer_table[5][109] = 1;
    answer_table[5][230] = 1;
    answer_table[5][127] = 1;
    answer_table[5][202] = 1;
    answer_table[5][187] = 1;
    answer_table[5][169] = 1;
    answer_table[5][85] = 1;

    answer_table[6][98] = 1;
    answer_table[6][93] = 1;
    answer_table[6][114] = 1;
    answer_table[6][35] = 1;
    answer_table[6][213] = 1;
    answer_table[6][200] = 1;
    answer_table[6][162] = 1;
    answer_table[6][219] = 1;
    answer_table[6][49] = 1;
    answer_table[6][67] = 1;
    answer_table[6][156] = 1;
    answer_table[6][151] = 1;
    answer_table[6][36] = 1;
    answer_table[6][75] = 1;
    answer_table[6][22] = 1;

    answer_table[7][93] = 1;
    answer_table[7][105] = 1;
    answer_table[7][143] = 1;
    answer_table[7][206] = 1;
    answer_table[7][226] = 1;
    answer_table[7][52] = 1;
    answer_table[7][112] = 1;
    answer_table[7][162] = 1;
    answer_table[7][6] = 1;
    answer_table[7][246] = 1;
    answer_table[7][73] = 1;
    answer_table[7][216] = 1;
    answer_table[7][50] = 1;
    answer_table[7][251] = 1;
    answer_table[7][30] = 1;
    answer_table[7][101] = 1;

    /* Input managing */
    rule tableIn;
        tableinputQ.deq;
        Bit#(152) d = tableinputQ.first;
        bram_main[0].write_req(bram_main_addr ,d);
        bram_main[1].write_req(bram_main_addr ,d);
        bram_main_addr <= bram_main_addr + 1;
    endrule
    rule subTableIn;
        subtableinputQ.deq;
        Bit#(129) d = subtableinputQ.first;
        bram_sub[0].write_req(bram_sub_addr, d);
        bram_sub[1].write_req(bram_sub_addr, d);
        bram_sub_addr <= bram_sub_addr + 1;
    endrule
    rule wordInput;
        wordInputQ.deq;
        Tuple2#(Bit#(2), Bit#(128)) word = wordInputQ.first;
        for (Bit#(8) i = 0; i < 3; i = i + 1) begin
            wordflagQ[i].enq(tpl_1(word));
            wordQ[i].enq(tpl_2(word));
        end
    endrule
    rule hashInput;
        hashInputQ.deq;
        Tuple2#(Bit#(8), Bit#(8)) hash = hashInputQ.first;
        hashQ[0].enq(tpl_1(hash));
        hashQ[1].enq(tpl_2(hash));
        hashQ[2].enq(tpl_1(hash));
        hashQ[3].enq(tpl_2(hash));
    endrule
    rule wordFlagSave;
        wordflagQ[2].deq;
        wordflagSaveQ.enq(wordflagQ[2].first);
    endrule
    rule wordFlagOut;
        wordflagSaveQ.deq;
        wordflagoutQ.enq(wordflagSaveQ.first);
    endrule
    rule wordOutSave;
        wordQ[2].deq;
        wordout_saveQ.enq(wordQ[2].first);
    endrule
    rule wordOut;
        wordout_saveQ.deq;
        wordoutQ.enq(wordout_saveQ.first);
    endrule

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule readReq;
            hashQ[i].deq;
            Bit#(8) hash = hashQ[i].first;
            bram_main[i].read_req(hash); // BRAM read request
        endrule
    end

    // BRAM Control
    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule bramMainCtl;
            Bit#(152) d <- bram_main[i].get;
            Bit#(128) table_word = d[151:24];
            Bit#(8) link = d[7:0];
            Bit#(16) svbits = d[23:8];
            mainWordQ[i].enq(table_word);
            mainLinkQ[i].enq(link);
            svbitsQ[i].enq(svbits);
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule compareValue(compare_handle[i] == 0); // Short word
            wordQ[i].deq;
            wordflagQ[i].deq;
            mainWordQ[i].deq;
            mainLinkQ[i].deq;
            Bit#(128) word = wordQ[i].first;
            Bit#(2) wordflag = wordflagQ[i].first;
            Bit#(128) table_word = mainWordQ[i].first;
            Bit#(8) link = mainLinkQ[i].first;

            case (wordflag)
                0 : begin
                    if (word == table_word) begin // long word
                        sub_link[i] <= link;
                        bram_sub[i].read_req(link);
                        compare_handle[i] <= 1;
                    end else begin
                        compare_handle[i] <= 2;
                    end
                end
                1 : begin
                    if (word == table_word) begin
                        compareQ[i].enq(tuple2(False, True));
                    end else begin
                        compareQ[i].enq(tuple2(False, False));
                    end
                end
                2 : begin
                    if (word == table_word) begin //linespace detection & word matching
                        compareQ[i].enq(tuple2(True, True));
                    end else begin
                        compareQ[i].enq(tuple2(True, False));
                    end
                end
            endcase
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule compareLargeValue(compare_handle[i] == 1); // Long word (more than 128bits)
            wordQ[i].deq;
            wordflagQ[i].deq;
            Bit#(128) word = wordQ[i].first;
            Bit#(129) d <- bram_sub[i].get;
            Bit#(128) table_word = d[128:1];
            Bit#(2) flag = sub_flag[i];
            Bit#(1) end_detect = d[0];
            Bit#(2) wordflag = wordflagQ[i].first;

            case (wordflag)
                0 : begin
                    if (word == table_word) begin
                        if (end_detect == 0) begin
                            compare_handle[i] <= 2;
                        end else begin
                            bram_sub[i].read_req(sub_link[i] + 1);
                            sub_link[i] <= sub_link[i] + 1;
                        end
                    end else begin
                        compare_handle[i] <= 2;
                    end
                end
                1 : begin
                    if (word == table_word && end_detect == 0) begin
                        compareQ[i].enq(tuple2(False,True));
                    end else begin
                        compareQ[i].enq(tuple2(False, False));
                    end
                    compare_handle[i] <= 0;
                end
                2 : begin
                    if (word == table_word && end_detect == 0) begin
                        compareQ[i].enq(tuple2(True, True));
                    end else begin
                        compareQ[i].enq(tuple2(True, False));
                    end
                    compare_handle[i] <= 0;
                end
            endcase
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule wordRemainFlush(compare_handle[i] == 2); // Flush (more than 128bits)
            wordQ[i].deq;
            wordflagQ[i].deq;
            Bit#(2) wordflag = wordflagQ[i].first;
            if (wordflag != 0) begin
                if (wordflag == 1) begin
                    compareQ[i].enq(tuple2(False, False));
                end else begin
                    compareQ[i].enq(tuple2(True, False));
                end
                compare_handle[i] <= 0;
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule flagScatterOneToEight;
            svbitsQ[i].deq;
            compareQ[i].deq;
            hashQ[i + 2].deq;
            Bool linespace = tpl_1(compareQ[i].first);
            Bool check = tpl_2(compareQ[i].first);
            Bit#(16) sv = svbitsQ[i].first;
            Bit#(8) hash = hashQ[i + 2].first; // For matching template
            if (check) begin
                toDetectTemplateQ[i].enq(tuple3(linespace, sv, hash));
            end else begin
                toDetectTemplateQ[i].enq(tuple3(linespace, 0, hash));
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        for (Bit#(8) j = 0; j < 8; j = j + 1) begin
            rule detectTemplate;
                Tuple3#(Bool, Bit#(16), Bit#(8)) d <- toDetectTemplateQ[i].get[j].get;
                Bool linespace = tpl_1(d);
                Bit#(16) flag_t = tpl_2(d);
                Bit#(8) hash = tpl_3(d);

                Bit#(2) flag = 0;
                case (j)
                    0 : flag = flag_t[15:14];
                    1 : flag = flag_t[13:12];
                    2 : flag = flag_t[11:10];
                    3 : flag = flag_t[9:8];
                    4 : flag = flag_t[7:6];
                    5 : flag = flag_t[5:4];
                    6 : flag = flag_t[3:2];
                    7 : flag = flag_t[1:0];
                endcase
                Bit#(256) current_hit = current_line_hit[i][j];
                Bit#(1) status = current_status[i][j];

                if (flag == 3) begin // Valid & Should
                    current_hit[hash] = 1;
                end else if (flag == 2) begin // Valid & Should Not
                    status = 0;
                end

                if (linespace) begin
                    hit_compareQ[i][j].enq(current_hit);
                    resultQ[i][j].enq(status);
                    status = 1; // reset
                    current_hit = 0;
                end
                current_status[i][j] <= status;
                current_line_hit[i][j] <= current_hit;
            endrule
        end
    end
    
    for (Bit#(8) i = 0; i < 8; i = i + 1) begin
        rule templateDetection;
            resultQ[0][i].deq;
            resultQ[1][i].deq;
            hit_compareQ[0][i].deq;
            hit_compareQ[1][i].deq;
            Bit#(256) answer = hit_compareQ[0][i].first | hit_compareQ[1][i].first;
            if(answer == answer_table[i]) begin
                detectionQ[i].enq(resultQ[0][i].first & resultQ[1][i].first);
            end else begin
                detectionQ[i].enq(0);
            end
        endrule
    end

    for (Bit#(8) i =0; i < 8; i = i + 1) begin
        rule outputCtl(output_handle[i] == 0);
            detectionQ[i].deq;
            template_flag[i] <= detectionQ[i].first;
            output_handle[i] <= 1;
            if (template_flag[i] == 1) begin
                outputQ[i].enq(10);
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 8; i = i + 1) begin
        rule outputRule(output_handle[i] == 1); // Normal status
            Bit#(128) word <- wordoutQ.get[i].get;
            Bit#(2) wordflag <- wordflagoutQ.get[i].get;

            if (wordflag == 2) begin
                output_handle[i] <= 0;
            end

            if (template_flag[i] == 1) begin
                outputQ[i].enq(word);
            end
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

    method Action put_hash(Tuple2#(Bit#(8), Bit#(8)) hash);
        hashInputQ.enq(hash);
    endmethod

    method Action put_table(Bit#(152) word);
        tableinputQ.enq(word);
    endmethod

    method Action put_sub_table(Bit#(129) word);
        subtableinputQ.enq(word);
    endmethod

    method Action put_word(Tuple2#(Bit#(2), Bit#(128)) word);
        wordInputQ.enq(word);
    endmethod
endmodule
endpackage
