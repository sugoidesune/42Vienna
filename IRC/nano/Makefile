NAME = ircserv
TESTRUNNER = testrunner
CXX = c++
CXXFLAGS = -Wall -Wextra -Werror -std=c++98

SRCS = main.cpp
OBJS = $(SRCS:.cpp=.o)

TEST_SRCS = tester/testrunner.cpp
TEST_OBJS = $(TEST_SRCS:.cpp=.o)

INTERCEPTOR = intercept/interceptor

all: $(NAME) $(TESTRUNNER) $(INTERCEPTOR)

$(NAME): $(OBJS)
	$(CXX) $(CXXFLAGS) $(OBJS) -o $(NAME)

$(TESTRUNNER):
	$(MAKE) -C tester

$(INTERCEPTOR):
	$(MAKE) -C intercept

clean:
	rm -f $(OBJS) *.log
	$(MAKE) -C tester clean
	$(MAKE) -C intercept clean

fclean: clean
	rm -f $(NAME)
	$(MAKE) -C tester fclean
	$(MAKE) -C intercept fclean

re: fclean all

run: $(NAME)
	./ircserv 6667 1234

intercept: $(INTERCEPTOR)
	./intercept/interceptor 127.0.0.1 6667

# Catch additional goals/arguments passed to make test (e.g., make test 04)
ifneq ($(filter test,$(firstword $(MAKECMDGOALS))),)
  RUNTESTER_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # Ignore the argument goals so make doesn't attempt to build them as targets
  $(eval $(RUNTESTER_ARGS):;@:)
endif

test: $(TESTRUNNER)
	@./tester/runtester $(RUNTESTER_ARGS) $(ARGS)

.PHONY: all clean fclean re run intercept test testrunner


