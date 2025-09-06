`timescale 1ns / 1ps

module async_fifo(
input rd_clk,
input wr_clk,
input wr_rst,
input rd_rst,
input rd_en,
input wr_en,
input [7:0] fifo_in,
output reg [7:0] fifo_out,
output fifo_full,
output fifo_empty
    );
    
    reg [7:0] fifo[0:63];
    reg [7:0] w_ptr;
    reg [7:0] rd_ptr;
    wire [7:0] w_ptr_g_sync, rd_ptr_sync, rd_ptr_g_sync, w_ptr_sync, w_ptr_g, rd_ptr_g;
    
    b2g inst1 (w_ptr,w_ptr_g);
    two_cell_sync inst2 (.src_clk(wr_clk), .dest_clk(rd_clk), .src_in(w_ptr_g), .dest_out(w_ptr_g_sync));
    g2b inst3 (w_ptr_g_sync,w_ptr_sync);
    
    b2g inst4 (rd_ptr,rd_ptr_g);
    two_cell_sync inst5 (.src_clk(rd_clk), .dest_clk(wr_clk), .src_in(rd_ptr_g), .dest_out(rd_ptr_g_sync));
    g2b inst6 (rd_ptr_g_sync,rd_ptr_sync);
    
    assign fifo_full = ((w_ptr[7:6] != rd_ptr_sync[7:6])&&(w_ptr[5:0] == rd_ptr_sync[5:0]));
    assign fifo_empty = (w_ptr_sync == rd_ptr);    
    
    always@(posedge rd_clk) begin //read operation
        if(rd_rst) begin
            fifo_out <= 8'b0;
        end
        else if(~fifo_empty && rd_en) begin
            fifo_out <= fifo[rd_ptr[5:0]];
        end
        else begin
            fifo_out <= fifo_out;
        end
    end
    
    always@(posedge wr_clk) begin //write operation
        if(~fifo_full && wr_en) begin
            fifo[w_ptr[5:0]] <= fifo_in;
        end
        else begin
            fifo[w_ptr[5:0]] <= fifo[w_ptr[5:0]];
        end
    end
    
    always@(posedge rd_clk or posedge rd_rst) begin //read pointer
        if(rd_rst) begin
            rd_ptr <= 6'b0;
        end
        else if(~fifo_empty && rd_en) begin
            rd_ptr <= rd_ptr +1;
        end
        else begin
            rd_ptr <= rd_ptr;
        end
    end
    
    always@(posedge wr_clk or posedge wr_rst) begin //write pointer
        if(wr_rst) begin
            w_ptr <= 6'b0;
        end
        else if(~fifo_full && wr_en) begin
            w_ptr <= w_ptr +1;
        end
        else begin
            w_ptr <= w_ptr;
        end
    end
endmodule
