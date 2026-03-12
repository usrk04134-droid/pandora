#include "weld_observability.h"

#include <nlohmann/json.hpp>

#include "web_hmi/web_hmi.h"

namespace {
const auto SUCCESS_PAYLOAD = nlohmann::json{
    {"result", "ok"}
};
}

namespace weld_control {

WeldObservability::WeldObservability(const common::Point& slides_actual, const macs::Slice& cached_mcs,
                                     const double& vertical_offset, web_hmi::WebHmi* web_hmi)
    : slides_actual_(slides_actual), cached_mcs_(cached_mcs), vertical_offset_(vertical_offset), web_hmi_(web_hmi) {
  RegisterHandlers();
}

void WeldObservability::RegisterHandlers() {
  web_hmi_->Subscribe("WOBS_McsProfileGet", [this](std::string const&, const nlohmann::json&) { OnMcsProfileGet(); });

  web_hmi_->Subscribe("WOBS_SlidesPositionGet",
                      [this](std::string const&, const nlohmann::json&) { OnSlidesPositionGet(); });

  web_hmi_->Subscribe("WOBS_VerticalOffsetGet",
                      [this](std::string const&, const nlohmann::json&) { OnVerticalOffsetGet(); });
}

void WeldObservability::OnMcsProfileGet() {
  nlohmann::json payload;
  payload["profile"] = nlohmann::json::array();
  payload["groove"]  = nlohmann::json::array();

  for (const auto& p : cached_mcs_.profile) {
    nlohmann::json jp;
    jp["x"] = p.horizontal;
    jp["z"] = p.vertical;
    payload["profile"].push_back(jp);
  }
  if (cached_mcs_.groove.has_value()) {
    for (const auto& p : cached_mcs_.groove.value()) {
      nlohmann::json jg;
      jg["x"] = p.horizontal;
      jg["z"] = p.vertical;
      payload["groove"].push_back(jg);
    }
  }
  web_hmi_->Send("WOBS_McsProfileGetRsp", SUCCESS_PAYLOAD, payload);
}

void WeldObservability::OnSlidesPositionGet() {
  nlohmann::json payload;
  payload["horizontal"] = slides_actual_.horizontal;
  payload["vertical"]   = slides_actual_.vertical;

  web_hmi_->Send("WOBS_SlidesPositionGetRsp", SUCCESS_PAYLOAD, payload);
}

void WeldObservability::OnVerticalOffsetGet() {
  nlohmann::json payload;
  payload["verticalOffset"] = vertical_offset_;

  web_hmi_->Send("WOBS_VerticalOffsetGetRsp", SUCCESS_PAYLOAD, payload);
}

}  // namespace weld_control
