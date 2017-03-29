#include "cli.h"

#include "config.h"
#include "logger.h"

#include <cxxopts.hpp>
#include <fmt/format.h>

#include <cstdlib>

namespace spd = spdlog;

using namespace std;

Cli::Cli( int argc, char **argv )
{
  auto logger = get_logger();

  cxxopts::Options options( argv[0], "" );

  int exitCode = 0;
  bool showHelp = false;
  bool showVersion = false;
  int verbosity = 0;
  std::string cyclesString;

  // clang-format off
    options.add_options()
      ("h,help", "Display this help.", cxxopts::value<bool>(showHelp))
      ("loadmem", "Elf or hex file with the program which has to be loaded into memory.", cxxopts::value<std::string>(loadFile), "file")
      ("max-cycles", "The maximum number of cycles which should be simulated. [0 == infinite]", cxxopts::value<std::string>(cyclesString)->default_value("0"), "cycles")
      ("vcdfile", "The vcd file which should be written.", cxxopts::value<std::string>(vcdFile), "file")
      ("v,verbose", "The verbosity level.", cxxopts::value<int>(verbosity)->implicit_value("1"), "level")
      ( "version", "Display the version information.", cxxopts::value<bool>( showVersion ) );
  // clang-format on

  try {
    // configure the logger level based on the verbosity
    options.parse( argc, argv );
    switch( verbosity ) {
    case 0:
      break;
    case 1:
      logger->set_level( spd::level::info );
      break;
    case 2:
      logger->set_level( spd::level::debug );
      break;
    default:
      logger->set_level( spd::level::trace );
      break;
    }

    maxCycles = std::stoull( cyclesString, 0, 0 );

    logger->info(
        "Command line parameters: program file = \"{}\", "
        "vcd file = \"{}\", max cycles = {}",
        loadFile, vcdFile, maxCycles );
  }
  catch( const cxxopts::OptionException &e ) {
    logger->error( "error parsing options: {}", e.what() );
    showHelp = true;
    exitCode = -1;
  }

  if( !showHelp && !showVersion && loadFile == "" ) {
    logger->error( "no hex file has been specified via --loadmem" );
    showHelp = true;
    exitCode = -2;
  }

  if( showHelp || showVersion ) {
    if( showVersion ) fmt::printf( "Version: %s\n", VERSION_STR );
    if( showHelp ) fmt::printf( "\n%s\n", options.help( {""} ) );
    std::exit( exitCode );
  }
}

Cli::~Cli() {}
