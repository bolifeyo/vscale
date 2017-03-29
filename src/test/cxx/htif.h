#ifndef VSCALE_VERILATOR_HTIF_H
#define VSCALE_VERILATOR_HTIF_H

#include <cstdint>

class Htif {
  using wire_t = uint8_t;
  using addr_t = uint16_t;
  using data_t = uint64_t;

  wire_t &req_valid_;
  wire_t &req_ready_;
  wire_t &req_rw_;
  addr_t &req_addr_;
  data_t &req_data_;
  wire_t &resp_valid_;
  wire_t &resp_ready_;
  data_t &resp_data_;

  int returnValue_ = 0;

  enum CsrRW : wire_t { READ = 0, WRITE = 1 };

  enum CsrAddr : addr_t { TO_HOST = 0x780, FROM_HOST = 0x781 };

public:
  Htif( wire_t &req_valid,
        wire_t &req_ready,
        wire_t &req_rw,
        addr_t &req_addr,
        data_t &req_data,
        wire_t &resp_valid,
        wire_t &resp_ready,
        data_t &resp_data );

  bool eval( uint64_t cycle );

  int get_return_value() { return returnValue_; }
};

#endif // VSCALE_VERILATOR_HTIF_H
