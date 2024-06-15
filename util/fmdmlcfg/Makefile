objdir = ./objs

TARGET ?=
ifeq ($(TARGET),)
CXX ?= g++
else
CXX = $(TARGET)-g++
endif

CXXFLAGS_ALL = -g $(CXXFLAGS)
CPPFLAGS_ALL = -std=gnu++11 -Wall -Wextra $(CPPFLAGS)
LDFLAGS_ALL = $(LDFLAGS)

LIBS = -lfltk

TARGET_OS ?= $(OS)
ifeq ($(TARGET_OS),Windows_NT)
ifneq ($(STATIC),)
	LIBS += -lole32 -luuid -lcomctl32 -lgdi32 -static
endif
	BINEXT = .exe
#else
#ifneq ($(STATIC),)
#	LIBS += -lX11 -lpthread -lxcb -lXau -lXdmcp -lXft -lXrender -lfontconfig -lexpat -lfreetype -lbz2 -lpng -lz -lbrotlidec-static -lbrotlicommon-static -lXext -lXinerama -static
#endif
endif

OBJS = $(objdir)/fmdmlcfg.o

all: $(objdir) fmdmlcfg$(BINEXT)

clean:
	rm -rf $(objdir)
	rm -f fmdmlcfg$(BINEXT)

$(objdir):
	mkdir -p $@

$(objdir)/%.o: %.cpp
	$(CXX) $(CXXFLAGS_ALL) $(CPPFLAGS_ALL) -c -o $@ $<

fmdmlcfg$(BINEXT): $(OBJS)
	$(CXX) $(CXXFLAGS_ALL) $(LDFLAGS_ALL) $^ -o $@ $(LIBS)
