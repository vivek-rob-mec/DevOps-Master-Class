param([switch]$WhatIfMode)
. (Join-Path $PSScriptRoot 'Common.ps1')

$project=@{
 Id='05-cpp-telemetry-monolith';Title='C++ Edge Telemetry Modular Monolith';Type='Modular monolith';Backend='C++20 / POSIX HTTP / SQLite';Frontend='React / Vite';Domain='telemetry';Namespace='telemetry-cpp';PublicPort=8085;Entry='app';Ui='app'
 Diagram=@'
flowchart LR
    Device["Edge devices"] --> HTTP["C++ HTTP adapter"]
    Operator --> UI["React operations console"] --> HTTP
    HTTP --> Ingest["Telemetry ingest module"]
    HTTP --> Query["Telemetry query module"]
    Ingest --> Domain["Validation and idempotency rules"]
    Query --> Domain
    Domain --> SQLite[(SQLite WAL store)]
    HTTP --> Metrics["Prometheus metrics"]
'@
 Workloads=@(
  @{Name='app';Port=8080;Health='/health';Responsibility='React UI, telemetry HTTP API, domain rules, and SQLite adapter in one deployable unit'}
 )
}

$root=New-CommonProject $project -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/CMakeLists.txt' @'
cmake_minimum_required(VERSION 3.22)
project(telemetry_monolith VERSION 0.1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
find_package(Threads REQUIRED)
find_package(SQLite3 REQUIRED)
add_executable(telemetry src/main.cpp)
target_compile_options(telemetry PRIVATE -Wall -Wextra -Wpedantic)
target_link_libraries(telemetry PRIVATE SQLite::SQLite3 Threads::Threads)
install(TARGETS telemetry RUNTIME DESTINATION bin)
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'app/src/main.cpp' @'
#include <arpa/inet.h>
#include <atomic>
#include <cctype>
#include <cstdint>
#include <cerrno>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <mutex>
#include <netinet/in.h>
#include <optional>
#include <random>
#include <regex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/socket.h>
#include <thread>
#include <unistd.h>

#include <sqlite3.h>

namespace fs = std::filesystem;

namespace {
std::atomic<bool> running{true};
std::atomic<unsigned long long> request_count{0};
std::mutex database_mutex;

struct Request {
    std::string method;
    std::string path;
    std::map<std::string, std::string> headers;
    std::string body;
};

struct Response {
    int status{200};
    std::string content_type{"application/json"};
    std::string body;
};

std::string lower(std::string value) {
    for (char& character : value) character = static_cast<char>(std::tolower(static_cast<unsigned char>(character)));
    return value;
}

std::string json_escape(const std::string& value) {
    std::ostringstream output;
    for (const unsigned char character : value) {
        switch (character) {
            case '"': output << "\\\""; break;
            case '\\': output << "\\\\"; break;
            case '\n': output << "\\n"; break;
            case '\r': output << "\\r"; break;
            case '\t': output << "\\t"; break;
            default:
                if (character < 0x20) output << "?";
                else output << character;
        }
    }
    return output.str();
}

std::optional<std::string> json_string(const std::string& body, const std::string& key) {
    const std::regex expression("\\\"" + key + "\\\"\\s*:\\s*\\\"([^\\\"]*)\\\"");
    std::smatch match;
    if (std::regex_search(body, match, expression)) return match[1].str();
    return std::nullopt;
}

std::string identifier() {
    static thread_local std::mt19937_64 random{std::random_device{}()};
    std::ostringstream value;
    value << std::hex << random() << random();
    return value.str();
}

class Database {
public:
    explicit Database(const std::string& path) {
        if (sqlite3_open(path.c_str(), &handle_) != SQLITE_OK) throw std::runtime_error("unable to open database");
        execute("PRAGMA journal_mode=WAL;");
        execute("PRAGMA busy_timeout=3000;");
        execute("CREATE TABLE IF NOT EXISTS telemetry_events ("
                "id TEXT PRIMARY KEY, event_type TEXT NOT NULL, payload TEXT NOT NULL, "
                "idempotency_key TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);");
    }
    ~Database() { if (handle_ != nullptr) sqlite3_close(handle_); }
    Database(const Database&) = delete;
    Database& operator=(const Database&) = delete;

    void execute(const std::string& sql) {
        char* error = nullptr;
        if (sqlite3_exec(handle_, sql.c_str(), nullptr, nullptr, &error) != SQLITE_OK) {
            const std::string message = error == nullptr ? "database error" : error;
            sqlite3_free(error);
            throw std::runtime_error(message);
        }
    }

    std::string list() {
        sqlite3_stmt* statement = nullptr;
        const char* query = "SELECT id,event_type,payload,created_at FROM telemetry_events ORDER BY created_at DESC LIMIT 200";
        if (sqlite3_prepare_v2(handle_, query, -1, &statement, nullptr) != SQLITE_OK) throw std::runtime_error("query preparation failed");
        std::ostringstream output;
        output << '[';
        bool first = true;
        while (sqlite3_step(statement) == SQLITE_ROW) {
            if (!first) output << ',';
            first = false;
            output << "{\"id\":\"" << json_escape(text(statement, 0)) << "\",\"eventType\":\"" << json_escape(text(statement, 1))
                   << "\",\"payload\":\"" << json_escape(text(statement, 2)) << "\",\"createdAt\":\"" << json_escape(text(statement, 3)) << "\"}";
        }
        sqlite3_finalize(statement);
        output << ']';
        return output.str();
    }

    std::string insert(const std::string& event_type, const std::string& payload, const std::string& key) {
        sqlite3_stmt* lookup = nullptr;
        sqlite3_prepare_v2(handle_, "SELECT id,event_type,payload,created_at FROM telemetry_events WHERE idempotency_key=?", -1, &lookup, nullptr);
        sqlite3_bind_text(lookup, 1, key.c_str(), -1, SQLITE_TRANSIENT);
        if (sqlite3_step(lookup) == SQLITE_ROW) {
            const std::string result = row(lookup);
            sqlite3_finalize(lookup);
            return result;
        }
        sqlite3_finalize(lookup);
        const std::string id = identifier();
        sqlite3_stmt* statement = nullptr;
        const char* sql = "INSERT INTO telemetry_events(id,event_type,payload,idempotency_key) VALUES(?,?,?,?)";
        if (sqlite3_prepare_v2(handle_, sql, -1, &statement, nullptr) != SQLITE_OK) throw std::runtime_error("insert preparation failed");
        sqlite3_bind_text(statement, 1, id.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 2, event_type.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 3, payload.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 4, key.c_str(), -1, SQLITE_TRANSIENT);
        if (sqlite3_step(statement) != SQLITE_DONE) {
            const std::string error = sqlite3_errmsg(handle_);
            sqlite3_finalize(statement);
            throw std::runtime_error(error);
        }
        sqlite3_finalize(statement);
        sqlite3_stmt* created = nullptr;
        sqlite3_prepare_v2(handle_, "SELECT id,event_type,payload,created_at FROM telemetry_events WHERE id=?", -1, &created, nullptr);
        sqlite3_bind_text(created, 1, id.c_str(), -1, SQLITE_TRANSIENT);
        if (sqlite3_step(created) != SQLITE_ROW) { sqlite3_finalize(created); throw std::runtime_error("insert verification failed"); }
        const std::string result = row(created);
        sqlite3_finalize(created);
        return result;
    }

private:
    sqlite3* handle_{nullptr};
    static std::string text(sqlite3_stmt* statement, int column) {
        const auto* value = sqlite3_column_text(statement, column);
        return value == nullptr ? "" : reinterpret_cast<const char*>(value);
    }
    static std::string row(sqlite3_stmt* statement) {
        return "{\"id\":\"" + json_escape(text(statement, 0)) + "\",\"eventType\":\"" + json_escape(text(statement, 1)) +
               "\",\"payload\":\"" + json_escape(text(statement, 2)) + "\",\"createdAt\":\"" + json_escape(text(statement, 3)) + "\"}";
    }
};

Request read_request(int socket) {
    std::string raw;
    char buffer[4096];
    std::size_t content_length = 0;
    std::size_t header_end = std::string::npos;
    while (raw.size() < 1024 * 1024) {
        const ssize_t received = recv(socket, buffer, sizeof(buffer), 0);
        if (received <= 0) break;
        raw.append(buffer, static_cast<std::size_t>(received));
        header_end = raw.find("\r\n\r\n");
        if (header_end != std::string::npos) {
            const std::regex length_expression("[Cc]ontent-[Ll]ength:\\s*([0-9]+)");
            std::smatch length_match;
            const std::string header_block = raw.substr(0, header_end);
            if (std::regex_search(header_block, length_match, length_expression)) content_length = std::stoul(length_match[1].str());
            if (raw.size() >= header_end + 4 + content_length) break;
        }
    }
    if (header_end == std::string::npos) throw std::runtime_error("invalid HTTP request");
    std::istringstream headers(raw.substr(0, header_end));
    Request request;
    std::string version;
    headers >> request.method >> request.path >> version;
    std::string line;
    std::getline(headers, line);
    while (std::getline(headers, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        const auto separator = line.find(':');
        if (separator != std::string::npos) {
            std::string value = line.substr(separator + 1);
            value.erase(0, value.find_first_not_of(" \t"));
            request.headers[lower(line.substr(0, separator))] = value;
        }
    }
    request.body = raw.substr(header_end + 4, content_length);
    return request;
}

std::string status_text(int status) {
    if (status == 200) return "OK";
    if (status == 201) return "Created";
    if (status == 400) return "Bad Request";
    if (status == 404) return "Not Found";
    if (status == 422) return "Unprocessable Entity";
    return "Internal Server Error";
}

void send_response(int socket, const Response& response, const std::string& request_id) {
    std::ostringstream message;
    message << "HTTP/1.1 " << response.status << ' ' << status_text(response.status) << "\r\n"
            << "Content-Type: " << response.content_type << "\r\n"
            << "Content-Length: " << response.body.size() << "\r\n"
            << "X-Request-ID: " << request_id << "\r\n"
            << "Connection: close\r\n\r\n" << response.body;
    const std::string payload = message.str();
    std::size_t sent = 0;
    while (sent < payload.size()) {
        const ssize_t count = send(socket, payload.data() + sent, payload.size() - sent, MSG_NOSIGNAL);
        if (count <= 0) break;
        sent += static_cast<std::size_t>(count);
    }
}

Response static_file(const std::string& web_root, std::string path) {
    if (path == "/") path = "/index.html";
    if (path.find("..") != std::string::npos) return {404, "application/json", "{\"code\":\"NOT_FOUND\"}"};
    fs::path target = fs::path(web_root) / path.substr(1);
    if (!fs::exists(target) || !fs::is_regular_file(target)) target = fs::path(web_root) / "index.html";
    std::ifstream input(target, std::ios::binary);
    if (!input) return {404, "application/json", "{\"code\":\"NOT_FOUND\"}"};
    std::ostringstream body;
    body << input.rdbuf();
    std::string type = "application/octet-stream";
    if (target.extension() == ".html") type = "text/html; charset=utf-8";
    else if (target.extension() == ".js") type = "application/javascript";
    else if (target.extension() == ".css") type = "text/css";
    return {200, type, body.str()};
}

Response route(const Request& request, const std::string& database_path, const std::string& web_root) {
    if (request.method == "GET" && request.path == "/health") {
        std::lock_guard<std::mutex> lock(database_mutex);
        Database database(database_path);
        return {200, "application/json", "{\"status\":\"ok\",\"service\":\"telemetry-app\"}"};
    }
    if (request.method == "GET" && request.path == "/metrics") {
        return {200, "text/plain; version=0.0.4", "# HELP telemetry_http_requests_total HTTP requests\n# TYPE telemetry_http_requests_total counter\ntelemetry_http_requests_total " + std::to_string(request_count.load()) + "\n"};
    }
    if (request.method == "GET" && request.path == "/api/events") {
        std::lock_guard<std::mutex> lock(database_mutex);
        Database database(database_path);
        return {200, "application/json", database.list()};
    }
    if (request.method == "POST" && request.path == "/api/events") {
        const auto key = request.headers.find("idempotency-key");
        if (key == request.headers.end() || key->second.empty()) return {400, "application/json", "{\"code\":\"IDEMPOTENCY_KEY_REQUIRED\"}"};
        const auto type = json_string(request.body, "eventType");
        const auto payload = json_string(request.body, "payload");
        if (!type || !payload || type->empty()) return {422, "application/json", "{\"code\":\"INVALID_EVENT\"}"};
        std::lock_guard<std::mutex> lock(database_mutex);
        Database database(database_path);
        return {201, "application/json", database.insert(*type, *payload, key->second)};
    }
    if (request.method == "GET" && !request.path.starts_with("/api/")) return static_file(web_root, request.path);
    return {404, "application/json", "{\"code\":\"NOT_FOUND\"}"};
}

void handle_client(int client, std::string database_path, std::string web_root) {
    const std::string request_id = identifier();
    try {
        const Request request = read_request(client);
        request_count.fetch_add(1);
        const Response response = route(request, database_path, web_root);
        std::cout << "{\"level\":\"info\",\"requestId\":\"" << request_id << "\",\"method\":\"" << json_escape(request.method)
                  << "\",\"path\":\"" << json_escape(request.path) << "\",\"status\":" << response.status << "}" << std::endl;
        send_response(client, response, request_id);
    } catch (const std::exception& error) {
        std::cerr << "{\"level\":\"error\",\"requestId\":\"" << request_id << "\",\"message\":\"" << json_escape(error.what()) << "\"}" << std::endl;
        send_response(client, {500, "application/json", "{\"code\":\"INTERNAL_ERROR\"}"}, request_id);
    }
    close(client);
}
}  // namespace

int main() {
    const int port = std::getenv("PORT") == nullptr ? 8080 : std::stoi(std::getenv("PORT"));
    const std::string database_path = std::getenv("DATABASE_PATH") == nullptr ? "/tmp/telemetry.db" : std::getenv("DATABASE_PATH");
    const std::string web_root = std::getenv("WEB_ROOT") == nullptr ? "/app/public" : std::getenv("WEB_ROOT");
    std::signal(SIGINT, [](int) { running = false; });
    std::signal(SIGTERM, [](int) { running = false; });
    const int server = socket(AF_INET, SOCK_STREAM, 0);
    if (server < 0) throw std::runtime_error("socket creation failed");
    int reuse = 1;
    setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(static_cast<uint16_t>(port));
    if (bind(server, reinterpret_cast<sockaddr*>(&address), sizeof(address)) < 0) throw std::runtime_error(std::string("bind failed: ") + std::strerror(errno));
    if (listen(server, 128) < 0) throw std::runtime_error("listen failed");
    std::cout << "{\"level\":\"info\",\"service\":\"telemetry-app\",\"port\":" << port << "}" << std::endl;
    while (running) {
        const int client = accept(server, nullptr, nullptr);
        if (client < 0) { if (errno == EINTR) continue; break; }
        std::thread(handle_client, client, database_path, web_root).detach();
    }
    close(server);
    return 0;
}
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'frontend/package.json' @'
{"name":"telemetry-react","private":true,"version":"0.1.0","type":"module","scripts":{"build":"vite build"},"dependencies":{"@vitejs/plugin-react":"6.0.4","vite":"8.1.0","react":"19.2.7","react-dom":"19.2.7"},"devDependencies":{}}
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/vite.config.js' 'import{defineConfig}from"vite";import react from"@vitejs/plugin-react";export default defineConfig({plugins:[react()]});' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/index.html' '<div id="root"></div><script type="module" src="/src/main.jsx"></script>' -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/main.jsx' @'
import React,{useEffect,useState}from"react";import{createRoot}from"react-dom/client";import"./style.css";function App(){const[events,setEvents]=useState([]),[message,setMessage]=useState("Ready");async function load(){setEvents(await(await fetch("/api/events")).json())}useEffect(()=>{load().catch(error=>setMessage(error.message))},[]);async function submit(event){event.preventDefault();const form=new FormData(event.currentTarget),response=await fetch("/api/events",{method:"POST",headers:{"Content-Type":"application/json","Idempotency-Key":crypto.randomUUID()},body:JSON.stringify({eventType:form.get("eventType"),payload:form.get("payload")})});setMessage(JSON.stringify(await response.json()));if(response.ok)await load()}return <main><h1>Edge Telemetry</h1><p>{message}</p><form onSubmit={submit}><input name="eventType" defaultValue="temperature"/><input name="payload" defaultValue="27.4C"/><button>Ingest event</button></form><ul>{events.map(item=><li key={item.id}><strong>{item.eventType}</strong> {item.payload} <small>{item.createdAt}</small></li>)}</ul></main>}createRoot(document.getElementById("root")).render(<App/>);
'@ -WhatIfMode:$WhatIfMode
Write-TemplateFile $root 'frontend/src/style.css' @'
:root{font-family:ui-monospace,SFMono-Regular,Consolas;color:#d9ffe7;background:#071810}body{margin:0}main{max-width:880px;margin:4rem auto;padding:2rem;border:1px solid #296d49;border-radius:14px;background:#0c2418}form{display:flex;gap:.7rem;flex-wrap:wrap}input,button{padding:.75rem;border-radius:7px;border:1px solid #3e8060;background:#102f20;color:#e8fff0}button{background:#39b972;color:#04160c}li{padding:.7rem;border-bottom:1px solid #245238}small{color:#82ae91}
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'Dockerfile' @'
FROM node:24-alpine AS frontend
WORKDIR /src
COPY frontend/package*.json ./
RUN npm ci --no-audit --no-fund
COPY frontend/ ./
RUN npm run build

FROM ubuntu:24.04 AS build
RUN apt-get update && apt-get install -y --no-install-recommends cmake g++ libsqlite3-dev ninja-build && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY app/ ./
RUN cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release && cmake --build build --parallel

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 app && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY --from=build /src/build/telemetry /app/telemetry
COPY --from=frontend /src/dist /app/public
RUN mkdir -p /app/data && chown -R app:app /app
USER 10001:10001
ENV PORT=8080 WEB_ROOT=/app/public DATABASE_PATH=/app/data/telemetry.db
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=10 CMD curl -fsS http://localhost:8080/health || exit 1
ENTRYPOINT ["/app/telemetry"]
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'docker-compose.yml' @'
services:
  app:
    image: ${REGISTRY:-local}/05-cpp-telemetry-monolith-app:${IMAGE_TAG:-dev}
    build: .
    environment: { PORT: 8080, WEB_ROOT: /app/public, DATABASE_PATH: /app/data/telemetry.db }
    ports: ["${PUBLIC_PORT:-8085}:8080"]
    volumes: [telemetry-data:/app/data]
    read_only: true
    tmpfs: [/tmp]
    security_opt: [no-new-privileges:true]
volumes: { telemetry-data: {} }
'@ -WhatIfMode:$WhatIfMode

Write-TemplateFile $root 'scripts/test.sh' @'
#!/usr/bin/env sh
set -eu
docker build --target build -t telemetry-cpp-build .
docker compose config --quiet
'@ -WhatIfMode:$WhatIfMode

[pscustomobject]@{Project=$project.Id;Root=$root;Files=$script:Generated.Count}
