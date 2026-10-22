ODELIA ?= ../../odelia
CXXFLAGS = -std=c++20 -O2 -DXAD_NO_THREADLOCAL -DXAD_USE_STRONG_INLINE -I$(ODELIA)/inst/include

all: field_cut one_shot

field_cut: field_cut.cpp toy.hpp Tape.o
	$(CXX) $(CXXFLAGS) -o $@ field_cut.cpp Tape.o

one_shot: one_shot.cpp toy.hpp Tape.o
	$(CXX) $(CXXFLAGS) -o $@ one_shot.cpp Tape.o

Tape.o: $(ODELIA)/src/Tape.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

clean:
	rm -f field_cut one_shot Tape.o
