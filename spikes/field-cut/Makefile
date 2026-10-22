ODELIA ?= ../../odelia
CXXFLAGS = -std=c++20 -O2 -DXAD_NO_THREADLOCAL -DXAD_USE_STRONG_INLINE -I$(ODELIA)/inst/include

field_cut: field_cut.cpp Tape.o
	$(CXX) $(CXXFLAGS) -o $@ field_cut.cpp Tape.o

Tape.o: $(ODELIA)/src/Tape.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

clean:
	rm -f field_cut Tape.o
