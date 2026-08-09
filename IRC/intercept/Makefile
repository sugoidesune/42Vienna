NAME = interceptor
CXX = c++
CXXFLAGS = -Wall -Wextra -Werror -std=c++98

SRCS = main.cpp
OBJS = $(SRCS:.cpp=.o)

all: $(NAME)

$(NAME): $(OBJS)
	$(CXX) $(CXXFLAGS) $(OBJS) -o $(NAME)

clean:
	rm -f $(OBJS)

fclean: clean
	rm -f $(NAME)

re: fclean all

# Run the interceptor proxy on default target IRC server (127.0.0.1:6667)
run: $(NAME)
	./$(NAME) 127.0.0.1 6667

.PHONY: all clean fclean re run
