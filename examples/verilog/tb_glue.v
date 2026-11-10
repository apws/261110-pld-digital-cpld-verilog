`timescale 1ns/1ps
module tb_glue;
    reg clk = 0;
    reg reset = 0, bank_we = 0, ext = 0;
    reg [1:0] data = 0;
    reg [15:0] addr = 0;
    reg mreq_n = 1, rd_n = 1, wr_n = 1;
    wire [1:0] bank;
    wire rom_n, ram_n, memrd_n, memwr_n, flag;
    integer i, q, r, w, d, e;
    integer checks = 0;
    reg [1:0] expected;
    glue dut(.clk(clk), .reset(reset), .bank_we(bank_we), .data(data),
        .addr(addr), .mreq_n(mreq_n), .rd_n(rd_n), .wr_n(wr_n),
        .ext(ext), .bank(bank), .rom_n(rom_n), .ram_n(ram_n),
        .memrd_n(memrd_n), .memwr_n(memwr_n), .flag(flag));

    task tick;
        begin
            #2; clk = 1; #2; clk = 0; #2;
        end
    endtask

    initial begin
        for (i = 0; i < 64; i = i + 1) begin
            addr = ((i >> 3) & 7) << 13;
            mreq_n = (i >> 2) & 1;
            rd_n = (i >> 1) & 1;
            wr_n = i & 1;
            #1;
            if (rom_n !== !(!mreq_n && addr < 16'h2000) ||
                ram_n !== !(!mreq_n && addr >= 16'h8000) ||
                memrd_n !== !(!mreq_n && !rd_n) ||
                memwr_n !== !(!mreq_n && !wr_n))
                $fatal(1, "decoder mismatch at %0d", i);
            checks = checks + 1;
        end
        // Enumerate each current state, reset/write/data combination,
        // both EXT values, and check stability before the active edge.
        for (q = 0; q < 4; q = q + 1)
        for (r = 0; r < 2; r = r + 1)
        for (w = 0; w < 2; w = w + 1)
        for (d = 0; d < 4; d = d + 1)
        for (e = 0; e < 2; e = e + 1) begin
            reset = 0; bank_we = 1; data = q; tick;
            reset = r; bank_we = w; data = d; ext = e;
            #1;
            if (bank !== q[1:0] || flag !== (e && q == 1))
                $fatal(1, "state changed without clock or flag mismatch");
            expected = r ? 0 : (w ? d : q);
            tick;
            if (bank !== expected || flag !== (e && expected == 1))
                $fatal(1, "bank transition mismatch");
            checks = checks + 1;
        end
        $display("PASS: %0d decoder/state cases", checks);
        $finish;
    end
endmodule
