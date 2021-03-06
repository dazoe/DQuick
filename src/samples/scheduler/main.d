module dquick.samples.scheduler.main;

import dquick.algorithms.scheduler;
import std.stdio;
import core.time;

version(Posix)
{
	// TODO remove that, it's normally linked with DQuick
	pragma(lib, "dl");	// dl functions aren't linked by default with dmd
}

class SomeTask
{
	void execute(Duration time, Duration step, ulong iter)
	{
		writeln("SomeTask.execute: time=", time, ", step=", step, ", iter=", iter);
	}
}

void main()
{
	Scheduler sched = new Scheduler();
	
	SomeTask task = new SomeTask();
	sched.addTask(Duration.zero, dur!"msecs"(500), 5, &task.execute);
	
	while((TickDuration.currSystemTick - TickDuration.appOrigin).seconds < 3)
	{
		// do something complex...
	}
	
	sched.destroy();
}
