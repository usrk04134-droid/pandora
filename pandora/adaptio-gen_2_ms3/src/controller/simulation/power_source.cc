#include "power_source.h"

using controller::simulation::PowerSource;

void PowerSource::Update() {
  if (commands.weld_start) {
    status.arcing  = true;
    status.voltage = commands.voltage;
    status.current = commands.current;
  } else {
    status.arcing              = false;
    status.in_welding_sequence = false;
    status.voltage             = 0.0;
    status.current             = 0.0;
  }
}
