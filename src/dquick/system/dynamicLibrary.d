module dquick.system.dynamic_library;

import dquick.utils.utils;

import core.runtime;
import std.string;
import std.stdio;

version (Windows)
{
	private import std.c.windows.windows;
}
else
{
	private import std.c.linux.linux;
	pragma(lib, "dl");	// dl functions aren't linked by default with dmd
}

struct DynamicLibrary
{
public:
	~this()
	{
		debug destructorAssert(mLibrary is null, "DynamicLibrary.unload method wasn't called.", mTrace);
	}

	bool	load(string name)
	{
		debug mTrace = defaultTraceHandler(null);

		unload();
		version(Windows)
		{
			mLibrary = LoadLibraryA(name.toStringz);
		}
		else
		{
			mLibrary = dlopen(name.toStringz, RTLD_NOW);
		}
		return (mLibrary != null);
	}

	void	unload()
	{
		version(Windows)
		{
			if (mLibrary)
				FreeLibrary(mLibrary);
		}
		else
		{
			if (mLibrary)
				dlclose(mLibrary);
		}
		mLibrary = null;
	}

	void*	functionAddress(string functionName)	// TODO find a way to generate methods will throw exceptions instead of just returning a null ptr
	{
		version(Windows)
		{
			FARPROC	symbol = GetProcAddress(mLibrary, functionName.toStringz);
		}
		else
		{
			void*	symbol = dlsym(mLibrary, functionName.toStringz);
		}
		if (symbol is null) {	// TODO Generate a function that will throw a specific msg with the name of the expected function
			writeln("Failed to load function address " ~ functionName ~ ".");
		}
		return symbol;
	}

private:
	void*	mLibrary = null;

	debug Throwable.TraceInfo	mTrace;
}
