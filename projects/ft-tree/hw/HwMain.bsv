import FIFO::*;
import FIFOF::*;
import Clocks::*;
import Vector::*;
import Connectable::*;

import Serializer::*;

import BRAM::*;
import BRAMFIFO::*;
import FIFOLI::*;

import PcieCtrl::*;
import DRAMController::*;

import FlashManagerCommon::*;
import ControllerTypes::*;
//import FlashCtrlVirtex1::*;
import DualFlashManagerOrdered::*;
import SinglePipe::*;
import Merger::*;

interface HwMainIfc;
endinterface

typedef 64 UserTagCnt;

module mkHwMain#(PcieUserIfc pcie, DRAMUserIfc dram, Vector#(2,FlashCtrlUser) flashes) 
	(HwMainIfc);

	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	Clock pcieclk = pcie.user_clk;
	Reset pcierst = pcie.user_rst;

    Vector#(2, SinglePipeIfc) pipe <- replicateM(mkSinglePipe);
	DualFlashManagerOrderedIfc flashuser <- mkDualFlashManagerOrdered(flashes); 

	Vector#(2, SerializerIfc#(256,2)) serial_usr <- replicateM(mkSerializer);

	Reg#(Bit#(1)) handle <- mkReg(0);

	Reg#(Bit#(32)) outputCnt <- mkReg(0);
    DeSerializerIfc#(128, 2) out_deserial <- mkDeSerializer;

	rule readFlashData;
		Bit#(256) word <- flashuser.readWord;
		serial_usr[handle].put(word);
		handle <= handle + 1;
	endrule

	for (Bit#(3) i = 0; i < 2; i = i +1) begin
	    rule putToPipe;
	        let d <- serial_usr[i].get;
	        pipe[i].putData(d);
	    endrule
	end

    Vector#(8, MergerIfc) outmerger_1 <- replicateM(mkMerger);
    for (Bit#(4) i = 0; i < 8; i = i + 1) begin
        rule merge_step1_1;
            Bit#(128) d <- pipe[0].get[i].get;
            if (d != 0) begin
                outmerger_1[i].enqOne(d);
            end
        endrule
        rule merge_step1_2;
            Bit#(128) d <- pipe[1].get[i].get;
            if (d != 0) begin
                outmerger_1[i].enqTwo(d);
            end
        endrule
    end

    Vector#(4, MergerIfc) merger8to4 <- replicateM(mkMerger);
    Vector#(2, MergerIfc) merger4to2 <- replicateM(mkMerger);
    MergerIfc merger2to1 <- mkMerger;

    for (Bit#(8) i = 0; i < 8; i = i + 1) begin
        rule mergeStep1;
            Bit#(8) id = i / 2;
            outmerger_1[i].deq;
            if (i%2 == 0) begin
                merger8to4[id].enqOne(outmerger_1[i].first);
            end else begin
                merger8to4[id].enqTwo(outmerger_1[i].first);
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 4; i = i + 1) begin
        rule mergeStep2;
            Bit#(8) id = i / 2;
            merger8to4[i].deq;
            if (i%2 == 0) begin
                merger4to2[id].enqOne(merger8to4[i].first);
            end else begin
                merger4to2[id].enqTwo(merger8to4[i].first);
            end
        endrule
    end

    for (Bit#(8) i = 0; i < 2; i = i + 1) begin
        rule mergeStep3;
            Bit#(8) id = i / 2;
            merger4to2[i].deq;
            if (i%2 == 0) begin
                merger2to1.enqOne(merger4to2[i].first);
            end else begin
                merger2to1.enqTwo(merger4to2[i].first);
            end
        endrule
    end

    rule getOutput;
        merger2to1.deq;
        out_deserial.put(merger2to1.first);
    endrule

    rule writeFlashUser;
        let d <- out_deserial.get;
        outputCnt <= outputCnt + 1;
        flashuser.writeWord(d);
    endrule

	SyncFIFOIfc#(IOWrite) pcieWriteQ <- mkSyncFIFOToCC(2,pcieclk,pcierst);
	SyncFIFOIfc#(IOReadReq) pcieReadQ <- mkSyncFIFOToCC(2,pcieclk,pcierst);
    SyncFIFOIfc#(Tuple2#(IOReadReq, Bit#(32))) pcieRespQ <- mkSyncFIFOFromCC(2,pcieclk);	

	rule getWriteReq;
		let w <- pcie.dataReceive;
		pcieWriteQ.enq(w);
	endrule
	
	rule getReadReq;
		let r <- pcie.dataReq;
		pcieReadQ.enq(r);
	endrule

	rule putOutputCntToPcie;
	    pcieReadQ.deq;
	    pcieRespQ.enq(tuple2(pcieReadQ.first, outputCnt));
	endrule

	rule returnReadResp;
		let r_ = pcieRespQ.first;
		pcieRespQ.deq;

		pcie.dataSend(tpl_1(r_), tpl_2(r_));
	endrule

	rule getCmd;
		pcieWriteQ.deq;
		let w = pcieWriteQ.first;

		let a = w.addr;
		let d = w.data;
		let off = (a>>2);

		if ( (off>>11) > 0 ) begin // command
			Bit#(2) cmd = truncate(off);

			if ( cmd == 0 ) flashuser.readPage(d);
			else if ( cmd == 1 ) flashuser.writePage(d);
			else flashuser.eraseBlock(d);
		end 	
	endrule
endmodule
