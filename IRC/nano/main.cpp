#include <iostream>
#include <vector>
#include <map>
#include <sstream>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <poll.h>

#include "helpers/print.hpp"
#include "helpers/Wire.hpp"
#include "helpers/Style.hpp"

struct Client {
    int fd;
    Wire nick;
    Wire user;
    Wire read_buf;
    bool registered;

    Client() : fd(-1), registered(false) {}
    Client(int socket_fd) : fd(socket_fd), registered(false) {}
};

// Global state for single-file nano IRC server
// struct pollfd: structure used by poll() holding file descriptor (.fd), requested events (.events), and returned events (.revents)
static std::vector<struct pollfd> g_pollfds;
static std::map<int, Client> g_clients;
static Wire g_password;

// Forward declarations
static int init_server(int port);
static void set_nonblocking(int fd);
static void handle_new_connection(int listen_fd);
static void handle_client_data(int fd);
static void remove_client(int fd);
static void send_raw(int fd, const Wire &msg);
static void process_buffer(Client &client);
static void process_line(Client &client, const Wire &line);
static void check_registration(Client &client);

// -----------------------------------------------------------------------------
// Low-Level / Helper Functions
// -----------------------------------------------------------------------------

// Set socket descriptor to non-blocking I/O mode.
// fcntl (file control): performs operations on open file descriptors.
// F_GETFL: fetches current file status flags.
// F_SETFL: sets file status flags.
// O_NONBLOCK: enables non-blocking I/O mode so calls (e.g. recv, accept) return immediately rather than blocking execution thread.
static void set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0); // Retrieve current file status flags
    if (flags != -1) {
        fcntl(fd, F_SETFL, flags | O_NONBLOCK); // Append O_NONBLOCK to existing flags
    }
}

static void send_raw(int fd, const Wire &msg) {
    Wire formatted(msg, "\r\n");
    // send(): system call to transmit data over a connected socket descriptor.
    // fd: target socket descriptor.
    // formatted.c_str(): pointer to data buffer to send.
    // formatted.size(): length of data in bytes.
    // 0: flags parameter (0 specifies default transmission behavior).
    send(fd, formatted.c_str(), formatted.size(), 0);
    print("[OUT -> ", fd, "] ", msg);
}

static void send_reply(int fd, const Wire &code, const Wire &nick, const Wire &text) {
    Wire target = nick.empty() ? "*" : nick;
    Wire msg(":nanoirc ", code, " ", target, " :", text);
    send_raw(fd, msg);
}

// -----------------------------------------------------------------------------
// Lifecycle Section 1: Server Initialization
// -----------------------------------------------------------------------------

static int init_server(int port) {
    // socket(): system call creates an endpoint for network communication and returns socket file descriptor.
    // AF_INET: Address Family IPv4 internet protocols.
    // SOCK_STREAM: specifies sequenced, reliable, two-way connection-based byte streams (TCP protocol).
    // 0: protocol selector (0 selects default protocol for AF_INET and SOCK_STREAM, which is IPPROTO_TCP).
    int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0) {
        printErr("Failed to create socket");
        return -1;
    }

    // opt = 1: integer flag passed as boolean TRUE to enable socket option.
    int opt = 1;
    // setsockopt(): sets socket options at specified protocol levels.
    // listen_fd: target socket file descriptor.
    // SOL_SOCKET: socket API level (independent of underlying network protocol).
    // SO_REUSEADDR: enables socket binding even if address/port is in TIME_WAIT state (allows instant server restart).
    // &opt, sizeof(opt): option value buffer pointer and byte size.
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    set_nonblocking(listen_fd);

    // sockaddr_in: socket address structure for IPv4 addresses (defined in <netinet/in.h>).
    sockaddr_in addr;
    std::memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;           // sin_family: set to AF_INET for IPv4 addressing
    addr.sin_addr.s_addr = INADDR_ANY;   // INADDR_ANY: IPv4 wildcard IP address (0.0.0.0) binding server to all host network interfaces
    addr.sin_port = htons(port);         // htons (Host To Network Short): converts port number from host byte order to Network Byte Order (Big-Endian)

    // bind(): system call associates local IP address and port specified in sockaddr structure with listening socket descriptor.
    // (struct sockaddr *)&addr: pointer cast from sockaddr_in* to generic socket address struct pointer (struct sockaddr*).
    // sizeof(addr): total size of sockaddr_in structure in bytes.
    if (bind(listen_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        printErr("Failed to bind socket");
        close(listen_fd); // close(): system call to terminate file descriptor and free kernel resources
        return -1;
    }

    // listen(): system call marks socket descriptor as passive socket waiting to accept incoming connections.
    // listen_fd: passive listening socket descriptor.
    // 10: backlog count defining maximum length of queue of pending connections.
    if (listen(listen_fd, 10) < 0) {
        printErr("Failed to listen on socket");
        close(listen_fd);
        return -1;
    }

    // struct pollfd: descriptor monitoring structure passed to poll() system call.
    struct pollfd pfd;
    pfd.fd = listen_fd;  // fd: socket file descriptor to monitor
    pfd.events = POLLIN; // events: bitmask specifying requested events (POLLIN = data ready to read / connection incoming)
    pfd.revents = 0;     // revents: bitmask of returned events filled by poll() kernel call
    g_pollfds.push_back(pfd);

    return listen_fd;
}

// -----------------------------------------------------------------------------
// Lifecycle Section 2: Connection Management
// -----------------------------------------------------------------------------

static void handle_new_connection(int listen_fd) {
    // sockaddr_in: structure to receive connecting client address information.
    sockaddr_in client_addr;
    // socklen_t: integer type representing byte size of socket address structure.
    socklen_t addr_len = sizeof(client_addr);
    // accept(): system call extracts first connection request on backlog queue of listening socket.
    // Creates a new connected socket descriptor (client_fd) for client communication.
    // (struct sockaddr *)&client_addr: outputs client network address details.
    // &addr_len: value-result argument (input max size, output actual address size).
    int client_fd = accept(listen_fd, (struct sockaddr *)&client_addr, &addr_len);

    if (client_fd >= 0) {
        set_nonblocking(client_fd);
        struct pollfd pfd;
        pfd.fd = client_fd;
        pfd.events = POLLIN; // Monitor client socket for read readiness (POLLIN)
        pfd.revents = 0;
        g_pollfds.push_back(pfd);

        g_clients[client_fd] = Client(client_fd);
        print("[INFO] New client connected on fd ", client_fd);
    }
}

static void remove_client(int fd) {
    print("[INFO] Client disconnected on fd ", fd);
    // close(): system call to shut down socket and free descriptor resource.
    close(fd);
    g_clients.erase(fd);

    for (size_t i = 0; i < g_pollfds.size(); ++i) {
        if (g_pollfds[i].fd == fd) {
            g_pollfds.erase(g_pollfds.begin() + i);
            break;
        }
    }
}

// -----------------------------------------------------------------------------
// Lifecycle Section 3: Data Reception & Parsing
// -----------------------------------------------------------------------------

static void handle_client_data(int fd) {
    char buffer[512];
    // recv(): system call to receive incoming bytes from socket descriptor.
    // fd: target client socket file descriptor.
    // buffer: memory buffer pointer to store received raw bytes.
    // sizeof(buffer) - 1: maximum byte count to receive (leaving room for null character terminator).
    // 0: flags parameter (0 specifies standard receive behavior).
    // Returns byte count read (> 0), 0 on orderly connection shutdown (EOF), or < 0 on error/EWOULDBLOCK.
    ssize_t bytes_read = recv(fd, buffer, sizeof(buffer) - 1, 0);

    if (bytes_read <= 0) {
        remove_client(fd);
        return;
    }

    buffer[bytes_read] = '\0';
    g_clients[fd].read_buf += buffer;
    process_buffer(g_clients[fd]);
}

static void process_buffer(Client &client) {
    size_t pos;
    while ((pos = client.read_buf.find("\n")) != Wire::npos) {
        Wire line = client.read_buf.substr(0, pos);
        if (!line.empty() && line[line.size() - 1] == '\r') {
            line.erase(line.size() - 1);
        }
        client.read_buf.erase(0, pos + 1);
        process_line(client, line);
    }
}

// -----------------------------------------------------------------------------
// Lifecycle Section 4: IRC Command Protocol Handling
// -----------------------------------------------------------------------------

static void check_registration(Client &client) {
    if (!client.registered && !client.nick.empty() && !client.user.empty()) {
        client.registered = true;
        send_reply(client.fd, "001", client.nick, Wire("Welcome to nanoIRC ", client.nick, "!"));
        send_reply(client.fd, "002", client.nick, "Your host is nanoirc, running version 1.0");
        send_reply(client.fd, "003", client.nick, "This server was created today");
        send_reply(client.fd, "004", client.nick, "nanoirc 1.0 o o");
        print("[INFO] Client ", client.nick, " registered successfully.");
    }
}

static void process_line(Client &client, const Wire &line) {
    if (line.empty()) return;
    print("[IN  <- ", client.fd, "] ", line);

    std::stringstream ss(line);
    Wire cmd;
    ss >> cmd;

    for (size_t i = 0; i < cmd.size(); ++i) {
        cmd[i] = std::toupper(cmd[i]);
    }

    if (cmd == "CAP") {
        Wire sub;
        ss >> sub;
        if (sub == "LS") {
            send_raw(client.fd, ":nanoirc CAP * LS :");
        }
    } else if (cmd == "NICK") {
        Wire nick;
        ss >> nick;
        if (!nick.empty()) {
            client.nick = nick;
            check_registration(client);
        }
    } else if (cmd == "USER") {
        Wire user;
        ss >> user;
        if (!user.empty()) {
            client.user = user;
            check_registration(client);
        }
    } else if (cmd == "PING") {
        Wire token;
        ss >> token;
        if (token.length() > 0 && token[0] == ':') token = token.substr(1);
        send_raw(client.fd, Wire(":nanoirc PONG nanoirc :", token));
    } else if (cmd == "MOTD") {
        send_reply(client.fd, "375", client.nick, "- nanoirc Message of the day -");
        send_reply(client.fd, "372", client.nick, "- Hello World! Welcome to nanoIRC!");
        send_reply(client.fd, "376", client.nick, "End of MOTD command");
    } else if (cmd == "QUIT") {
        remove_client(client.fd);
    } else if (cmd == "PRIVMSG") {
        Wire target, text;
        ss >> target;
        std::getline(ss, text);
        if (!text.empty() && text[0] == ' ') text.erase(0, 1);
        if (!text.empty() && text[0] == ':') text.erase(0, 1);

        send_raw(client.fd, Wire(":", client.nick, "!", client.user, "@localhost PRIVMSG ", target, " :", text));
    }
}

// -----------------------------------------------------------------------------
// Lifecycle Section 5: Main Loop
// -----------------------------------------------------------------------------

int main(int argc, char **argv) {
    int port = 6667;
    if (argc >= 2) {
        port = std::atoi(argv[1]);
    }
    if (argc >= 3) {
        g_password = argv[2];
        print(Style("Admin Password: ").red().padx(5),g_password);
    }

    int listen_fd = init_server(port);
    if (listen_fd < 0) {
        return 1;
    }

    print("[SERVER] nanoIRC listening on port ", port);

    while (true) {
        // poll(): multiplexing system call that monitors multiple file descriptors for events.
        // &g_pollfds[0]: address of array containing pollfd structures.
        // g_pollfds.size(): number of descriptors currently in pollfd list.
        // -1: timeout parameter in milliseconds (-1 means wait indefinitely until an event arrives).
        // Returns number of ready descriptors (> 0), 0 on timeout, or -1 on error.
        int ret = poll(&g_pollfds[0], g_pollfds.size(), -1);
        if (ret < 0) {
            printErr("poll error");
            break;
        }

        for (size_t i = 0; i < g_pollfds.size(); ++i) {
            // revents: returned events bitmask populated by kernel during poll().
            // POLLIN: event bit indicating data is available to read without blocking.
            if (g_pollfds[i].revents & POLLIN) {
                if (g_pollfds[i].fd == listen_fd) {
                    handle_new_connection(listen_fd);
                } else {
                    handle_client_data(g_pollfds[i].fd);
                }
            }
        }
    }

    // close(): releases listening socket descriptor on loop termination.
    close(listen_fd);
    return 0;
}

