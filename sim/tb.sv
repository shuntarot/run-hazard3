// Runs asm/smoke.elf on hazard3_top. tcm behaves like the harness's FPGA
// memory: one cycle, byte addressed, 64 KB from BASE. dmem is an AXI4
// memory from DRAM_BASE whose channels stall for a varying number of cycles,
// the way DRAM behind a clock crossing does. Veryl's own simulator cannot run
// Hazard3 (it is Verilog), so this uses Verilator.
module tb;
    logic clk = 0;
    always #5 clk = ~clk;

    logic [31:0] ta, trd, twd;
    logic        tre, twe;
    logic [3:0]  tws;
    // dut_base in Harness.toml
    localparam logic [31:0] BASE      = 32'h8000_0000;
    localparam logic [31:0] DRAM_BASE = 32'h8001_0000;
    logic [31:0] tcm  [0:16383];
    logic [31:0] dmem [0:16383];
    logic [31:0] want [0:12];

    logic [31:0] cycle = 0;
    logic        rst_n;
    integer      stalls = 0, oor = 0, bad = 0, i;
    logic [31:0] count;

    assign rst_n = cycle >= 5;

    __std___axi4_if____std___axi4_pkg__32__4__1__1__1__1__1__1 axi ();

    run_hazard3_hazard3_top dut (
        .i_clk(clk), .i_rst(rst_n), .i_dm_rst(rst_n),
        // The Debug Module is left idle.
        .i_dmi_psel(1'b0), .i_dmi_penable(1'b0), .i_dmi_pwrite(1'b0),
        .i_dmi_paddr(9'd0), .i_dmi_pwdata(32'd0), .o_dmi_prdata(), .o_dmi_pready(),
        .o_tcm_addr(ta), .o_tcm_re(tre), .o_tcm_we(twe), .o_tcm_wstrb(tws),
        .o_tcm_wdata(twd), .i_tcm_rdata(trd),
        .dmem(axi.master)
    );

    // Pseudo-random ready and response delays, so AW and W are taken in
    // either order and R / B come back late.
    logic [15:0] lfsr = 16'hace1;
    always @(posedge clk) lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

    logic        aw_got, w_got, ar_got;
    logic [31:0] aw_addr, ar_addr;  // offsets from DRAM_BASE, as the harness makes them
    logic [31:0] w_data;
    logic [3:0]  w_strb;
    logic [2:0]  r_wait, b_wait;

    assign axi.awready = rst_n && !aw_got && lfsr[0];
    assign axi.wready  = rst_n && !w_got && lfsr[1];
    assign axi.arready = rst_n && !ar_got && lfsr[2];
    assign axi.bvalid  = aw_got && w_got && b_wait == 0;
    assign axi.bresp   = __std_axi4_config::resp_variants_OKAY;
    assign axi.bid     = 0;
    assign axi.buser   = 0;
    assign axi.rvalid  = ar_got && r_wait == 0;
    assign axi.rdata   = ar_addr < 65536 ? dmem[ar_addr[15:2]] : 0;
    assign axi.rresp   = __std_axi4_config::resp_variants_OKAY;
    assign axi.rid     = 0;
    assign axi.rlast   = 1;
    assign axi.ruser   = 0;

    // The bridge sends single whole-word beats only.
    function automatic logic odd(logic [2:0] size, logic [7:0] len, logic [1:0] low);
        return size != 3'd2 || len != 0 || low != 0;
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            aw_got <= 0;
            w_got  <= 0;
            ar_got <= 0;
            r_wait <= 0;
            b_wait <= 0;
        end else begin
            if (axi.awvalid && axi.awready) begin
                aw_got  <= 1;
                aw_addr <= axi.awaddr - DRAM_BASE;
                b_wait  <= lfsr[5:3];
                if (odd(axi.awsize, axi.awlen, axi.awaddr[1:0])) bad = bad + 1;
            end
            if (axi.wvalid && axi.wready) begin
                w_got  <= 1;
                w_data <= axi.wdata;
                w_strb <= axi.wstrb;
                if (!axi.wlast) bad = bad + 1;
            end
            if (axi.arvalid && axi.arready) begin
                ar_got  <= 1;
                ar_addr <= axi.araddr - DRAM_BASE;
                r_wait  <= lfsr[8:6];
                if (odd(axi.arsize, axi.arlen, axi.araddr[1:0])) bad = bad + 1;
            end
            if (aw_got && w_got && b_wait != 0) b_wait <= b_wait - 1;
            if (ar_got && r_wait != 0) r_wait <= r_wait - 1;

            if (axi.bvalid && axi.bready) begin
                aw_got <= 0;
                w_got  <= 0;
                if (aw_addr < 65536) begin
                    if (w_strb[0]) dmem[aw_addr[15:2]][7:0]   <= w_data[7:0];
                    if (w_strb[1]) dmem[aw_addr[15:2]][15:8]  <= w_data[15:8];
                    if (w_strb[2]) dmem[aw_addr[15:2]][23:16] <= w_data[23:16];
                    if (w_strb[3]) dmem[aw_addr[15:2]][31:24] <= w_data[31:24];
                end else begin
                    oor <= oor + 1;
                end
            end
            if (axi.rvalid && axi.rready) begin
                ar_got <= 0;
                if (ar_addr >= 65536) oor <= oor + 1;
            end
            // One transfer at a time: a read and a write never overlap.
            if ((aw_got || w_got) && ar_got) bad = bad + 1;
        end
    end

    initial begin
        for (i = 0; i < 16384; i = i + 1) begin
            tcm[i]  = 0;
            dmem[i] = 0;
        end
        $readmemh("smoke.hex", tcm);

        // What asm/smoke.S writes at 0x8000_1000, word by word. +0x2c is
        // the counter.
        want[0]  = 32'h21534e48; want[1]  = 32'h40801105; want[2] = 32'h00000000;
        want[3]  = 32'hc0ffee42; want[4]  = 32'h000f45f6; want[5] = 32'h44332211;
        want[6]  = 32'h66665555; want[7]  = 32'h0000002a; want[8] = 32'h00000025;
        want[9]  = 32'h12345678; want[10] = 32'h12345678; want[11] = 32'h0;
        want[12] = 32'hfeedface;
    end

    always @(posedge clk) begin
        cycle <= cycle + 1;
        if (rst_n && !dut.hready) stalls <= stalls + 1;
        if (rst_n && (tre || twe) && ta - BASE >= 65536) oor <= oor + 1;
        if (tre) trd <= tcm[ta[15:2]];
        if (twe) begin
            if (tws[0]) tcm[ta[15:2]][7:0]   <= twd[7:0];
            if (tws[1]) tcm[ta[15:2]][15:8]  <= twd[15:8];
            if (tws[2]) tcm[ta[15:2]][23:16] <= twd[23:16];
            if (tws[3]) tcm[ta[15:2]][31:24] <= twd[31:24];
        end
    end

    always @(posedge clk) begin
        if (cycle == 3000) begin
            for (i = 0; i < 13; i = i + 1) begin
                if (i == 11) continue;
                if (tcm[1024 + i] == want[i]) begin
                    $display("+%h %h", 8'(i * 4), tcm[1024 + i]);
                end else begin
                    $display("+%h %h  <- want %h", 8'(i * 4), tcm[1024 + i], want[i]);
                    bad = bad + 1;
                end
            end
            if (dmem[0] != 32'hfeedface) begin
                $display("dmem+0 %h  <- want feedface", dmem[0]);
                bad = bad + 1;
            end
            count = tcm[1024 + 11];
        end
        if (cycle == 3300) begin
            $display("+2c %h -> %h", count, tcm[1024 + 11]);
            if (tcm[1024 + 11] == count) bad = bad + 1;
            $display("%0d cycles with hready low", stalls);
            if (oor != 0) begin
                $display("%0d accesses out of range", oor);
                bad = bad + 1;
            end
            if (bad == 0) $display("PASS");
            else $display("FAIL");
            $finish;
        end
    end
endmodule
