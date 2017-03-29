#include "htif.h"

#include <cstdlib>
#include <fmt/format.h>

Htif::Htif( Htif::wire_t &req_valid,
            Htif::wire_t &req_ready,
            Htif::wire_t &req_rw,
            Htif::addr_t &req_addr,
            Htif::data_t &req_data,
            Htif::wire_t &resp_valid,
            Htif::wire_t &resp_ready,
            Htif::data_t &resp_data )
  : req_valid_( req_valid ),
    req_ready_( req_ready ),
    req_rw_( req_rw ),
    req_addr_( req_addr ),
    req_data_( req_data ),
    resp_valid_( resp_valid ),
    resp_ready_( resp_ready ),
    resp_data_( resp_data )
{
  // always read the TO_HOST CSR register
  req_valid = true;
  req_rw = CsrRW::READ;
  req_addr = CsrAddr::TO_HOST;
  req_data = 0;

  resp_ready = true;
}

bool Htif::eval( uint64_t cycle )
{
  if( resp_valid_ == false ) return false;

  if( resp_data_ & 0x1 ) {
    // program ended
    returnValue_ = resp_data_ >> 1;
    fmt::print( "*** FINISHED *** after {} cycles with exit code {}\n", cycle,
                returnValue_ );
    return true;
  }

  if( resp_data_ & 0x2 ) {
    // output the second byte to stdout
    std::putc( ( resp_data_ >> 8 ) & 0xFF, stdout );
    return false;
  }

  if( resp_data_ != 0 ) {
    fmt::print( stderr, "*** FAILED *** (tohost = {}) after {} cycles\n",
                resp_data_, cycle );
    returnValue_ = -1;
    return true;
  }
  return false;
}
