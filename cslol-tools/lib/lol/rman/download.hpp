#pragma once
#include <functional>
#include <lol/common.hpp>
#include <lol/fs.hpp>
#include <lol/rman/manifest.hpp>
#include <string>

namespace lol::rman {
    //! Reports how many uncompressed bytes of the file were written so far.
    using Progress = std::function<void(std::uint64_t written)>;

    //! Downloads one file of the release into `path`. Chunks that sit next to each other in a bundle are fetched with
    //! a single HTTP range request from `bundle_base` (".../channels/public/bundles/"). Throws if the result does not
    //! match the size the manifest gives.
    auto download(Manifest const& manifest,
                  File const& file,
                  std::string const& bundle_base,
                  fs::path const& path,
                  Progress const& progress = {}) -> void;
}
