module dquick.script.iItemBinding;

import dquick.script.dmlEngineCore;
import derelict.lua.lua;

interface IItemBinding {
	dquick.script.dmlEngineCore.DMLEngineCore	dmlEngine();
	void										dmlEngine(dquick.script.dmlEngineCore.DMLEngineCore);
	void	executeBindings();
	static if (dquick.script.dmlEngineCore.DMLEngineCore.showDebug)
	{
		string	displayDependents();
		string	displayDependencies();
	}
	void	createItemBindingLuaEnv();
	bool	creating();
	void	valueFromLua(lua_State* L);
	void	valuesFromLuaTable(lua_State* L);
	void	pushToLua(lua_State* L);
	int		itemBindingLuaEnvDummyClosureReference();

	string	id();
}
