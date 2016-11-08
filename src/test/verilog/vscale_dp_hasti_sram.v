`include "vscale_hasti_constants.vh"

module vscale_dp_hasti_sram(
                            input                          hclk,
                            input                          hresetn,
                            input [`HASTI_ADDR_WIDTH-1:0]  p0_haddr,
                            input                          p0_hwrite,
                            input [`HASTI_SIZE_WIDTH-1:0]  p0_hsize,
                            input [`HASTI_BURST_WIDTH-1:0] p0_hburst,
                            input                          p0_hmastlock,
                            input [`HASTI_PROT_WIDTH-1:0]  p0_hprot,
                            input [`HASTI_TRANS_WIDTH-1:0] p0_htrans,
                            input [`HASTI_BUS_WIDTH-1:0]   p0_hwdata,
                            output [`HASTI_BUS_WIDTH-1:0]  p0_hrdata,
                            output                         p0_hready,
                            output                         p0_hresp,
                            input [`HASTI_ADDR_WIDTH-1:0]  p1_haddr,
                            input                          p1_hwrite,
                            input [`HASTI_SIZE_WIDTH-1:0]  p1_hsize,
                            input [`HASTI_BURST_WIDTH-1:0] p1_hburst,
                            input                          p1_hmastlock,
                            input [`HASTI_PROT_WIDTH-1:0]  p1_hprot,
                            input [`HASTI_TRANS_WIDTH-1:0] p1_htrans,
                            input [`HASTI_BUS_WIDTH-1:0]   p1_hwdata,
                            output [`HASTI_BUS_WIDTH-1:0]  p1_hrdata,
                            output                         p1_hready,
                            output                         p1_hresp
                            );

   parameter nwords = 65536;


   reg [`HASTI_BUS_WIDTH-1:0]                              mem [nwords-1:0] /*verilator public*/;

   // p0
   reg [`HASTI_ADDR_WIDTH-1:0]                             p0_reg_addr;
   reg [`HASTI_SIZE_WIDTH-1:0]                             p0_reg_size;
   reg                                                     p0_reg_write;

   wire [`HASTI_ADDR_WIDTH-1:0]                            p0_addr_word = p0_reg_addr >> 2;

   wire [`HASTI_BUS_NBYTES-1:0]                            p0_wmask_lut = (p0_reg_size == 0) ? `HASTI_BUS_NBYTES'h1 : (p0_reg_size == 1) ? `HASTI_BUS_NBYTES'h3 : `HASTI_BUS_NBYTES'hf;
   wire [`HASTI_BUS_NBYTES-1:0]                            p0_wmask_shift = p0_wmask_lut << p0_reg_addr[1:0];
   wire [`HASTI_BUS_WIDTH-1:0]                             p0_wmask = {{8{p0_wmask_shift[3]}},{8{p0_wmask_shift[2]}},{8{p0_wmask_shift[1]}},{8{p0_wmask_shift[0]}}};

   always @(posedge hclk) begin
      p0_reg_addr <= p0_haddr;
      p0_reg_size <= p0_hsize;
      p0_reg_write <= p0_hwrite;

      if (p0_reg_write) begin
        mem[p0_addr_word] <= (mem[p0_addr_word] & ~p0_wmask) | (p0_hwdata & p0_wmask);
      end
   end

   assign p0_hrdata = mem[p0_addr_word];
   assign p0_hready = 1'b1;
   assign p0_hresp = `HASTI_RESP_OKAY;


   // p1
   reg [`HASTI_ADDR_WIDTH-1:0]  p1_reg_addr;
   wire [`HASTI_ADDR_WIDTH-1:0] p1_raddr = p1_reg_addr >> 2;

   always @(posedge hclk) begin
      p1_reg_addr <= p1_haddr;
   end

   assign p1_hrdata = mem[p1_raddr];
   assign p1_hready = 1'b1;
   assign p1_hresp = `HASTI_RESP_OKAY;

endmodule // vscale_dp_hasti_sram

