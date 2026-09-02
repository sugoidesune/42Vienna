ifeq ($(filter cm ng db wp rd st km ad ft,$(MAKECMDGOALS)),)
include Makefile.cm
else
cm ng db wp rd st km ad ft:
	$(MAKE) -f Makefile.$@ -- $(filter-out $@,$(MAKECMDGOALS))
.PHONY: cm ng db wp rd st km ad ft
%:
	@:
endif
