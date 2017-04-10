#include "Vvscale_sim_top.h"
#include "Vvscale_sim_top_vscale_dp_hasti_sram.h"
#include "Vvscale_sim_top_vscale_sim_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "cli.h"
#include "config.h"
#include "htif.h"
#include "logger.h"

#include <elfio/elfio.hpp>
#include <fmt/format.h>

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdio>
#include <fstream>
#include <memory>
#include <string>

using namespace std;

int hexNibbleToInt( char nibble )
{
  assert( isxdigit( nibble ) );
  if( nibble >= '0' && nibble <= '9' ) return nibble - '0';
  if( nibble >= 'a' && nibble <= 'f' ) return nibble - 'a' + 10;
  return nibble - 'A' + 10;
}

int main( int argc, char **argv )
{
  auto logger = get_logger();

  const Cli cli( argc, argv );
  Verilated::commandArgs( argc, argv );

  // instantiate model and connect helper signals
  auto verilator_top = make_unique<Vvscale_sim_top>();

  auto &clk = verilator_top->clk;
  auto &reset = verilator_top->reset;
  auto &htif_req_valid = verilator_top->htif_pcr_req_valid;
  auto &htif_req_ready = verilator_top->htif_pcr_req_ready;
  auto &htif_req_rw = verilator_top->htif_pcr_req_rw;
  auto &htif_req_addr = verilator_top->htif_pcr_req_addr;
  auto &htif_req_data = verilator_top->htif_pcr_req_data;
  auto &htif_resp_valid = verilator_top->htif_pcr_resp_valid;
  auto &htif_resp_ready = verilator_top->htif_pcr_resp_ready;
  auto &htif_resp_data = verilator_top->htif_pcr_resp_data;

  uint32_t *memoryStart = verilator_top->TOP_VAR_NAME->hasti_mem->mem;
  size_t memorySize = sizeof( verilator_top->TOP_VAR_NAME->hasti_mem->mem );

  // load program into memory
  auto elf = make_unique<ELFIO::elfio>();
  if( elf->load( cli.loadFile ) ) {
    logger->debug( "interpreting program as elf file" );
    char *baseAddress = reinterpret_cast<char *>( memoryStart );

    for( auto &&seg : elf->segments ) {
      if( PT_LOAD == seg->get_type() && seg->get_file_size() ) {
        if( seg->get_physical_address() + seg->get_file_size() > memorySize ) {
          logger->error(
              "ELF segment ({} bytes @ physical address 0x{:x}) file size "
              "exceeds physical memory size ({} bytes). Loading not possible.",
              seg->get_file_size(), seg->get_physical_address(), memorySize );
          return -1;
        }
        else if( seg->get_virtual_address() + seg->get_memory_size()
                 > memorySize ) {
          logger->warn(
              "ELF segment ({} bytes @ virtual address 0x{:x}) memory size "
              "exceeds physical memory size ({} bytes). Program may not work "
              "as expected.",
              seg->get_memory_size(), seg->get_virtual_address(), memorySize );
        }

        logger->info(
            "Loading ELF segment in physical address range [0x{:x},0x{:x}[ "
            "({} bytes).",
            seg->get_physical_address(),
            seg->get_physical_address() + seg->get_file_size(),
            seg->get_file_size() );
        copy( seg->get_data(), seg->get_data() + seg->get_file_size(),
              baseAddress + seg->get_physical_address() );
      }
    }
  }
  else {
    logger->debug( "interpreting program as hex file" );

    ifstream hexfile( cli.loadFile );
    if( hexfile.bad() ) {
      logger->error( "hex file could not be opened" );
      return -1;
    }

    uint32_t *memory = memoryStart;
    uint32_t *memoryEnd = memoryStart + memorySize / sizeof( uint32_t );
    array<char, 32> buffer;

    fill( memoryStart, memoryEnd, 0 );
    for( ; memory + 3 < memoryEnd && hexfile; memory += 4 ) {
      size_t characters = 0;
      buffer.fill( 0 );
      while( characters < buffer.size() && hexfile ) {
        hexfile.get( buffer[characters] );
        if( isxdigit( buffer[characters] ) ) ++characters;
      }
      if( characters != buffer.size() ) break;
      for( size_t idx = 0; idx < buffer.size(); ++idx ) {
        memory[3 - idx / 8] <<= 4;
        memory[3 - idx / 8] += hexNibbleToInt( buffer[idx] );
      }
    }
    logger->info( "{} bytes written to memory from hex file",
                  ( memory - memoryStart ) * 4 );
  }

  // setup trace file generation
  unique_ptr<VerilatedVcdC> tfp;
  bool generateVcd = cli.vcdFile != "";
  if( generateVcd ) {
    tfp = make_unique<VerilatedVcdC>();
    Verilated::traceEverOn( true );
    verilator_top->trace( tfp.get(), 99 ); // requires explicit max levels param
    tfp->open( cli.vcdFile.c_str() );
  }

  // main simulation loop
  reset = true;
  clk = false;
  Htif htif( htif_req_valid, htif_req_ready, htif_req_rw, htif_req_addr,
             htif_req_data, htif_resp_valid, htif_resp_ready, htif_resp_data );
  verilator_top->eval(); // initialize the simulator
  int retVal = 0;
  for( uint64_t cycle = 0; !Verilated::gotFinish(); ++cycle ) {
    if( cli.maxCycles > 0 && cycle >= cli.maxCycles ) {
      fmt::print( stderr, "*** FAILED *** (timeout) after {} cycles\n", cycle );
      retVal = -1;
      break;
    }

    // process the htif interface
    if( htif.eval( cycle ) ) break;

    // generate reset signal
    reset = cycle < 10;

    // simulate the positiv clock edge
    clk = true;
    verilator_top->eval();
    if( generateVcd ) tfp->dump( cycle * 100 );

    // simulate the negative clock edge
    clk = false;
    verilator_top->eval();
    if( generateVcd ) tfp->dump( cycle * 100 + 50 );
  }
  if( generateVcd ) tfp->close();

  return retVal ? retVal : htif.get_return_value();
}
