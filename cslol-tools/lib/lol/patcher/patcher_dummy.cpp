#if !defined(__APPLE__)
// do not reorder
#    include <lol/error.hpp>
#    include <lol/patcher/patcher.hpp>

using namespace lol;
using namespace lol::patcher;

// LolSikins applies skins with the patcher host in its patcher folder, so mod-tools has no in-process patcher on
// Windows anymore (the old patcher DLL it needed expired and was removed).
auto patcher::run(std::function<void(Message, char const*)> update,
                  fs::path const& profile_path,
                  fs::path const& config_path,
                  fs::path const& game_path,
                  fs::names const& opts) -> void {
    (void)update;
    (void)profile_path;
    (void)config_path;
    (void)game_path;
    (void)opts;
    lol_throw_msg("runoverlay is not available, LolSikins applies skins with its patcher host");
}

#endif
