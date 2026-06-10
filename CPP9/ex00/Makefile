NAME = btc
CXX = c++
CXXFLAGS = -std=c++98
#-Wall -Wextra -Werror 


HELPERS_DIR = helpers/
SRC_DIR = helpers/
HELPER_HEADERS = Iterator.hpp Map.hpp ReadFile.hpp \
	Vector.hpp Wire.hpp WriteFile.hpp \
	abo.hpp arithmatic.hpp macrogod.hpp \
	print.hpp templategod.hpp Curried.hpp

HEADERS = $(addprefix $(HELPERS_DIR),$(HELPER_HEADERS))

HELPER_CPP = Wire.cpp WriteFile.cpp ReadFile.cpp

HELPER_SRCS = $(addprefix $(SRC_DIR),$(HELPER_CPP))

SRCS = main.cpp $(HELPER_SRCS)
OBJS = $(SRCS:.cpp=.o)

all: $(NAME)

$(NAME): $(OBJS)
	$(CXX) $(CXXFLAGS) $(OBJS) -o $(NAME)

%.o: %.cpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS)

fclean: clean
	rm -f $(NAME)

re: fclean all

run: $(NAME)
	./btc test.txt

.PHONY: all clean fclean re
