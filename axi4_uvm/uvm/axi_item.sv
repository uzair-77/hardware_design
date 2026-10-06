// One AXI transaction (a full burst, read or write)
class axi_item extends uvm_sequence_item;
    localparam int MEM_BYTES = 16384;
    localparam bit [1:0] FIXED = 2'b00, INCR = 2'b01, WRAP = 2'b10;

    rand bit          is_write;
    rand bit [3:0]    id;
    rand bit [15:0]   addr;
    rand bit [7:0]    len;        // beats - 1
    rand bit [2:0]    size;       // bytes per beat = 1 << size
    rand bit [1:0]    burst;
    rand bit [31:0]   data[];     // write data (driven) or read data (observed)
    rand bit [3:0]    strb[];     // write strobes
    rand bit          oor;        // address outside the 16 KB memory
    rand int unsigned gap;        // idle cycles before the transaction

    bit [1:0]         resp[];     // read: one per beat, write: resp[0] = BRESP

    `uvm_object_utils(axi_item)

    function new(string name = "axi_item");
        super.new(name);
    endfunction

    constraint c_size  { size <= 2; }                       // 32-bit bus
    constraint c_burst { burst inside {FIXED, INCR, WRAP}; }
    constraint c_len {
        if (burst == WRAP) len inside {1, 3, 7, 15};
        else               len inside {[0:15]};
    }
    constraint c_align { (addr & ((1 << size) - 1)) == 0; }
    constraint c_4k    { burst == INCR -> (int'(addr[11:0]) + ((int'(len) + 1) << size)) <= 4096; }
    constraint c_range { oor -> addr >= MEM_BYTES; !oor -> addr < MEM_BYTES; }
    constraint c_oor   { oor dist {0 := 9, 1 := 1}; }
    constraint c_sizes { data.size() == len + 1; strb.size() == len + 1; }
    constraint c_strb  { foreach (strb[i]) strb[i] dist {4'hF := 50, [4'h0:4'hE] :/ 50}; }
    constraint c_gap   { gap dist {0 := 60, [1:5] :/ 30, [6:20] :/ 10}; }

    // address of beat i (same formula as the AXI spec)
    function bit [15:0] beat_addr(int i);
        bit [15:0] a     = addr;
        bit [15:0] nbyte = 16'd1 << size;
        bit [15:0] total = 16'(len + 1) << size;
        repeat (i) begin
            case (burst)
                INCR:    a = a + nbyte;
                WRAP:    a = (a & ~(total - 1)) | ((a + nbyte) & (total - 1));
                default: ;
            endcase
        end
        return a;
    endfunction

    // byte lanes a beat is allowed to use
    function bit [3:0] lane_mask(int i);
        bit [15:0] a = beat_addr(i);
        bit [3:0]  m;
        case (size)
            0:       m = 4'b0001;
            1:       m = 4'b0011;
            default: m = 4'b1111;
        endcase
        return m << a[1:0];
    endfunction

    // narrow beats may only strobe their own lanes
    function void post_randomize();
        foreach (strb[i]) strb[i] &= lane_mask(i);
    endfunction

    function string convert2string();
        return $sformatf("%s id=%0d addr=0x%04h len=%0d size=%0d burst=%0d oor=%0b",
                         is_write ? "WR" : "RD", id, addr, len, size, burst, oor);
    endfunction
endclass
