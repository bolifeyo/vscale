#include "unistd.h"
#include "getopt.h"

#include "Vvscale_verilator_top.h"
#include "Vvscale_verilator_top_vscale_verilator_top.h"
#include "Vvscale_verilator_top_vscale_sim_top.h"
#include "Vvscale_verilator_top_vscale_dp_hasti_sram.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <algorithm>
#include <array>
#include <iostream>
#include <memory>
#include <string>

#define VCD_PATH_LENGTH 256

int main(int argc, char **argv, char **env) {

  int c;
  int digit_optind = 0;
  char vcdfile[VCD_PATH_LENGTH];

  bool generateVcd = false;
  int retVal = 0;

  while (1) {
    int this_option_optind = optind ? optind : 1;
    int option_index = 0;
    static struct option long_options[] = {
      {"vcdfile", required_argument, 0,  0 },
      {0,         0,                 0,  0 }
    };

    c = getopt_long(argc, argv, "",
                    long_options, &option_index);
    if (c == -1)
      break;
    
    switch (c) {
    case 0:
      if (optarg) {
        generateVcd = true;
        strncpy(vcdfile,optarg,VCD_PATH_LENGTH);
      }
      break;
    default:
      break;
    }
  }

  Verilated::commandArgs(argc, argv);

  auto verilator_top = std::make_unique<Vvscale_verilator_top>();
  std::unique_ptr<VerilatedVcdC> tfp;

  if(generateVcd) {
    tfp = std::make_unique<VerilatedVcdC>();
    Verilated::traceEverOn(true);
    verilator_top->trace(tfp.get(), 99); // requires explicit max levels param
    tfp->open(vcdfile);
  }

  auto &htif_valid = verilator_top->v->DUT->htif_pcr_resp_valid;
  auto &htif_data = verilator_top->v->DUT->htif_pcr_resp_data;
  char* memory = reinterpret_cast<char*>(verilator_top->v->DUT->hasti_mem->mem);

  verilator_top->reset = 0;
  verilator_top->clk   = 0;
  for (vluint64_t half_cycle = 0; !Verilated::gotFinish(); ++half_cycle) {
    // generate reset and clock signals
    verilator_top->reset = (half_cycle < 20) ? 1 : 0;
    verilator_top->clk = !verilator_top->clk;

    // simulate the circuit and dump traces if requested
    verilator_top->eval();
    if(generateVcd)
      tfp->dump(half_cycle*50);

    // skip evaluation of the remaining logic on the falling clock edge
    if ( half_cycle % 2 )
      continue;

    if( htif_valid == 1 && htif_data != 0) {
      if( htif_data & 0x1 ) {
        // program ended
        retVal = htif_data >> 1;
        std::cout << "*** FINISHED *** after "
                  << verilator_top->v->trace_count
                  << " simulation cycles with exit code "
                  << retVal << std::endl;
        break;
      } else if ( htif_data & 0x2 ) {
          // output the second byte to stdout
          std::putc( (htif_data >> 8) & 0xFF, stdout );
      } else {
        std::cerr <<  "*** FAILED *** (tohost = "
                  << htif_data
                  << ") after "
                  << verilator_top->v->trace_count
                  << " simulation cycles" << std::endl;
        break;
      }
    }
  }
  if(generateVcd)
    tfp->close();

  return retVal;
}
