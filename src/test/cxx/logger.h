#ifndef VSCALE_VERILATOR_LOGGER_H
#define VSCALE_VERILATOR_LOGGER_H

#include <spdlog/spdlog.h>

#include <memory>
#include <string>

using Logger = std::shared_ptr<spdlog::logger>;

Logger get_logger( const std::string &name = "default" );

#endif // VSCALE_VERILATOR_LOGGER_H
