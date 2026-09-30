#pragma once
#include <lol/common.hpp>
#include <span>
#include <string>
#include <unordered_map>
#include <vector>

namespace lol::rman {
    //! Where a chunk of file data lives: a byte range inside a bundle on Riot's CDN.
    struct ChunkRef {
        std::uint64_t bundle_id;
        std::uint64_t bundle_offset;
        std::uint32_t compressed_size;
        std::uint32_t uncompressed_size;
    };

    //! A file of the release, made of zstd-compressed chunks.
    struct File {
        std::string path;
        std::uint64_t size;
        std::vector<std::uint64_t> chunk_ids;
    };

    //! Riot patcher release manifest (RMAN v2): a zstd-compressed FlatBuffer listing bundles, chunks and files.
    struct Manifest {
        std::vector<File> files;
        std::unordered_map<std::uint64_t, ChunkRef> chunks;

        static auto parse(std::span<char const> data) -> Manifest;
    };
}
