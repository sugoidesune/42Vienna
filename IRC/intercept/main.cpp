#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <sstream>
#include <cstdlib>
#include <cstring>
#include <cerrno>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/select.h>

static void set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags != -1) {
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }
}

static void print_message(const std::string& tag, const std::string& buf) {
    std::string line;
    std::istringstream iss(buf);
    while (std::getline(iss, line)) {
        if (!line.empty() && line[line.size() - 1] == '\r') {
            line.erase(line.size() - 1);
        }
        if (!line.empty()) {
            std::cout << "[" << tag << "] " << line << std::endl;
        }
    }
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " <target_ip> <target_port> [listening_port]" << std::endl;
        return 1;
    }

    std::string target_ip = argv[1];
    int target_port = std::atoi(argv[2]);
    int listen_port = 6666;
    if (argc >= 4) {
        listen_port = std::atoi(argv[3]);
    }

    int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0) {
        std::cerr << "Error creating listening socket: " << strerror(errno) << std::endl;
        return 1;
    }

    int opt = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in listen_addr;
    std::memset(&listen_addr, 0, sizeof(listen_addr));
    listen_addr.sin_family = AF_INET;
    listen_addr.sin_addr.s_addr = INADDR_ANY;
    listen_addr.sin_port = htons(listen_port);

    if (bind(listen_fd, (struct sockaddr*)&listen_addr, sizeof(listen_addr)) < 0) {
        std::cerr << "Error binding socket to port " << listen_port << ": " << strerror(errno) << std::endl;
        close(listen_fd);
        return 1;
    }

    if (listen(listen_fd, 10) < 0) {
        std::cerr << "Error listening on socket: " << strerror(errno) << std::endl;
        close(listen_fd);
        return 1;
    }

    struct sockaddr_in bound_addr;
    socklen_t addr_len = sizeof(bound_addr);
    if (getsockname(listen_fd, (struct sockaddr*)&bound_addr, &addr_len) == 0) {
        std::cout << "Interceptor listening on IP: 0.0.0.0, Port: " << ntohs(bound_addr.sin_port) << std::endl;
    } else {
        std::cout << "Interceptor listening on Port: " << listen_port << std::endl;
    }

    set_nonblocking(listen_fd);

    int client_counter = 0;

    // Maps to manage state
    std::map<int, int> client_to_server; // client_fd -> server_fd
    std::map<int, int> server_to_client; // server_fd -> client_fd
    std::map<int, std::string> client_tags; // client_fd -> "C1", "C2", ...
    std::map<int, std::string> server_tags; // server_fd -> "S1", "S2", ...
    std::map<int, std::string> client_buffers; // client_fd -> incoming stream buffer
    std::map<int, std::string> server_buffers; // server_fd -> incoming stream buffer

    while (true) {
        fd_set readfds;
        FD_ZERO(&readfds);

        FD_SET(listen_fd, &readfds);
        int max_fd = listen_fd;

        for (std::map<int, int>::iterator it = client_to_server.begin(); it != client_to_server.end(); ++it) {
            int cfd = it->first;
            int sfd = it->second;
            FD_SET(cfd, &readfds);
            FD_SET(sfd, &readfds);
            if (cfd > max_fd) max_fd = cfd;
            if (sfd > max_fd) max_fd = sfd;
        }

        int activity = select(max_fd + 1, &readfds, NULL, NULL, NULL);
        if (activity < 0) {
            if (errno == EINTR) continue;
            std::cerr << "Select error: " << strerror(errno) << std::endl;
            break;
        }

        // New client connection
        if (FD_ISSET(listen_fd, &readfds)) {
            struct sockaddr_in client_addr;
            socklen_t clen = sizeof(client_addr);
            int client_fd = accept(listen_fd, (struct sockaddr*)&client_addr, &clen);
            if (client_fd >= 0) {
                // Connect to remote target server
                int server_fd = socket(AF_INET, SOCK_STREAM, 0);
                if (server_fd >= 0) {
                    struct sockaddr_in srv_addr;
                    std::memset(&srv_addr, 0, sizeof(srv_addr));
                    srv_addr.sin_family = AF_INET;
                    srv_addr.sin_port = htons(target_port);
                    inet_pton(AF_INET, target_ip.c_str(), &srv_addr.sin_addr);

                    if (connect(server_fd, (struct sockaddr*)&srv_addr, sizeof(srv_addr)) >= 0) {
                        set_nonblocking(client_fd);
                        set_nonblocking(server_fd);

                        client_counter++;
                        std::ostringstream oss;
                        oss << "C" << client_counter;
                        std::string ctag = oss.str();
                        std::string stag = "S" + oss.str().substr(1);

                        client_to_server[client_fd] = server_fd;
                        server_to_client[server_fd] = client_fd;
                        client_tags[client_fd] = ctag;
                        server_tags[server_fd] = stag;

                        std::cout << "[SYSTEM] New client connected -> assigned tag " << ctag 
                                  << ", forwarded to " << target_ip << ":" << target_port << std::endl;
                    } else {
                        std::cerr << "[SYSTEM] Failed to connect to target server " << target_ip << ":" << target_port << std::endl;
                        close(server_fd);
                        close(client_fd);
                    }
                } else {
                    close(client_fd);
                }
            }
        }

        // Check active connections
        std::vector<int> to_close;
        for (std::map<int, int>::iterator it = client_to_server.begin(); it != client_to_server.end(); ++it) {
            int cfd = it->first;
            int sfd = it->second;

            // Data from Client
            if (FD_ISSET(cfd, &readfds)) {
                char buffer[4096];
                ssize_t bytes = recv(cfd, buffer, sizeof(buffer), 0);
                if (bytes <= 0) {
                    if (bytes < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                        // ignore
                    } else {
                        to_close.push_back(cfd);
                    }
                } else {
                    std::string data(buffer, bytes);
                    client_buffers[cfd] += data;
                    size_t pos;
                    while ((pos = client_buffers[cfd].find('\n')) != std::string::npos) {
                        std::string line = client_buffers[cfd].substr(0, pos + 1);
                        client_buffers[cfd].erase(0, pos + 1);
                        print_message(client_tags[cfd], line);
                    }
                    send(sfd, data.c_str(), data.size(), 0);
                }
            }

            // Data from Server
            if (FD_ISSET(sfd, &readfds)) {
                char buffer[4096];
                ssize_t bytes = recv(sfd, buffer, sizeof(buffer), 0);
                if (bytes <= 0) {
                    if (bytes < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                        // ignore
                    } else {
                        to_close.push_back(cfd);
                    }
                } else {
                    std::string data(buffer, bytes);
                    server_buffers[sfd] += data;
                    size_t pos;
                    while ((pos = server_buffers[sfd].find('\n')) != std::string::npos) {
                        std::string line = server_buffers[sfd].substr(0, pos + 1);
                        server_buffers[sfd].erase(0, pos + 1);
                        print_message(server_tags[sfd], line);
                    }
                    send(cfd, data.c_str(), data.size(), 0);
                }
            }
        }

        // Clean up disconnected sockets
        for (size_t i = 0; i < to_close.size(); ++i) {
            int cfd = to_close[i];
            if (client_to_server.count(cfd)) {
                int sfd = client_to_server[cfd];
                std::cout << "[SYSTEM] Connection " << client_tags[cfd] << " closed." << std::endl;
                close(cfd);
                close(sfd);
                client_tags.erase(cfd);
                server_tags.erase(sfd);
                client_buffers.erase(cfd);
                server_buffers.erase(sfd);
                server_to_client.erase(sfd);
                client_to_server.erase(cfd);
            }
        }
    }

    close(listen_fd);
    return 0;
}
