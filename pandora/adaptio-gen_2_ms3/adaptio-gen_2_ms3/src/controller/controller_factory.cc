#include "controller_factory.h"

#include <memory>

#include "common/clock_functions.h"
#include "common/logging/application_log.h"
#include "controller/controller.h"
#include "controller/controller_configuration.h"
#ifdef ENABLE_PNDRIVER
#include "controller/pn_driver/pn_driver.h"
#endif
#include "controller/simulation/simulation.h"

using controller::ControllerFactory;
using controller::ControllerType;
using controller::simulation::Simulation;

// TODO: This should return a boost::result iso we can return a proper error instead of just nullptr
auto ControllerFactory::CreateController(const ControllerConfigurationData& configuration,
                                         clock_functions::SteadyClockNowFunc _func) -> std::unique_ptr<Controller> {
  ControllerPtr controller(nullptr);

  switch (configuration.type) {
    case ControllerType::PN_DRIVER: {
#ifdef ENABLE_PNDRIVER
      if (configuration.pn_driver.has_value()) {
        controller = std::make_unique<controller::pn_driver::PnDriver>(configuration.pn_driver.value(), _func);
      } else {
        LOG_ERROR("PN driver selected but no configuration provided");
      }
#else
      LOG_ERROR("PnDriver not compiled in this build (ENABLE_PNDRIVER=OFF)");
#endif
    } break;
    case ControllerType::SIMULATION: {
      controller = std::make_unique<Simulation>(_func);
    } break;
  }

  return controller;
}
