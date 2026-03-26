#pragma once

#include <SQLiteCpp/SQLiteCpp.h>

#include <cstddef>
#include <cstdint>
#include <memory>
#include <nlohmann/json.hpp>
#include <optional>
#include <vector>

#include "common/groove/point.h"
#include "common/logging/application_log.h"
#include "common/storage/slot_buffer_storage.h"

namespace weld_control {

struct GrooveProfileData {
  std::vector<common::Point> profile;

  auto ToJson() const -> nlohmann::json {
    auto points = nlohmann::json::array();
    for (auto const& p : profile) {
      points.push_back(nlohmann::json{
          {"horizontal", p.horizontal},
          {"vertical",   p.vertical  }
      });
    }

    return nlohmann::json{
        {"profile", points},
    };
  }

  static auto FromJson(const nlohmann::json& json_obj) -> std::optional<GrooveProfileData> {
    try {
      auto const& points = json_obj.at("profile");
      if (!points.is_array()) {
        return std::nullopt;
      }

      std::vector<common::Point> profile;
      profile.reserve(points.size());

      for (auto const& p : points) {
        profile.push_back(common::Point{
            .horizontal = p.at("horizontal").get<double>(),
            .vertical   = p.at("vertical").get<double>(),
        });
      }

      return GrooveProfileData{.profile = std::move(profile)};
    } catch (const nlohmann::json::exception& e) {
      LOG_ERROR("Failed to parse GrooveProfileData from JSON: {}", e.what());
      return std::nullopt;
    }
  }
};

class GrooveProfileBuffer {
 public:
  explicit GrooveProfileBuffer(SQLite::Database* db)
      : storage_(std::make_unique<common::storage::SlotBufferStorage<GrooveProfileData>>(db, "groove_profile")) {}

  auto Init(double length, double resolution) -> void {
    auto const slots = static_cast<size_t>(length / resolution);
    storage_->Init(slots, 1.0);
  }

  auto Store(double pos, GrooveProfileData const& value) -> void { storage_->Store(pos, value); }

  auto Get(double pos) const -> std::optional<std::pair<double, GrooveProfileData>> { return storage_->Get(pos); }

  auto Clear() -> void { storage_->Clear(); }

  auto Empty() const -> bool { return storage_->Empty(); }

  auto Filled() const -> bool { return storage_->Filled(); }

  auto FilledSlots() const -> size_t { return storage_->FilledSlots(); }

  auto Slots() const -> size_t { return storage_->Slots(); }

  auto FillRatio() const -> double { return storage_->FillRatio(); }

  auto Available() const -> bool { return storage_->Available(); }

 private:
  std::unique_ptr<common::storage::SlotBufferStorage<GrooveProfileData>> storage_;
};

}  // namespace weld_control