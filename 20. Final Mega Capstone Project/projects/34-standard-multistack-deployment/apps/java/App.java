import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Executors;

public class App {
    static String env(String key, String fallback) {
        String value = System.getenv(key);
        return value == null || value.isEmpty() ? fallback : value;
    }
    static String quote(String value) {
        StringBuilder result = new StringBuilder("\"");
        for (char c : value.toCharArray()) {
            if (c == '"' || c == '\\') result.append('\\').append(c);
            else if (c < 32) result.append(String.format("\\u%04x", (int)c));
            else result.append(c);
        }
        return result.append('"').toString();
    }
    public static void main(String[] args) throws Exception {
        var server = HttpServer.create(new InetSocketAddress(Integer.parseInt(env("PORT", "8080"))), 64);
        var executor = Executors.newVirtualThreadPerTaskExecutor();
        server.setExecutor(executor);
        server.createContext("/", exchange -> {
            String path = exchange.getRequestURI().getPath();
            int status = 200;
            String body = "{\"status\":\"ok\"}";
            if (!exchange.getRequestMethod().equals("GET")) {
                status = 405;
                body = "{\"error\":\"method not allowed\"}";
                exchange.getResponseHeaders().set("Allow", "GET");
            } else if (path.equals("/api/info")) {
                body = "{\"service\":\"deployment-demo\",\"stack\":\"java\",\"version\":"
                    + quote(env("APP_VERSION", "dev")) + ",\"environment\":" + quote(env("APP_ENV", "local")) + "}";
            } else if (!path.equals("/healthz") && !path.equals("/readyz")) {
                status = 404;
                body = "{\"error\":\"not found\"}";
            }
            byte[] payload = body.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(status, payload.length);
            try (var output = exchange.getResponseBody()) { output.write(payload); }
            exchange.close();
            System.out.println("{\"event\":\"request\",\"status\":" + status + ",\"stack\":\"java\"}");
        });
        Runtime.getRuntime().addShutdownHook(new Thread(() -> { server.stop(20); executor.close(); }));
        server.start();
    }
}
