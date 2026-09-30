#include <zstd.h>

#include <chrono>
#include <fstream>
#include <lol/error.hpp>
#include <lol/rman/download.hpp>
#include <lol/utility/http.hpp>
#include <thread>

using namespace lol;
using namespace lol::rman;

namespace {
    constexpr std::uint64_t MAX_RANGE = 32 * 1024 * 1024;
    constexpr int ATTEMPTS = 4;

    auto fetch(std::string const& url, std::uint64_t offset, std::uint64_t size) -> std::vector<char> {
        for (int attempt = 1;; ++attempt) {
            try {
                return utility::http_get(url, offset, size);
            } catch (std::exception const&) {
                if (attempt == ATTEMPTS) {
                    throw;
                }
                lol::error::stack().clear();
                std::this_thread::sleep_for(std::chrono::seconds(attempt * 2));
            }
        }
    }
}

auto rman::download(Manifest const& manifest,
                    File const& file,
                    std::string const& bundle_base,
                    fs::path const& path,
                    Progress const& progress) -> void {
    lol_trace_func(lol_trace_var("{}", file.path), lol_trace_var("{}", path));
    auto const chunk = [&](std::size_t i) -> ChunkRef const& {
        auto const found = manifest.chunks.find(file.chunk_ids[i]);
        lol_throw_if_msg(found == manifest.chunks.end(), "Chunk {:016X} is missing", file.chunk_ids[i]);
        return found->second;
    };

    auto out = std::ofstream(path, std::ios::binary | std::ios::trunc);
    lol_throw_if_msg(!out, "Can not write {}", path);
    auto written = std::uint64_t{0};
    auto buffer = std::vector<char>{};
    for (std::size_t first = 0; first != file.chunk_ids.size();) {
        // Merge the following chunks that continue this one inside the same bundle.
        auto const& start = chunk(first);
        auto last = first + 1;
        auto length = (std::uint64_t)start.compressed_size;
        while (last != file.chunk_ids.size()) {
            auto const& next = chunk(last);
            if (next.bundle_id != start.bundle_id || next.bundle_offset != start.bundle_offset + length ||
                length + next.compressed_size > MAX_RANGE) {
                break;
            }
            length += next.compressed_size;
            ++last;
        }

        auto const data = fetch(fmt::format("{}{:016X}.bundle", bundle_base, start.bundle_id), start.bundle_offset, length);
        auto cursor = std::size_t{0};
        for (auto i = first; i != last; ++i) {
            auto const& ref = chunk(i);
            buffer.resize(ref.uncompressed_size);
            auto const result = ZSTD_decompress(buffer.data(), buffer.size(), data.data() + cursor, ref.compressed_size);
            lol_throw_if_msg(ZSTD_isError(result) || result != ref.uncompressed_size,
                             "Chunk {:016X} of {} is corrupt",
                             file.chunk_ids[i],
                             file.path);
            out.write(buffer.data(), (std::streamsize)buffer.size());
            cursor += ref.compressed_size;
            written += ref.uncompressed_size;
        }
        lol_throw_if_msg(!out, "Failed writing {}", path);
        if (progress) {
            progress(written);
        }
        first = last;
    }
    out.close();
    lol_throw_if_msg(!out || written != file.size, "{} is {} bytes, expected {}", file.path, written, file.size);
}
