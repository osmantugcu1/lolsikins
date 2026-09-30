#pragma once
#include <lol/common.hpp>
#include <string>
#include <vector>

namespace lol::utility {
    //! GET a URL over HTTPS. With size != 0 only the bytes [offset, offset + size) are requested (HTTP range).
    auto http_get(std::string const& url, std::uint64_t offset = 0, std::uint64_t size = 0) -> std::vector<char>;
}
