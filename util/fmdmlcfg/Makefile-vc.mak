srcdir = .

CPU=i386
APPVER=4.0
NODEBUG=1
!include <win32.mak>

!IFDEF NODEBUG
cdebug = -O2 -DNDEBUG
!ELSE
cdebug = -Zi -Od -DDEBUG
!ENDIF

CFLAGS_ALL = $(CFLAGS) $(cdebug)
CPPFLAGS_ALL = $(CPPFLAGS) $(cflags) $(cvarsdll) -DUNICODE -D_UNICODE -DWIN32_LEAN_AND_MEAN -D_CRT_SECURE_NO_WARNINGS
LDFLAGS_ALL = $(LDFLAGS) $(ldebug)

LIBS = fltk.lib user32.lib gdi32.lib advapi32.lib shell32.lib ole32.lib

OBJS = $(srcdir)\fmdmlcfg.obj

{$(srcdir)}.cpp{$(srcdir)}.obj:
	$(cc) $(CFLAGS_ALL) $(CPPFLAGS_ALL) $<

all: fmdmlcfg.exe

clean:
	del /q fmdmlcfg.obj fmdmlcfg.exe fmdmlcfg.exe.manifest

$(srcdir)\fmdmlcfg.obj: fmdmlcfg.cpp

fmdmlcfg.exe: $(OBJS)
	$(link) $(LDFLAGS_ALL) -out:$@ $(OBJS) $(LIBS)

