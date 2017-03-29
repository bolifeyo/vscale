#include "logger.h"

#include <cassert>

Logger get_logger( const std::string &name )
{
  auto res = spdlog::get( name );
  if( !res ) {
    res = spdlog::stdout_logger_mt( name );
    res->set_level( spdlog::level::warn );
  }
  assert( res );
  return res;
}
