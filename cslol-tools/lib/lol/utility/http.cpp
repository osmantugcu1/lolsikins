#include <lol/error.hpp>
#include <lol/utility/http.hpp>

using namespace lol;

#ifdef _WIN32
// do not reorder
#    define WIN32_LEAN_AND_MEAN
#    include <windows.h>
// do not reorder
#    include <winhttp.h>

namespace {
    struct Handle {
        HINTERNET handle = nullptr;
        explicit Handle(HINTERNET handle) noexcept : handle(handle) {}
        Handle(Handle const&) = delete;
        Handle& operator=(Handle const&) = delete;
        ~Handle() noexcept {
            if (handle) {
                WinHttpCloseHandle(handle);
            }
        }
        operator HINTERNET() const noexcept { return handle; }
    };

    auto widen(std::string const& str) -> std::wstring {
        auto const size = MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), nullptr, 0);
        auto result = std::wstring((std::size_t)size, L'\0');
        MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), result.data(), size);
        return result;
    }

    // One session for the whole process: WinHTTP keeps its connections alive between requests.
    auto session() -> HINTERNET {
        static auto const handle = [] {
            auto result = WinHttpOpen(L"LolSikins",
                                      WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                                      WINHTTP_NO_PROXY_NAME,
                                      WINHTTP_NO_PROXY_BYPASS,
                                      0);
            if (result) {
                WinHttpSetTimeouts(result, 30000, 30000, 60000, 60000);
            }
            return result;
        }();
        return handle;
    }
}

auto utility::http_get(std::string const& url, std::uint64_t offset, std::uint64_t size) -> std::vector<char> {
    lol_trace_func(lol_trace_var("{}", url), lol_trace_var("{}", offset), lol_trace_var("{}", size));
    lol_throw_if_msg(!session(), "WinHttpOpen failed: {}", GetLastError());

    auto const wide_url = widen(url);
    auto parts = URL_COMPONENTS{};
    parts.dwStructSize = sizeof(parts);
    parts.dwSchemeLength = (DWORD)-1;
    parts.dwHostNameLength = (DWORD)-1;
    parts.dwUrlPathLength = (DWORD)-1;
    parts.dwExtraInfoLength = (DWORD)-1;
    lol_throw_if_msg(!WinHttpCrackUrl(wide_url.c_str(), (DWORD)wide_url.size(), 0, &parts), "Bad url: {}", url);
    auto const host = std::wstring(parts.lpszHostName, parts.dwHostNameLength);
    auto object = std::wstring(parts.lpszUrlPath, parts.dwUrlPathLength);
    if (parts.lpszExtraInfo) {
        object += std::wstring(parts.lpszExtraInfo, parts.dwExtraInfoLength);
    }

    auto const connection = Handle(WinHttpConnect(session(), host.c_str(), parts.nPort, 0));
    lol_throw_if_msg(!connection, "WinHttpConnect failed: {}", GetLastError());
    auto const request = Handle(WinHttpOpenRequest(connection,
                                                   L"GET",
                                                   object.c_str(),
                                                   nullptr,
                                                   WINHTTP_NO_REFERER,
                                                   WINHTTP_DEFAULT_ACCEPT_TYPES,
                                                   parts.nScheme == INTERNET_SCHEME_HTTPS ? WINHTTP_FLAG_SECURE : 0));
    lol_throw_if_msg(!request, "WinHttpOpenRequest failed: {}", GetLastError());

    auto headers = std::wstring{};
    if (size) {
        headers = L"Range: bytes=" + std::to_wstring(offset) + L"-" + std::to_wstring(offset + size - 1);
    }
    lol_throw_if_msg(!WinHttpSendRequest(request,
                                         headers.empty() ? WINHTTP_NO_ADDITIONAL_HEADERS : headers.c_str(),
                                         headers.empty() ? 0 : (DWORD)-1L,
                                         WINHTTP_NO_REQUEST_DATA,
                                         0,
                                         0,
                                         0),
                     "WinHttpSendRequest failed: {}",
                     GetLastError());
    lol_throw_if_msg(!WinHttpReceiveResponse(request, nullptr), "WinHttpReceiveResponse failed: {}", GetLastError());

    auto status = DWORD{};
    auto status_size = DWORD{sizeof(status)};
    WinHttpQueryHeaders(request,
                        WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                        WINHTTP_HEADER_NAME_BY_INDEX,
                        &status,
                        &status_size,
                        WINHTTP_NO_HEADER_INDEX);
    lol_throw_if_msg(status != 200 && status != 206, "HTTP {} for {}", status, url);

    auto result = std::vector<char>{};
    if (size) {
        result.reserve(size);
    }
    for (;;) {
        auto available = DWORD{};
        lol_throw_if_msg(!WinHttpQueryDataAvailable(request, &available), "Download failed: {}", GetLastError());
        if (available == 0) {
            break;
        }
        auto const old_size = result.size();
        result.resize(old_size + available);
        auto read = DWORD{};
        lol_throw_if_msg(!WinHttpReadData(request, result.data() + old_size, available, &read),
                         "Download failed: {}",
                         GetLastError());
        result.resize(old_size + read);
    }

    // A server that ignores the range answers 200 with the whole file.
    if (size && status == 200) {
        lol_throw_if_msg(result.size() < offset + size, "Short download for {}", url);
        result = std::vector<char>(result.begin() + (std::ptrdiff_t)offset,
                                   result.begin() + (std::ptrdiff_t)(offset + size));
    }
    lol_throw_if_msg(size && result.size() != size, "Got {} bytes of {} for {}", result.size(), size, url);
    return result;
}

#else
#    include <cstdio>
#    include <memory>

// Non-Windows builds only exist for development; they shell out to curl.
auto utility::http_get(std::string const& url, std::uint64_t offset, std::uint64_t size) -> std::vector<char> {
    lol_trace_func(lol_trace_var("{}", url), lol_trace_var("{}", offset), lol_trace_var("{}", size));
    lol_throw_if_msg(url.find('\'') != std::string::npos, "Bad url: {}", url);
    auto const range = size ? fmt::format("-r {}-{} ", offset, offset + size - 1) : std::string{};
    auto const command = fmt::format("curl -sSL --fail {}'{}'", range, url);
    auto pipe = std::unique_ptr<FILE, int (*)(FILE*)>(popen(command.c_str(), "r"), pclose);
    lol_throw_if_msg(!pipe, "Failed to run curl");
    auto result = std::vector<char>{};
    char buffer[65536];
    while (auto const count = std::fread(buffer, 1, sizeof(buffer), pipe.get())) {
        result.insert(result.end(), buffer, buffer + count);
    }
    auto const status = pclose(pipe.release());
    lol_throw_if_msg(status != 0, "curl failed for {}", url);
    lol_throw_if_msg(size && result.size() != size, "Got {} bytes of {} for {}", result.size(), size, url);
    return result;
}
#endif
