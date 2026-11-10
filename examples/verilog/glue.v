`timescale 1ns/1ps
// Illustrative behavior only; board pins and timing remain to be supplied.
module glue (
    input wire clk,
    input wire reset,
    input wire bank_we,
    input wire [1:0] data,
    input wire [15:0] addr,
    input wire mreq_n,
    input wire rd_n,
    input wire wr_n,
    input wire ext,
    output reg [1:0] bank,
    output wire rom_n,
    output wire ram_n,
    output wire memrd_n,
    output wire memwr_n,
    output wire flag
);
    always @(posedge clk) begin
        if (reset)
            bank <= 2'b00;
        else if (bank_we)
            bank <= data;
    end

    assign rom_n = mreq_n | (addr[15:13] != 3'b000);
    assign ram_n = mreq_n | ~addr[15];
    assign memrd_n = mreq_n | rd_n;
    assign memwr_n = mreq_n | wr_n;
    assign flag = ext & bank[0] & ~bank[1];
endmodule
