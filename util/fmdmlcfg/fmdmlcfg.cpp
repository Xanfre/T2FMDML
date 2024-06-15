#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <FL/Fl.H>
#include <FL/filename.H>
#include <FL/Fl_File_Chooser.H> 
#include <FL/Fl_Widget.H>
#include <FL/fl_ask.H>
#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <direct.h>
#include <io.h>
#include <windows.h>
#define MAX_PATH_BUF MAX_PATH
#define DIRSEP "\\"
#else
#include <unistd.h>
#define MAX_PATH_BUF PATH_MAX
#define DIRSEP "/"
#endif
#ifdef _GNU_SOURCE
#define stristr strcasestr
#endif

// constant strings
#define DML_KEY "//T2 FM: "
#define SEC_KEY "//Section: "
#define CMT_BEGIN "/*"
#define CMT_END "*/"
#define DIS_SUF ".disabled"

// constant values
#define DML_KEY_LEN 9
#define SEC_KEY_LEN 11
#define CMT_BEGIN_LEN 2
#define CMT_END_LEN 2
#define DIS_SUF_LEN 9
#define HEADER_BUF 1024 // Max header buffer size.
#define FMDML_GAM -1
#define FMDML_GLOBAL_GAM 0

// configuration
#define SCALE(x) x * g_scale / 4

// callbacks
static void OnConfigure(Fl_Widget *o, void *p);
static void OnSelect(Fl_Widget *o, void *p);
static void OnToggle(Fl_Widget *o, void *p);
static void OnSearch(Fl_Widget *o, void *p);
static void OnExit(Fl_Widget *o, void *p);
static void OnConfigChanged(Fl_Widget *o, void *p);
static void OnConfigDone(Fl_Widget *o, void *p);
static void OnConfigClose(Fl_Widget *o, void *p);

// globals
#ifdef DEF_SCALE
static int g_scale = DEF_SCALE + 3;
#else
static int g_scale = 4;
#endif

// interface definitions
#include "fl_mainwnd.cpp.h"
#include "fl_dmlconfig.cpp.h"

// return codes
#define FMDML_RET_ERR -1
#define FMDML_RET_SUCCESS 0

// structures
typedef struct _DMLEntry
{
	short misnum;
	char *fname;
	bool enabled;
}
DMLEntry;

// prototypes
static bool HasCommandLineOption(int argc, char **argv, const char *option);
static bool GetCommandLineInt(int argc, char **argv, const char *option,
	int *val);
static void InitFLTK(const char *theme);
static void SetDMLDir(const short misnum, char *path);
static void SetDMLPath(const DMLEntry *e, char *path, const size_t pathSize);
static bool IsDMLHeaderValid(char *header);
static void GetSortName(char **name);
static int ChangeCurrentDir(bool useBinDir);
static int ReadFileIntoBuffer(const char *name, char **data, size_t *len,
	const size_t extraSize = 0);
static void GetDMLs(void);
static void ClearDMLs(void);

// helpers
#ifndef stristr
static char* stristr(const char *haystack, const char *needle)
{
	int c = tolower(*needle);
	if (c == '\0')
		return (char *) haystack;
	for (; *haystack != '\0'; haystack++)
	{
		if (tolower((unsigned char) *haystack) != c)
			continue;
		size_t i = 0;
		while (1)
		{
			if (needle[++i] == '\0')
				return (char *) haystack;
			if (tolower((unsigned char) haystack[i])
				!= tolower((unsigned char) needle[i]))
				break;
		}
	}
	return NULL;
}
#endif

/////////////////////////////////////////////////////////////////////
// MAIN WINDOW

static void OnConfigure(Fl_Widget *, void *)
{
	// Ignore message if configure window is already showing.
	if (NULL != pDMLConfig)
		return;
	const int sel = pDMLList->value();
	if (0 == sel)
	{
		fl_message("Please select a DML before attempting to configure.");
		return;
	}
	DMLEntry *e = (DMLEntry *) pDMLList->data(sel);
	MakeConfig();
	if (NULL != pDMLConfig && NULL != pCFGList)
	{
		int loaded = FMDML_RET_ERR;
		char *data;
		{
			char path[MAX_PATH_BUF];
			SetDMLPath(e, path, sizeof(path));
			loaded = ReadFileIntoBuffer(path, &data, NULL);
		}
		if (FMDML_RET_ERR != loaded)
		{
			if (!IsDMLHeaderValid(data))
			{
				fl_alert("The DML to be modified is not valid.");
				delete[] data;
				return;
			}
			char *match = data;
			while (NULL != (match = strstr(match, "\r\n" SEC_KEY)))
			{
				char *match2 = strstr(match + 2 + SEC_KEY_LEN, "\r\n");
				int enabled = 1;
				if (NULL != match2)
				{
					if (!strncmp(match2 + 2, CMT_BEGIN "\r\n",
						CMT_BEGIN_LEN + 2))
						enabled = 0;
					*match2 = '\0';
				}
				pCFGList->add(match + 2 + SEC_KEY_LEN, enabled);
				if (NULL == match2)
					break;
				else
				{
					*match2 = '\r';
					match = match2 + 2;
				}

			}
			delete[] data;
			// Center the window on the main window.
			pDMLConfig->position(
				pMainWnd->x() + ((pMainWnd->w() - pDMLConfig->w()) / 2),
				pMainWnd->y() + ((pMainWnd->h() - pDMLConfig->h()) / 2));
			pDMLConfig->show();
		}
		else
			fl_alert("Cannot configure empty or missing DML.");
	}
}

static void OnSelect(Fl_Widget *o, void *p)
{
	OnConfigure(o, p);
}

static void OnToggle(Fl_Widget *, void *)
{
	const int sel = pDMLList->value();
	if (0 == sel)
	{
		fl_message("Please select a DML before attempting to activate or"
			" deactivate.");
		return;
	}
	DMLEntry *e = (DMLEntry *) pDMLList->data(sel);
	const size_t fnameLen = strlen(e->fname);
	if (!e->enabled && fnameLen >= DIS_SUF_LEN
		&& strcmp(e->fname + fnameLen - DIS_SUF_LEN, DIS_SUF))
	{
		fl_alert("Disabled DML has incorrect suffix.");
		return;
	}
	char path[MAX_PATH_BUF];
	char newPath[MAX_PATH_BUF];
	SetDMLPath(e, path, sizeof(path));
	const size_t pathLen = strlen(path);
	if (e->enabled && pathLen + DIS_SUF_LEN + 1 > MAX_PATH_BUF)
	{
		fl_alert("Path of DML to be disabled is too long.");
		return;
	}
	char *newName = new char[pathLen + 1 +
		(e->enabled ? DIS_SUF_LEN : -DIS_SUF_LEN)];
	if (NULL == newName)
	{
		fl_alert("Cannot allocate temporary buffer.");
		return;
	}
	const char *line = pDMLList->text(sel);
	char *newLine = new char[strlen(line) + 1];
	if (NULL == newLine)
	{
		delete[] newName;
		fl_alert("Cannot allocate temporary buffer.");
		return;
	}
	strcpy(newLine, line);
	if (e->enabled)
	{
		strcpy(newPath, path);
		strcpy(newName, e->fname);
		strcat(newPath, DIS_SUF);
		strcat(newName, DIS_SUF);
		newLine[1] = '-';
	}
	else
	{
		const size_t nameLen = strlen(e->fname);
		memcpy(newPath, path, pathLen - DIS_SUF_LEN);
		newPath[pathLen - DIS_SUF_LEN] = '\0';
		memcpy(newName, e->fname, nameLen - DIS_SUF_LEN);
		newName[nameLen - DIS_SUF_LEN] = '\0';
		newLine[1] = '*';
	}
	fl_rename(path, newPath);
	delete[] e->fname;
	e->fname = newName;
	pDMLList->text(sel, newLine);
	e->enabled = !e->enabled;
	delete[] newLine;
}

static void OnSearch(Fl_Widget *, void *)
{
	// Unselect the currently selected line.
	const int sel = pDMLList->value();
	if (0 != sel)
		pDMLList->select(sel, 0);
	// Show only lines matching the query.
	const char *query = pDMLSearch->value();
	for (int i = 1; i <= pDMLList->size(); i++)
	{
		const int matches = (NULL == query || *query == '\0'
			|| NULL != stristr(pDMLList->text(i), query));
		if (pDMLList->visible(i) && !matches)
			pDMLList->hide(i);
		else if (!pDMLList->visible(i) && matches)
			pDMLList->show(i);
	}
	// Reset the scrollbar position
	pDMLList->topline(1);
}

static void OnExit(Fl_Widget *, void *)
{
	pMainWnd->hide();
}

/////////////////////////////////////////////////////////////////////
// CONFIGURATION

static void OnConfigChanged(Fl_Widget *, void *)
{
	const int sel = pCFGList->value();
	const int opt = pDMLList->value();
	if (0 == sel || 0 == opt)
	{
		fl_alert("Cannot retrieve changed option.");
		return;
	}
	const size_t keyLen = strlen(pCFGList->text(sel)) + 2 + SEC_KEY_LEN;
	char *key = new char[keyLen + 1];
	if (NULL == key)
	{
		fl_alert("Cannot allocate temporary buffer.");
		return;
	}
	strcpy(key, "\r\n" SEC_KEY);
	strcat(key, pCFGList->text(sel));
	char path[MAX_PATH_BUF];
	SetDMLPath((DMLEntry *) pDMLList->data(opt), path, sizeof(path));
	char *data;
	size_t bytesRead;
	if (FMDML_RET_ERR != ReadFileIntoBuffer(path, &data, &bytesRead,
		CMT_BEGIN_LEN + CMT_END_LEN + 4))
	{
		if (!IsDMLHeaderValid(data))
		{
			delete[] key;
			delete[] data;
			fl_alert("The DML to be modified is not valid.");
			return;
		}
		const char *begin = CMT_BEGIN "\r\n";
		const char *end = CMT_END "\r\n";
		char *match = strstr(data, key);
		if (NULL != match && !strncmp(match + keyLen, "\r\n", 2))
		{
			match += keyLen + 2;
			if (!pCFGList->checked(sel))
			{
				const size_t matchLen = strlen(match);
				if (0 != matchLen)
					memmove(match + CMT_BEGIN_LEN + 2, match, matchLen);
				memcpy(match, begin, CMT_BEGIN_LEN + 2);
				match[matchLen + CMT_BEGIN_LEN + 2] = '\0';
				char *match2 = strstr(match, "\r\n" SEC_KEY);
				if (NULL == match2)
					strcpy(match + matchLen + CMT_BEGIN_LEN + 2, end);
				else
				{
					match2 += 2;
					const size_t matchLen2 = strlen(match2);
					if (0 != matchLen2)
						memmove(match2 + CMT_END_LEN + 2, match2, matchLen2);
					memcpy(match2, end, CMT_END_LEN + 2);
					match2[matchLen2 + CMT_END_LEN + 2] = '\0';
				}
			}
			else if (!strncmp(match, begin, CMT_BEGIN_LEN + 2))
			{
				const size_t matchLen = strlen(match) - CMT_BEGIN_LEN - 2;
				if (0 != matchLen)
					memmove(match, match + CMT_BEGIN_LEN + 2, matchLen);
				match[matchLen] = '\0';
				char *match2 = strstr(match, end);
				if (NULL != match2)
				{
					const size_t matchLen2 = strlen(match2) - CMT_END_LEN - 2;
					if (0 != matchLen2)
						memmove(match2, match2 + CMT_END_LEN + 2, matchLen2);
					match2[matchLen2] = '\0';
				}
			}
			FILE *f = fl_fopen(path, "wb");
			if (NULL != f)
			{
				fwrite(data, sizeof(char), strlen(data) / sizeof(char), f);
				fclose(f);
			}
			else
				fl_alert("Cannot write to DML.");
		}
		else
			fl_alert("Cannot find requested DML section.");
		delete[] data;
	}
	else
		fl_alert("Cannot modify empty or missing DML.");
	delete[] key;
}

static void OnConfigDone(Fl_Widget *o, void *p)
{
	pDMLConfig->hide();
	OnConfigClose(o, p);
}

static void OnConfigClose(Fl_Widget *, void *)
{
	delete pDMLConfig;
	pDMLConfig = NULL;
}

/////////////////////////////////////////////////////////////////////

int main(int argc, char **argv)
{
	// Parse command line arguments.
#ifdef DEF_THEME
#define DEF_THEME_S(s) DEF_THEME_S_(s)
#define DEF_THEME_S_(s) #s
	char theme[8] = DEF_THEME_S(DEF_THEME);
#undef DEF_THEME_S
#undef DEF_THEME_S_
	if (HasCommandLineOption(argc, argv, "-theme_gtk"))
		strcpy(theme, "gtk+");
	else
#else
	char theme[8] = "gtk+";
#endif
	if (HasCommandLineOption(argc, argv, "-theme_dark"))
		strcpy(theme, "dgtk+");
	else if (HasCommandLineOption(argc, argv, "-theme_plastic"))
		strcpy(theme, "plastic");
	else if (HasCommandLineOption(argc, argv, "-theme_base"))
		strcpy(theme, "base");
	if (GetCommandLineInt(argc, argv, "-scale", &g_scale))
	{
		g_scale += 3;
		if (g_scale < 4)
			g_scale = 4;
		else if (g_scale > 8)
			g_scale = 8;
	}
	InitFLTK(theme);
#ifdef _WIN32
	const bool useCWD = !HasCommandLineOption(argc, argv, "-select_dir");
#else
	const bool useCWD = HasCommandLineOption(argc, argv, "-cwd");
#endif
	if (FMDML_RET_ERR == ChangeCurrentDir(useCWD))
		return FMDML_RET_ERR;
	if (4 != g_scale)
		Fl::scrollbar_size(SCALE(Fl::scrollbar_size()));
	MakeWindow();
	if (NULL != pMainWnd && NULL != pDMLList)
	{
		GetDMLs();
		// Center the main window.
		pMainWnd->position(
			Fl::x() + ((Fl::w() - pMainWnd->w()) / 2),
			Fl::y() + ((Fl::h() - pMainWnd->h()) / 2));
		pMainWnd->show();
		Fl::run();
		ClearDMLs();
	}
	if (NULL != pMainWnd)
		delete pMainWnd;
	return FMDML_RET_SUCCESS;
}

/////////////////////////////////////////////////////////////////////

static bool HasCommandLineOption(int argc, char **argv, const char *option)
{
	for (int i = 1; i < argc; i++)
	{
#ifdef _WIN32
		if (!stricmp(argv[i], option))
#else
		if (!strcasecmp(argv[i], option))
#endif
			return true;
	}
	return false;
}

static bool GetCommandLineInt(int argc, char **argv, const char *option,
	int *val)
{
	for (int i = 1; i < argc; i++)
	{
#if _WIN32
		if (!stricmp(argv[i], option) && argc > i + 1
			&& isdigit(argv[i + 1][0]))
#else
		if (!strcasecmp(argv[i], option) && argc > i + 1
			&& isdigit(argv[i + 1][0]))
#endif
		{
			*val = atoi(argv[i + 1]);
			return true;
		}
	}
	return false;
}

static void InitFLTK(const char *theme)
{
	if (*theme == 'd')
	{
		const unsigned int dark_cmap[42] = {
#include "dark_cmap.h"
		};
		unsigned int c, i = 0;
#define SETCLR(_x,_y) Fl::set_color((Fl_Color)_x,dark_cmap[_y++])
		for (c = FL_FOREGROUND_COLOR; c < FL_FOREGROUND_COLOR + 16; c++)
			SETCLR(c, i); // 3-bit colormap
		for (c = FL_GRAY0; c <= FL_BLACK; c++)
			SETCLR(c, i); // grayscale ramp and FL_BLACK
		SETCLR(FL_WHITE, i); // FL_WHITE
#undef SETCLR
		Fl::scheme(theme + 1);
	}
	else
		Fl::scheme(theme);
	if (4 != g_scale)
		FL_NORMAL_SIZE = SCALE(FL_NORMAL_SIZE);
}

static void SetDMLDir(const short misnum, char *path)
{
	switch (misnum)
	{
		case FMDML_GAM:
			strcpy(path, ".");
			break;
		case FMDML_GLOBAL_GAM:
			strcpy(path, "." DIRSEP "dbmods");
			break;
		default: // > 0
#ifdef _WIN32
			_snprintf_s(path, 20, _TRUNCATE, "." DIRSEP "dbmods" DIRSEP
				"miss%hd.mis", misnum);
#else
			snprintf(path, 20, "." DIRSEP "dbmods" DIRSEP "miss%hd.mis",
				misnum);
#endif
			break;
	}
}

static void SetDMLPath(const DMLEntry *e, char *path, const size_t pathSize)
{
	SetDMLDir(e->misnum, path);
	if (strlen(path) + strlen(e->fname) + 2 > pathSize)
		return;
	strcat(path, DIRSEP);
	strcat(path, e->fname);
}

static bool IsDMLHeaderValid(char *header)
{
	return !strncmp(header, "DML1", 4);
}

static void GetSortName(char **name)
{
	if (!strncmp(*name, "The ", 4))
		*name += 4;
	else if (!strncmp(*name, "An ", 3))
		*name += 3;
	else if (!strncmp(*name, "A ", 2))
		*name += 2;
}

static int ChangeCurrentDir(bool useBinDir)
{
	int ret = -1;
	if (useBinDir)
	{
#ifdef _WIN32
		WCHAR path[MAX_PATH_BUF];
		if (0 == GetModuleFileNameW(NULL, path, MAX_PATH_BUF))
			return FMDML_RET_ERR;
		LPWSTR sep = wcsrchr(path, '\\');
		// NOTE: There should always be a directory separator, though there does
		// not necessarily need to be one in this case.
		if (NULL != sep)
			*sep = '\0';
		ret = _wchdir(path);
#else
		char path[MAX_PATH_BUF];
		ssize_t bytesWritten;
#if defined(__linux__) || defined(__LINUX__)
		if (-1 == (bytesWritten = readlink("/proc/self/exe", path,
			MAX_PATH_BUF - 1)))
			return FMDML_RET_ERR;
#elif defined(__unix__) || defined(__UNIX__) \
		|| (defined(__APPLE__) && defined(__MACH__))
#include <sys/param.h>
#if defined(BSD)
		if (-1 == (bytesWritten = readlink("/proc/curproc/file", path,
			MAX_PATH_BUF - 1)))
			return FMDML_RET_ERR;
#else
#error "Cannot get binary path on target. See ChangeToBinDir for details."
#endif
#else
#error "Cannot get binary path on target. See ChangeToBinDir for details."
#endif
		path[bytesWritten] = '\0';
		char *sep = strrchr(path, '/');
		// NOTE: See previous.
		if (NULL != sep)
			*sep = '\0';
		ret = chdir(path);
#endif
	}
	else
	{
		int fontSize = FL_NORMAL_SIZE;
		if (fontSize > 18)
			FL_NORMAL_SIZE = 18;
		char *selDir = fl_dir_chooser("Select T2FMDML Directory", NULL, 0);
		FL_NORMAL_SIZE = fontSize;
		if (NULL != selDir)
#ifdef _WIN32
		{
			const size_t dirLen = strlen(selDir);
			const size_t dirLenW = fl_utf8toUtf16(selDir, dirLen, NULL, 0) + 1;
			LPWSTR selDirW = new WCHAR[dirLenW];
			if (NULL != selDirW)
			{
				fl_utf8toUtf16(selDir, dirLen, (unsigned short *) selDirW,
					dirLenW);
				ret = _wchdir(selDirW);
				delete[] selDirW;
			}
		}
#else
			ret = chdir(selDir);
#endif
	}
	return (0 == ret) ? FMDML_RET_SUCCESS : FMDML_RET_ERR;
}

static int ReadFileIntoBuffer(const char *name, char **data, size_t *len,
	const size_t extraSize)
{
	int ret = FMDML_RET_ERR;
	FILE *f = fl_fopen(name, "rb");
	if (NULL != f)
	{
#ifdef _WIN32
		const int n = _filelength(_fileno(f));
#else
		fseek(f, 0, SEEK_END);
		const int n = ftell(f);
		fseek(f, 0, SEEK_SET);
#endif
		if (n > 0 && NULL != (*data = new char[n + extraSize + 1]))
		{
			const size_t bytesRead = fread(*data, sizeof(char),
				n / sizeof(char), f);
			(*data)[bytesRead] = '\0';
			if (NULL != len)
				*len = bytesRead;
			ret = FMDML_RET_SUCCESS;
		}
		fclose(f);
	}
	return ret;
}

static void GetDMLs(void)
{
	char header[HEADER_BUF];
	char path[MAX_PATH_BUF];
	for (short i = FMDML_GAM; i < 100; i++)
	{
		SetDMLDir(i, path);
		if (!fl_filename_isdir(path))
			continue;
		const size_t pathLen = strlen(path);
		dirent **files;
		int nFiles = fl_filename_list(path, &files, NULL);
		for (int j = 0; j < nFiles; j++)
		{
			path[pathLen] = '\0';
			dirent *fEntry = files[j];
			if (pathLen + strlen(fEntry->d_name) + 2 > MAX_PATH_BUF
				|| fEntry->d_name[0] == '.')
				continue;
			strcat(path, DIRSEP);
			strcat(path, fEntry->d_name);
			FILE *f;
			if (NULL == (f = fl_fopen(path, "rb")))
				continue;
			const size_t bytesRead = fread(header, sizeof(char),
				sizeof(header) / sizeof(char) - 1, f);
			fclose(f);
			header[bytesRead] = '\0';
			if (!IsDMLHeaderValid(header))
				continue;
			char *name = strstr(header, "\r\n" DML_KEY);
			if (NULL == name)
				continue;
			name += 2 + DML_KEY_LEN - 4;
			memmove(header, name, strlen(name) + 1); // Move back in the buffer.
			name = header;
			// Construct the display name.
			name[0] = '[';
			name[2] = ']';
			name[3] = ' ';
			for (char *c = name; *c != '\0'; c++)
			{
				if (iscntrl(*c) || !strncmp(c, " /", 2)
					|| !strncmp(c, " by ", 4))
				{
					switch (i)
					{
						// NOTE: In the first two cases, the header buffer must
						// be large enough to accomodate the appended strings.
						case FMDML_GAM:
							if (HEADER_BUF - (c - name) >= 10)
							{
								strcpy(c, " (Gamesys)");
								*(c + 10) = '\0';
							}
							else
								*c = '\0';
							break;
						case FMDML_GLOBAL_GAM:
							if (HEADER_BUF - (c - name) >= 17)
							{
								strcpy(c, " (Global Gamesys)");
								*(c + 17) = '\0';
							}
							else
								*c = '\0';
							break;
						default: // > 0
							*c = '\0';
							break;
					}
					break;
				}
			}
			// Determine where the new entry should be placed. The list is
			// sorted alphabetically. ignoring common English articles.
			char *sortName = name + 4;
			GetSortName(&sortName);
			int line = 1;
			while (line <= pDMLList->size())
			{
				char *lineName = ((char *) pDMLList->text(line)) + 4;
				GetSortName(&lineName);
				if (strcmp(sortName, lineName) > 0)
					line++;
				else
					break;
			}
			// Add DML to list and create an entry for it.
			char *fname = new char[strlen(fEntry->d_name) + 1];
			if (NULL == fname)
				continue;
			DMLEntry *e = new DMLEntry;
			if (NULL == e)
			{
				delete[] fname;
				continue;
			}
			strcpy(fname, fEntry->d_name);
			e->misnum = i;
			e->fname = fname;
			const size_t fnameLen = strlen(fname);
			if (fnameLen >= DIS_SUF_LEN
				&& !strcmp(fname + fnameLen - DIS_SUF_LEN, DIS_SUF))
			{
				e->enabled = false;
				name[1] = '-';
			}
			else
			{
				e->enabled = true;
				name[1] = '*';
			}
			pDMLList->insert(line, name, e);
		}
		fl_filename_free_list(&files, nFiles);
	}
}

static void ClearDMLs(void)
{
	for (int i = 1; i <= pDMLList->size(); i++)
	{
		DMLEntry *e = (DMLEntry *) pDMLList->data(i);
		delete[] e->fname;
		delete e;
	}
}

