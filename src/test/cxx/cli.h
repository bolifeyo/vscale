#ifndef VSCALE_VERILATOR_CLI_H
#define VSCALE_VERILATOR_CLI_H

#include <string>

class Cli {
public:
  Cli( int argc, char **argv );
  ~Cli();

  std::string loadFile;
  std::string vcdFile;
  uint64_t maxCycles;
};

#endif // VSCALE_VERILATOR_CLI_H
