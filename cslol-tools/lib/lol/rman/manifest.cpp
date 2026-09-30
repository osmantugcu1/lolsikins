#include <zstd.h>

#include <cstring>
#include <lol/error.hpp>
#include <lol/rman/manifest.hpp>
#include <memory>
#include <optional>

using namespace lol;
using namespace lol::rman;

namespace {
    // Minimal bounds-checked FlatBuffer reader, enough for the manifest schema.
    struct Reader {
        std::span<char const> data;

        template <typename T>
        auto read(std::size_t pos) const -> T {
            lol_throw_if_msg(pos > data.size() || data.size() - pos < sizeof(T), "Manifest read out of bounds");
            auto value = T{};
            std::memcpy(&value, data.data() + pos, sizeof(T));
            return value;
        }

        struct Table {
            std::size_t pos;
            std::vector<std::uint16_t> fields;
        };

        auto table(std::size_t pos) const -> Table {
            auto const vtable = (std::int64_t)pos - read<std::int32_t>(pos);
            lol_throw_if_msg(vtable < 0, "Manifest vtable out of bounds");
            auto const vtable_size = read<std::uint16_t>((std::size_t)vtable);
            auto result = Table{pos, {}};
            for (std::size_t i = 4; i + 2 <= vtable_size; i += 2) {
                result.fields.push_back(read<std::uint16_t>((std::size_t)vtable + i));
            }
            return result;
        }

        auto field(Table const& t, std::size_t i) const -> std::optional<std::size_t> {
            if (i < t.fields.size() && t.fields[i] != 0) {
                return t.pos + t.fields[i];
            }
            return std::nullopt;
        }

        template <typename T>
        auto scalar(Table const& t, std::size_t i) const -> T {
            auto const at = field(t, i);
            return at ? read<T>(*at) : T{};
        }

        auto deref(std::size_t pos) const -> std::size_t { return pos + read<std::uint32_t>(pos); }

        auto tables(Table const& t, std::size_t i) const -> std::vector<Table> {
            auto result = std::vector<Table>{};
            if (auto const at = field(t, i)) {
                auto const vec = deref(*at);
                auto const count = read<std::uint32_t>(vec);
                result.reserve(count);
                for (std::size_t k = 0; k != count; ++k) {
                    result.push_back(table(deref(vec + 4 + 4 * k)));
                }
            }
            return result;
        }

        auto string(Table const& t, std::size_t i) const -> std::string {
            if (auto const at = field(t, i)) {
                auto const str = deref(*at);
                auto const size = read<std::uint32_t>(str);
                lol_throw_if_msg(str + 4 > data.size() || data.size() - str - 4 < size, "Manifest string out of bounds");
                return std::string(data.data() + str + 4, size);
            }
            return {};
        }

        auto u64s(Table const& t, std::size_t i) const -> std::vector<std::uint64_t> {
            auto result = std::vector<std::uint64_t>{};
            if (auto const at = field(t, i)) {
                auto const vec = deref(*at);
                auto const count = read<std::uint32_t>(vec);
                result.reserve(count);
                for (std::size_t k = 0; k != count; ++k) {
                    result.push_back(read<std::uint64_t>(vec + 4 + 8 * k));
                }
            }
            return result;
        }
    };

    // The body is several zstd frames in a row; the streaming API decodes all of them.
    auto decompress_body(std::span<char const> src, std::size_t size) -> std::vector<char> {
        auto result = std::vector<char>(size);
        auto ctx = std::unique_ptr<ZSTD_DStream, decltype(&ZSTD_freeDStream)>(ZSTD_createDStream(), ZSTD_freeDStream);
        lol_throw_if(!ctx || ZSTD_isError(ZSTD_initDStream(ctx.get())));
        auto input = ZSTD_inBuffer{src.data(), src.size(), 0};
        auto output = ZSTD_outBuffer{result.data(), result.size(), 0};
        while (input.pos < input.size) {
            auto const in_before = input.pos;
            auto const out_before = output.pos;
            auto const ret = ZSTD_decompressStream(ctx.get(), &output, &input);
            lol_throw_if_msg(ZSTD_isError(ret), "Manifest zstd error: {}", ZSTD_getErrorName(ret));
            lol_throw_if_msg(input.pos == in_before && output.pos == out_before, "Manifest body is larger than expected");
        }
        lol_throw_if_msg(output.pos != size, "Manifest body is {} bytes, expected {}", output.pos, size);
        return result;
    }
}

auto Manifest::parse(std::span<char const> data) -> Manifest {
    lol_trace_func(lol_trace_var("{}", data.size()));
    auto const header = Reader{data};
    lol_throw_if_msg(data.size() < 28 || std::memcmp(data.data(), "RMAN", 4) != 0, "Not a release manifest");
    auto const major = header.read<std::uint8_t>(4);
    lol_throw_if_msg(major != 2, "Unsupported manifest version {}", major);
    auto const offset = header.read<std::uint32_t>(8);
    auto const compressed = header.read<std::uint32_t>(12);
    auto const uncompressed = header.read<std::uint32_t>(24);
    lol_throw_if_msg(offset > data.size() || data.size() - offset < compressed, "Manifest is truncated");

    auto const body = decompress_body(data.subspan(offset, compressed), uncompressed);
    auto const fb = Reader{body};
    auto const root = fb.table(fb.deref(0));
    auto manifest = Manifest{};

    // Table 0: bundles, each a list of chunks stored back to back.
    for (auto const& bundle : fb.tables(root, 0)) {
        auto const bundle_id = fb.scalar<std::uint64_t>(bundle, 0);
        auto bundle_offset = std::uint64_t{0};
        for (auto const& chunk : fb.tables(bundle, 1)) {
            auto const ref = ChunkRef{
                .bundle_id = bundle_id,
                .bundle_offset = bundle_offset,
                .compressed_size = fb.scalar<std::uint32_t>(chunk, 1),
                .uncompressed_size = fb.scalar<std::uint32_t>(chunk, 2),
            };
            manifest.chunks.insert_or_assign(fb.scalar<std::uint64_t>(chunk, 0), ref);
            bundle_offset += ref.compressed_size;
        }
    }

    // Table 3: directories (id, parent id, name), used to build file paths.
    auto directories = std::unordered_map<std::uint64_t, std::pair<std::string, std::uint64_t>>{};
    for (auto const& directory : fb.tables(root, 3)) {
        directories.insert_or_assign(fb.scalar<std::uint64_t>(directory, 0),
                                     std::pair{fb.string(directory, 2), fb.scalar<std::uint64_t>(directory, 1)});
    }
    auto const directory_path = [&](std::uint64_t id) {
        auto path = std::string{};
        for (std::size_t depth = 0; id != 0 && depth != 64; ++depth) {
            auto const found = directories.find(id);
            if (found == directories.end()) {
                break;
            }
            path = path.empty() ? found->second.first : found->second.first + "/" + path;
            id = found->second.second;
        }
        return path;
    };

    // Table 2: files (1 directory id, 2 size, 3 name, 7 chunk ids).
    for (auto const& file : fb.tables(root, 2)) {
        auto const directory = directory_path(fb.scalar<std::uint64_t>(file, 1));
        auto const name = fb.string(file, 3);
        manifest.files.push_back(File{
            .path = directory.empty() ? name : directory + "/" + name,
            .size = fb.scalar<std::uint32_t>(file, 2),
            .chunk_ids = fb.u64s(file, 7),
        });
    }
    return manifest;
}
