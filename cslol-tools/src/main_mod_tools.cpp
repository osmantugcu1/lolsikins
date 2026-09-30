#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdio>
#include <fstream>
#include <lol/error.hpp>
#include <lol/fs.hpp>
#include <lol/hash/dict.hpp>
#include <lol/io/file.hpp>
#include <lol/log.hpp>
#include <lol/patcher/patcher.hpp>
#include <lol/rman/download.hpp>
#include <lol/rman/manifest.hpp>
#include <lol/utility/cli.hpp>
#include <lol/utility/http.hpp>
#include <lol/utility/zip.hpp>
#include <lol/wad/archive.hpp>
#include <lol/wad/index.hpp>
#include <mutex>
#include <set>
#include <thread>
#include <unordered_set>

using namespace lol;

static auto FILTER_NONE(wad::Index::Map::const_reference i) noexcept -> bool { return false; }

static auto FILTER_TFT(wad::Index::Map::const_reference i) noexcept -> bool {
    static constexpr std::string_view BLOCKLIST[] = {"map21", "map22"};
    for (auto const& name : BLOCKLIST)
        if (name == i.first) return true;
    return false;
}

static auto is_wad(fs::path const& path) -> bool {
    auto filename = path.filename().generic_string();
    if (filename.ends_with(".wad") || filename.ends_with(".wad.client")) return true;
    if (fs::exists(path / "data")) return true;
    if (fs::exists(path / "data2")) return true;
    if (fs::exists(path / "levels")) return true;
    if (fs::exists(path / "assets")) return true;
    if (fs::exists(path / "assets")) return true;
    if (fs::exists(path / "OBSIDIAN_PACKED_MAPPING.txt")) return true;
    return false;
}

static auto mod_addwad(fs::path src, fs::path dst, fs::path game, bool noTFT, bool removeUNK) -> void {
    lol_trace_func(lol_trace_var("{}", src), lol_trace_var("{}", dst), lol_trace_var("{}", game));
    lol_throw_if(src.empty());
    lol_throw_if(dst.empty());
    lol_throw_if(!fs::exists(dst / "META" / "info.json"));

    auto mounted = wad::Mounted{src.filename()};
    if (fs::is_directory(src)) {
        mounted.archive = wad::Archive::pack_from_directory(src);
    } else {
        mounted.archive = wad::Archive::read_from_file(src);
    }

    if (!game.empty()) {
        logi("Indexing game wads");
        auto game_index = wad::Index::from_game_folder(game);
        lol_throw_if_msg(game_index.mounts.empty(), "Not a valid Game folder");
        game_index.remove_filter(noTFT ? FILTER_TFT : FILTER_NONE);

        logi("Rebasing");
        auto base = game_index.find_by_mount_name_or_overlap(mounted.name(), mounted.archive);
        lol_throw_if_msg(!base, "Failed to find base wad for: {}", mounted.name());
        if (removeUNK) {
            mounted.remove_unknown(*base);
        }
        mounted.remove_unmodified(*base);
        mounted.relpath = mounted.relpath.parent_path() / base->relpath.filename();
    } else {
        logw("No game folder selected, falling back to manual rename!");
        auto filename = mounted.relpath.filename().generic_string();
        if (!filename.ends_with(".wad.client")) {
            if (filename.ends_with(".wad")) {
                filename.append(".client");
            } else {
                filename.append(".wad.client");
            }
        }
    }

    mounted.archive.write_to_file(dst / "WAD" / mounted.relpath);
}

static auto mod_copy(fs::path src, fs::path dst, fs::path game, bool noTFT) -> void {
    lol_trace_func(lol_trace_var("{}", src), lol_trace_var("{}", dst), lol_trace_var("{}", game));
    lol_throw_if(src.empty());
    lol_throw_if(dst.empty());
    lol_throw_if(!fs::exists(src / "META" / "info.json"));

    if (src == dst) {
        logi("Creating tmp directory");
        auto tmp = fs::tmp_dir{dst.generic_string() + ".tmp"};
        mod_copy(src, tmp.path, game, noTFT);

        logi("Removing original directory");
        fs::remove_all(src);

        logi("Moving tmp directory");
        tmp.move(src);
        return;
    }

    logi("Indexing mod wads");
    auto mod_index = wad::Index::from_mod_folder(src);

    if (!game.empty()) {
        logi("Indexing game wads");
        auto game_index = wad::Index::from_game_folder(game);
        lol_throw_if_msg(game_index.mounts.empty(), "Not a valid Game folder");
        game_index.remove_filter(noTFT ? FILTER_TFT : FILTER_NONE);

        logi("Rebasing wads");
        mod_index = mod_index.rebase_from_game(game_index);
    }

    logi("Resolving conflicts");
    mod_index.resolve_conflicts(mod_index, false);

    if (fs::exists(dst)) {
        fs::remove_all(dst);
    }

    logi("Copying META files");
    fs::create_directories(dst / "META");
    for (auto const& dirent : fs::directory_iterator(src / "META")) {
        auto relpath = fs::relative(dirent.path(), src);
        fs::copy_file(src / relpath, dst / relpath, fs::copy_options::overwrite_existing);
    }

    logi("Writing wads");
    fs::create_directories(dst);
    mod_index.write_to_directory(dst);
}

static auto mod_export(fs::path src, fs::path dst, fs::path game, bool noTFT) -> void {
    lol_trace_func(lol_trace_var("{}", src), lol_trace_var("{}", dst), lol_trace_var("{}", game));
    lol_throw_if(src.empty());
    lol_throw_if(dst.empty());
    lol_throw_if(!fs::exists(src / "META" / "info.json"));

    logi("Creating tmp directory");
    auto tmp = fs::tmp_dir{dst.generic_string() + ".tmp"};

    logi("Optimizing before zipping");
    mod_copy(src, tmp.path, game, noTFT);

    logi("Zipping mod");
    utility::zip(tmp.path, dst);
}

static auto mod_import(fs::path src, fs::path dst, fs::path game, bool noTFT) -> void {
    lol_trace_func(lol_trace_var("{}", src), lol_trace_var("{}", dst), lol_trace_var("{}", game));
    lol_throw_if(src.empty());
    lol_throw_if(dst.empty());

    logi("Creating tmp directory");
    auto tmp = fs::tmp_dir{dst.generic_string() + ".tmp"};

    if (is_wad(src)) {
        auto info_json = fmt::format(
            R"({{ "Author": "Unknown", "Description": "Imported from wad", "Name": "{}", "Version": "1.0.0" }})",
            wad::Mounted::make_name(src));
        auto info = io::File::create(tmp.path / "META" / "info.json");
        info.write(0, info_json.data(), info_json.size());
        mod_addwad(src, tmp.path, game, noTFT, false);
    } else if (auto filename = src.filename().generic_string();
               filename.ends_with(".zip") || filename.ends_with(".fantome")) {
        logi("Unzipping mod");
        utility::unzip(src, tmp.path);

        logi("Optimizing after unzipping");
        mod_copy(tmp.path, tmp.path, game, noTFT);
    } else if (fs::exists(src / "META" / "info.json")) {
        mod_copy(src, tmp.path, game, noTFT);
    } else {
        lol_throw_msg("Unsuported mod file!");
    }

    if (fs::exists(dst)) {
        logi("Remove existing mod");
        fs::remove_all(dst);
    }

    logi("Moving tmp directory");
    tmp.move(dst);
}

static auto mod_mkoverlay(fs::path src,
                          fs::path dst,
                          fs::path game,
                          fs::names mods,
                          fs::names under,
                          bool noTFT,
                          bool ignoreConflict) -> void {
    lol_trace_func(lol_trace_var("{}", src), lol_trace_var("{}", dst), lol_trace_var("{}", game));
    lol_throw_if(src.empty());
    lol_throw_if(dst.empty());
    lol_throw_if(game.empty());

    logi("Indexing game");
    auto game_index = wad::Index::from_game_folder(game);
    lol_throw_if_msg(game_index.mounts.empty(), "Not a valid Game folder");
    game_index.remove_filter(noTFT ? FILTER_TFT : FILTER_NONE);

    auto blocked = std::unordered_set<hash::Xxh64>{};
    for (auto const& [_, mounted] : game_index.mounts) {
        auto subchunk_name = fs::path(mounted.relpath).replace_extension(".SubChunkTOC").generic_string();
        blocked.insert(hash::Xxh64(subchunk_name));
    }
    auto mod_queue = std::vector<wad::Index>{};

    // Mods listed in --under: (the voice pack) go first and give way to any other mod that touches the same files.
    auto const is_under = [&](fs::path const& name) { return std::find(under.begin(), under.end(), name) != under.end(); };
    auto order = std::vector<fs::path>(mods.begin(), mods.end());
    std::stable_partition(order.begin(), order.end(), is_under);

    logi("Reading mods");
    for (auto const& mod_name : order) {
        auto mod_index = wad::Index::from_mod_folder(src / mod_name);
        for (auto& [path_, mounted] : mod_index.mounts) {
            std::erase_if(mounted.archive.entries, [&](auto const& kvp) { return blocked.contains(kvp.first); });
        }
        if (mod_index.mounts.empty()) {
            logw("Empty mod: {}", mod_index.name);
            continue;
        }

        // We have to resolve any conflicts inside mod itself
        mod_index.resolve_conflicts(mod_index, ignoreConflict);

        // We try to resolve conflicts with other mods
        for (auto& old : mod_queue) {
            old.resolve_conflicts(mod_index, ignoreConflict || is_under(old.name));
        }
        mod_queue.push_back(std::move(mod_index));
    }

    auto overlay_index = wad::Index{};
    logi("Merging mods");
    for (auto& mod_index : mod_queue) {
        overlay_index.add_overlay_mod(game_index, mod_index);
    }

    logi("Writing wads");
    fs::create_directories(dst);
    overlay_index.write_to_directory(dst);

    logi("Cleaning up stray wads");
    overlay_index.cleanup_in_directory(dst);
}

static auto mod_runoverlay(fs::path overlay, fs::path config_file, fs::path game, fs::names opts) -> void {
    lol_trace_func(lol_trace_var("{}", overlay), lol_trace_var("{}", config_file), lol_trace_var("{}", game));
    lol_throw_if(overlay.empty());
    lol_throw_if(config_file.empty());

    auto lock = new std::atomic_bool(false);
    auto thread = std::thread([lock] {
        setbuf(stdin, nullptr);
        for (;;) {
            int c = fgetc(stdin);
            if (c == '\n' && !*lock) {
                fflush(stdout);
                exit(0);
            }
            if (c == -1) {
                exit(0);
            }
        }
    });
    thread.detach();

    fmtlog::setLogFile(stdout, false);
    auto old_msg = patcher::M_DONE;
    try {
        patcher::run(
            [lock, &old_msg](auto msg, char const* arg) {
                if (msg != old_msg) {
                    old_msg = msg;
                    fprintf(stdout, "Status: %s\n", patcher::STATUS_MSG[msg]);
                    fflush(stdout);
                    if (msg == patcher::M_PATCH || msg == patcher::M_NEED_SAVE) {
                        *lock = true;
                        if (arg && *arg) {
                            fprintf(stdout, "Config: %s\n", arg);
                            fflush(stdout);
                        }
                    } else if (*lock) {
                        *lock = false;
                    }
                }
                if (msg == patcher::M_WAIT_EXIT) {
                    if (arg && *arg) {
                        fprintf(stdout, "[DLL] %s\n", arg);
                        fflush(stdout);
                    }
                }
            },
            overlay,
            config_file,
            game,
            opts);
    } catch (patcher::PatcherAborted const&) {
        // nothing to see here, lol
        lol::error::stack().clear();
        return;
    } catch (...) {
        throw;
    }
}

// Voice language packs.
//
// Voice-over lives in "<name>.<ll_CC>.wad.client" files under Champions/ and Maps/Shipping/, which hold nothing else.
// Every locale keeps its voice lines under the same entry paths, so the game plays whatever the WAD of its own locale
// holds. A voice pack is the target locale's WADs downloaded from Riot's CDN and saved under the game's locale names.
// Text lives in other locale files (Localized/Global, UI) that are left alone.

static constexpr char const* PATCH_SERVICE =
    "https://sieve.services.riotcdn.net/api/v1/products/lol/version-sets/EUW1"
    "?q[artifact_type_id]=lol-game-client&q[platform]=windows&q[published]=true";

// "ja_JP" out of "Ahri.ja_JP.wad.client", or empty.
static auto wad_locale(std::string_view filename) -> std::string {
    constexpr std::string_view suffix = ".wad.client";
    if (!filename.ends_with(suffix)) return {};
    filename.remove_suffix(suffix.size());
    auto const dot = filename.rfind('.');
    if (dot == std::string_view::npos) return {};
    auto const locale = filename.substr(dot + 1);
    if (locale.size() != 5 || locale[2] != '_') return {};
    if (!std::islower((unsigned char)locale[0]) || !std::islower((unsigned char)locale[1])) return {};
    if (!std::isupper((unsigned char)locale[3]) || !std::isupper((unsigned char)locale[4])) return {};
    return std::string(locale);
}

static auto lowercase(std::string str) -> std::string {
    std::transform(str.begin(), str.end(), str.begin(), [](unsigned char c) { return (char)std::tolower(c); });
    return str;
}

// Game release manifest url and its version ("16.19", may be empty), from Riot's patch service.
static auto find_game_release() -> std::pair<std::string, std::string> {
    auto const response = utility::http_get(PATCH_SERVICE);
    auto const json = std::string_view(response.data(), response.size());
    auto const string_after = [&](std::string_view key) -> std::string {
        auto at = json.find(key);
        if (at == std::string_view::npos) return {};
        at = json.find('"', at + key.size());
        auto const end = at == std::string_view::npos ? at : json.find('"', at + 1);
        if (end == std::string_view::npos) return {};
        return std::string(json.substr(at + 1, end - at - 1));
    };
    auto const url = string_after("\"url\":");
    lol_throw_if_msg(!url.starts_with("https://") || !url.ends_with(".manifest"), "Unexpected patch service response");
    auto version = string_after("\"riot:artifact_version_id\":{\"values\":[");
    if (auto const dot = version.find('.'); dot != std::string::npos) {
        version = version.substr(0, version.find('.', dot + 1));
    }
    return {url, version};
}

static auto read_file(fs::path const& path) -> std::vector<char> {
    auto file = std::ifstream(path, std::ios::binary);
    lol_throw_if_msg(!file, "Can not read {}", path);
    return std::vector<char>(std::istreambuf_iterator<char>(file), {});
}

static auto json_string(std::string_view str) -> std::string {
    auto result = std::string{"\""};
    for (char c : str) {
        if (c == '"' || c == '\\') result += '\\';
        result += c;
    }
    return result + "\"";
}

static auto mod_mkvoice(std::string target,
                        fs::path dst,
                        fs::path game,
                        fs::path work,
                        std::string manifest_url,
                        std::string bundle_base,
                        std::string name,
                        bool noTFT,
                        std::size_t jobs) -> void {
    lol_trace_func(lol_trace_var("{}", target), lol_trace_var("{}", dst), lol_trace_var("{}", game));
    lol_throw_if(dst.empty());
    lol_throw_if(game.empty());
    lol_throw_if_msg(wad_locale("voice." + target + ".wad.client") != target, "Bad language: {}", target);
    if (work.empty()) {
        work = fs::path(dst).concat(".voice");
    }
    jobs = std::clamp<std::size_t>(jobs ? jobs : 4, 1, 16);

    // The game's voice language is the one its champion WADs use.
    logi("Indexing game");
    auto const final_dir = game / "DATA" / "FINAL";
    lol_throw_if_msg(!fs::exists(final_dir), "Not a valid Game folder");
    auto game_wads = std::set<std::string>{};
    auto counts = std::map<std::string, std::size_t>{};
    for (auto const& dirent : fs::recursive_directory_iterator(final_dir)) {
        if (!dirent.is_regular_file()) continue;
        auto const locale = wad_locale(dirent.path().filename().generic_string());
        if (locale.empty()) continue;
        auto const relpath = fs::relative(dirent.path(), game).generic_string();
        game_wads.insert(lowercase(relpath));
        if (lowercase(relpath).starts_with("data/final/champions/")) counts[locale] += 1;
    }
    lol_throw_if_msg(counts.empty(), "The game has no voice files");
    auto const current = std::max_element(counts.begin(), counts.end(), [](auto const& l, auto const& r) {
                             return l.second < r.second;
                         })->first;
    lol_throw_if_msg(current == target, "The game already uses {} voices", target);

    auto version = std::string{};
    if (manifest_url.empty()) {
        std::tie(manifest_url, version) = find_game_release();
    }
    logi("Voice: {} over {}, release {} {}", target, current, version, manifest_url);
    auto const manifest = rman::Manifest::parse(manifest_url.starts_with("https://") ? utility::http_get(manifest_url)
                                                                                    : read_file(manifest_url));
    if (bundle_base.empty()) {
        lol_throw_if_msg(manifest_url.find("/releases/") == std::string::npos, "Unknown bundle location");
        bundle_base = manifest_url.substr(0, manifest_url.rfind("/releases/")) + "/bundles/";
    }

    // Target-locale voice WADs whose twin in the game's locale exists.
    struct Job {
        rman::File const* file;
        std::string name;
    };
    auto queue = std::vector<Job>{};
    auto total = std::uint64_t{0};
    for (auto const& file : manifest.files) {
        auto const relpath = lowercase(file.path);
        if (!relpath.starts_with("data/final/champions/") && !relpath.starts_with("data/final/maps/shipping/")) continue;
        auto const filename = fs::path(file.path).filename().generic_string();
        if (wad_locale(filename) != target) continue;
        if (noTFT && (relpath.find("/tftchampion.") != std::string::npos || relpath.find("/map22.") != std::string::npos)) {
            continue;
        }
        auto twin = file.path;
        twin.replace(twin.size() - std::string_view(".wad.client").size() - target.size(), target.size(), current);
        if (!game_wads.contains(lowercase(twin))) continue;
        queue.push_back({&file, fs::path(twin).filename().generic_string()});
        total += file.size;
    }
    lol_throw_if_msg(queue.empty(), "No {} voice files match the game", target);

    // Work folder: finished WADs stay there, so an interrupted build continues where it stopped.
    auto const stamp = fmt::format("{}\n{}\n{}\n", target, current, manifest_url);
    if (auto old = std::ifstream(work / "build.txt"); !old || std::string(std::istreambuf_iterator<char>(old), {}) != stamp) {
        old.close();
        fs::remove_all(work);
        fs::create_directories(work / "WAD");
        std::ofstream(work / "build.txt", std::ios::binary) << stamp;
    }
    fs::create_directories(work / "WAD");
    fs::create_directories(work / "download");

    auto done_files = std::atomic<std::size_t>{0};
    auto done_bytes = std::atomic<std::uint64_t>{0};
    auto next = std::atomic<std::size_t>{0};
    auto failed = std::atomic<bool>{false};
    auto failure = std::string{};
    auto failure_lock = std::mutex{};
    auto const worker = [&] {
        for (;;) {
            auto const index = next++;
            if (index >= queue.size() || failed) return;
            auto const& job = queue[index];
            try {
                auto const out = work / "WAD" / job.name;
                if (!fs::exists(out)) {
                    auto const download = work / "download" / job.name;
                    auto last = std::uint64_t{0};
                    rman::download(manifest, *job.file, bundle_base, download, [&](std::uint64_t written) {
                        done_bytes += written - last;
                        last = written;
                    });
                    fs::rename(download, out);
                } else {
                    done_bytes += job.file->size;
                }
                done_files += 1;
            } catch (std::exception const& error) {
                auto lock = std::lock_guard(failure_lock);
                if (!failed.exchange(true)) {
                    failure = fmt::format("{}: {}", job.name, error.what());
                }
                return;
            }
        }
    };

    logi("Voice: {} files, {} MB", queue.size(), total >> 20);
    auto threads = std::vector<std::thread>{};
    for (std::size_t i = 0; i != std::min(jobs, queue.size()); ++i) {
        threads.emplace_back(worker);
    }
    for (auto last = std::chrono::steady_clock::now();;) {
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
        auto const finished = done_files.load() == queue.size() || failed;
        if (finished || std::chrono::steady_clock::now() - last > std::chrono::seconds(1)) {
            last = std::chrono::steady_clock::now();
            fmt::print("Voice progress: {}/{} MB, {}/{} files\n",
                       std::min(done_bytes.load(), total) >> 20,
                       total >> 20,
                       done_files.load(),
                       queue.size());
            fflush(stdout);
        }
        if (finished) break;
    }
    for (auto& thread : threads) {
        thread.join();
    }
    lol_throw_if_msg(failed.load(), "Voice download failed: {}", failure);

    // Replace the previous voice pack with the finished one.
    fs::remove_all(work / "download");
    fs::create_directories(work / "META");
    std::ofstream(work / "META" / "info.json", std::ios::binary) << fmt::format(
        "{{\n    \"Name\": {},\n    \"Author\": \"LolSikins\",\n    \"Version\": {},\n    \"Description\": {}\n}}\n",
        json_string(name.empty() ? "Voice " + target : name),
        json_string(version.empty() ? "1.0" : version),
        json_string(fmt::format("{} voices over the game's {} files. Text stays unchanged.", target, current)));
    // build.txt goes last: if the old pack can not be replaced yet, the next run still finds every file done.
    fs::remove_all(dst);
    fs::create_directories(dst.parent_path());
    fs::rename(work, dst);
    fs::remove(dst / "build.txt");
}

static auto help(fs::path cmd) -> void {
    lol_trace_func(
        "addwad <src> <dst> --game:<path> --noTFT --removeUNK",
        "copy <src> <dst> --game:<path> --noTFT",
        "export <src> <dst> --game:<path> --noTFT",
        "import <src> <dst> --game:<path> --noTFT",
        "mkoverlay <modsdir> <overlay> --game:<path> --mods:<name1>/<name2>/<name3>... --under:<name>/... --noTFT --ignoreConflict",
        "runoverlay <overlay> <configfile> --game:<path> --opts:<none/configless>...",
        "mkvoice <ll_CC> <dst> --game:<path> --work:<dir> --manifest:<url or file> --bundles:<url> --name:<name> --jobs:<n> --noTFT",
        "help");
    lol_throw_msg("Bad command: {}", cmd);
}

int main(int argc, char** argv) {
    utility::set_binary_io();
    fmtlog::setHeaderPattern("[{l}] ");
    fmtlog::setLogFile(stdout, false);
    lol::init_logging_thread();
    try {
        fs::path exe, cmd, src, dst;
        auto flags = utility::argv_parse(utility::argv_fix(argc, argv), exe, cmd, src, dst);
        if (cmd == "addwad") {
            mod_addwad(src, dst, flags["--game:"], flags.contains("--noTFT"), flags.contains("--removeUNK"));
        } else if (cmd == "copy") {
            mod_copy(src, dst, flags["--game:"], flags.contains("--noTFT"));
        } else if (cmd == "export") {
            mod_export(src, dst, flags["--game:"], flags.contains("--noTFT"));
        } else if (cmd == "import") {
            mod_import(src, dst, flags["--game:"], flags.contains("--noTFT"));
        } else if (cmd == "mkoverlay") {
            mod_mkoverlay(src,
                          dst,
                          flags["--game:"],
                          flags["--mods:"],
                          flags["--under:"],
                          flags.contains("--noTFT"),
                          flags.contains("--ignoreConflict"));
        } else if (cmd == "runoverlay") {
            mod_runoverlay(src, dst, flags["--game:"], flags["--opts:"]);
        } else if (cmd == "mkvoice") {
            auto const jobs = flags["--jobs:"].generic_string();
            mod_mkvoice(src.generic_string(),
                        dst,
                        flags["--game:"],
                        flags["--work:"],
                        flags["--manifest:"].generic_string(),
                        flags["--bundles:"].generic_string(),
                        flags["--name:"].generic_string(),
                        flags.contains("--noTFT"),
                        jobs.empty() ? 0 : (std::size_t)std::stoul(jobs));
        } else {
            help(cmd);
        }
        logi("Done!");
    } catch (std::exception const& error) {
        fmtlog::poll(true);
        fflush(stdout);

        fmt::print(stderr, "backtrace: {}\nerror: {}\n", lol::error::stack_trace(), error);
        fflush(stderr);
        return EXIT_FAILURE;
    }

    fmtlog::poll(true);
    fflush(stdout);
    return EXIT_SUCCESS;
}
