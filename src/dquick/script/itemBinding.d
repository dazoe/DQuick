module dquick.script.itemBinding;

public import std.traits;
public import std.typetuple;
public import std.string;
import std.stdio;
import std.signals;
public import std.conv;
public import derelict.lua.lua;
public import std.c.string;

import dquick.script.nativePropertyBinding;
import dquick.script.virtualPropertyBinding;
import dquick.script.delegatePropertyBinding;
import dquick.script.dmlEngine;
public import dquick.script.utils;
public import dquick.script.dmlEngineCore;

static string	I_ITEM_BINDING()
{
	return BASE_ITEM_BINDING() ~ q"(
	)";
}

static string	ITEM_BINDING()
{
	return BASE_ITEM_BINDING() ~ q"(
		override string	id()
		{
			return this.item.id;
		}
	)";
}


static string	BASE_ITEM_BINDING()
{
	return q"(
		static if (__traits(hasMember, typeof(this), "mDMLEngine") == false)
			dquick.script.dmlEngineCore.DMLEngineCore	mDMLEngine;

		override dquick.script.dmlEngineCore.DMLEngineCore	dmlEngine() {return mDMLEngine;};
		override void	dmlEngine(dquick.script.dmlEngineCore.DMLEngineCore dmlEngine)
		{
			assert(mDMLEngine is null || mDMLEngine is dmlEngine);
			if (mDMLEngine != dmlEngine)
			{
				if (id == "")
					__traits(getMember, this, "idProperty").value(format("%s_%x", typeid(this), cast(void*)this));
				mDMLEngine = dmlEngine;
				static if (__traits(hasMember, this, "item") == true)
				{
					DMLEngine	dmlEngine2 = cast(DMLEngine)mDMLEngine;
					assert(dmlEngine2, "An ItemBinding can only works with a DMLEngine");
					dmlEngine2.registerItem!T(item, this);
				}
				createItemBindingLuaEnv();
			}
		}

		override void	createItemBindingLuaEnv()
		{
			// Create new _ENV table with lookup function to handle this and parent
			string	lua = q"(
				local __itemBinding_env = {
				}
				local __itemBinding_env_mt = {
					__index = function (_, n)
						--for key,value in pairs(_) do print(key,value) end
						--print("n = "..n)
						if n == "this" then
							return rawget(_, n)
						else 
							local itemMemberVal = rawget(_, "this")[n];
							if itemMemberVal == nil then
								return _ENV[n]
							else
								return itemMemberVal
							end
						end
					end,
					__newindex = function (_, n, v)
						assert(n ~= "this")
						local this = rawget(_, "this")
						if this[n] == nil then
							_ENV[n] = v
						else
							this[n] = v
						end
					end
				}
				setmetatable(__itemBinding_env, __itemBinding_env_mt)
				__itemBinding_env_global = __itemBinding_env

				__itemBinding_dummy_closure_global = function()
					return __itemBinding_env
				end
			)";
			dmlEngine.load(lua, "ItemBindingLuaEnv");

			// Put component env
			lua_rawgeti(dmlEngine.luaState, LUA_REGISTRYINDEX, dmlEngine.currentLuaEnv);
			const char*	envUpvalue = lua_setupvalue(dmlEngine.luaState, -2, 1);
			if (envUpvalue == null) // No access to env, env table is still on the stack so we need to pop it
				lua_pop(dmlEngine.luaState, 1);

			dmlEngine.execute();

			// Get new env table
			lua_rawgeti(dmlEngine.luaState, LUA_REGISTRYINDEX, dmlEngine.currentLuaEnv);
			lua_pushstring(dmlEngine.luaState, "__itemBinding_env_global");
			lua_rawget(dmlEngine.luaState, -2); // Raw get without calling index metamethod to not get parent components values

			// set this into env
			lua_pushstring(dmlEngine.luaState, "this");
			pushToLua(dmlEngine.luaState);
			lua_rawset(dmlEngine.luaState, -3);
			lua_pop(dmlEngine.luaState, 1);

			// Get dummy closure
			lua_pushstring(dmlEngine.luaState, "__itemBinding_dummy_closure_global");
			lua_rawget(dmlEngine.luaState, -2); // Raw get without calling index metamethod to not get parent components values

			mItemBindingLuaEnvDummyClosureReference = luaL_ref(dmlEngine.luaState, LUA_REGISTRYINDEX);

			lua_pop(dmlEngine.luaState, 1);
		}

		static if (__traits(hasMember, typeof(this), "mCreating") == false)
			bool	mCreating;
		override bool	creating() {return mCreating;}

		static if (__traits(hasMember, typeof(this), "virtualProperties") == false)
			public dquick.script.virtualPropertyBinding.VirtualPropertyBinding[string]	virtualProperties;

		override void	executeBindings()
		{
			foreach (member; __traits(allMembers, typeof(this)))
			{
				static if (is(typeof(__traits(getMember, this, member)) : dquick.script.propertyBinding.PropertyBinding))
				{
					assert(__traits(getMember, this, member) !is null, format("[%s].%s is null", id, member));
					__traits(getMember, this, member).executeBinding();
				}
			}
			foreach (member; virtualProperties)
				member.executeBinding();
		}

		static if (dquick.script.dmlEngine.DMLEngine.showDebug)
		{
			override string	displayDependents()
			{
				string	result;
				result ~= format("native properties:\n");
				foreach (member; __traits(allMembers, typeof(this)))
				{
					static if (is(typeof(__traits(getMember, this, member)) : dquick.script.propertyBinding.PropertyBinding))
					{
						assert(__traits(getMember, this, member) !is null);
						result ~= shiftRight(format("%s's dependents:\n", __traits(getMember, this, member).propertyName), "\t", 1);
						result ~= shiftRight(__traits(getMember, this, member).displayDependents(), "\t", 2);
					}
				}
				result ~= format("virtual properties:\n");
				foreach (key, virtualProperty; virtualProperties)
				{
					result ~= shiftRight(format("%s's dependents:\n", key), "\t", 1);
					result ~= shiftRight(virtualProperty.displayDependents(), "\t", 2);
				}
				return result;
			}
			override string	displayDependencies()
			{
				string	result;
				result ~= format("native properties:\n");
				foreach (member; __traits(allMembers, typeof(this)))
				{
					static if (is(typeof(__traits(getMember, this, member)) : dquick.script.propertyBinding.PropertyBinding))
					{
						assert(__traits(getMember, this, member) !is null);
						result ~= shiftRight(format("%s's dependencies:\n", __traits(getMember, this, member).propertyName), "\t", 1);
						result ~= shiftRight(__traits(getMember, this, member).displayDependencies(), "\t", 1);
					}
				}
				result ~= format("virtual properties:\n");
				foreach (key, virtualProperty; virtualProperties)
				{
					result ~= shiftRight(format("%s's dependencies:\n", key), "\t", 1);
					result ~= shiftRight(virtualProperty.displayDependencies(), "\t", 1);
				}
				return result;
			}
		}

		override void	valueFromLua(lua_State* L)
		{
			if (lua_type(L, -2) == LUA_TSTRING)
			{
				string	key = to!(string)(lua_tostring(L, -2));

				bool	found = false;
				foreach (member; __traits(allMembers, typeof(this)))
				{
					static if (is(typeof(__traits(getMember, this, member)) : dquick.script.propertyBinding.PropertyBinding))
					{
						if (__traits(getMember, this, member) is null)
							throw new Exception(format("property \"%s\" is null, you must instanciate it", getPropertyNameFromPropertyDeclaration(member)));

						if (key == getPropertyNameFromPropertyDeclaration(member))
						{
							found = true;
							__traits(getMember, this, member).bindingFromLua(L, -1);
							break;
						}
						else if (key == getSignalNameFromPropertyName(getPropertyNameFromPropertyDeclaration(member)))
						{
							found = true;

							if (lua_isfunction(L, -1))
							{
								// Set _ENV upvalue
								const char*	upvalue = lua_getupvalue(L, -1, 1);
								if (upvalue != null)
								{
									lua_pop(L, 1);
									if (strcmp(upvalue, "_ENV") == 0)
									{					
										lua_rawgeti(L, LUA_REGISTRYINDEX, itemBindingLuaEnvDummyClosureReference);
										lua_upvaluejoin(L, -2, 1, -1, 1);
										lua_pop(L, 1);
									}
								}

								__traits(getMember, this, member).slotLuaReference = luaL_ref(L, LUA_REGISTRYINDEX);
								lua_pushnil(L); // To compensate the value poped by luaL_ref
							}
							else
								throw new Exception(format("attribute \"%s\" is a %s, a function was expected", key, getLuaTypeName(L, -1)));
							break;
						}
					}
				}

				if (found == false)
				{
					auto	propertyName = getPropertyNameFromSignalName(key);
					if (propertyName != "")
					{
						found = true;

						if (lua_isfunction(L, -1))
						{
							dquick.script.virtualPropertyBinding.VirtualPropertyBinding virtualProperty;
							auto virtualPropertyPtr = (propertyName in this.virtualProperties);
							if (!virtualPropertyPtr)
							{
								virtualProperty = new dquick.script.virtualPropertyBinding.VirtualPropertyBinding(this, propertyName);
								this.virtualProperties[propertyName] = virtualProperty;
							}
							else
							{
								virtualProperty = *virtualPropertyPtr;
							}
							// Set _ENV upvalue
							const char*	upvalue = lua_getupvalue(L, -1, 1);
							if (upvalue != null)
							{
								lua_pop(L, 1);
								if (strcmp(upvalue, "_ENV") == 0)
								{					
									lua_rawgeti(L, LUA_REGISTRYINDEX, itemBindingLuaEnvDummyClosureReference);
									lua_upvaluejoin(L, -2, 1, -1, 1);
									lua_pop(L, 1);
								}
							}

							virtualProperty.slotLuaReference = luaL_ref(L, LUA_REGISTRYINDEX);
							lua_pushnil(L); // To compensate the value poped by luaL_ref
						}
						else
							throw new Exception(format("attribute \"%s\" is a %s, a function was expected", key, getLuaTypeName(L, -1)));
					}
					else
					{
						dquick.script.virtualPropertyBinding.VirtualPropertyBinding virtualProperty;
						auto virtualPropertyPtr = (key in this.virtualProperties);
						if (!virtualPropertyPtr)
						{
							virtualProperty = new dquick.script.virtualPropertyBinding.VirtualPropertyBinding(this, key);
							this.virtualProperties[key] = virtualProperty;
						}
						else
						{
							virtualProperty = *virtualPropertyPtr;
						}
						virtualProperty.bindingFromLua(L, -1);
					}
				}
			}
			else if (lua_type(L, -2) == LUA_TNUMBER)
			{
				if (lua_isuserdata(L, -1) == false)
					throw new Exception(format("attribute \"%d\" is a %s, an item was expected", lua_tointeger(L, -2), getLuaTypeName(L, -1)));

				dquick.script.iItemBinding.IItemBinding	child;
				dquick.script.utils.valueFromLua!(dquick.script.iItemBinding.IItemBinding)(L, -1, child);
				if (child is null)
					throw new Exception(format("attribute \"%d\" is not an item", lua_tointeger(L, -2)));

				static if (__traits(hasMember, this, "addChild") == true)
				{
					// Search in the ItemBinding
					foreach (overload; __traits(getOverloads, typeof(this), "addChild")) 
					{
						alias ParameterTypeTuple!(overload) MyParameterTypeTuple;
						static if (MyParameterTypeTuple.length == 1)
						{
							MyParameterTypeTuple[0]	castedItemBinding = cast(MyParameterTypeTuple[0])(child);
							if (castedItemBinding !is null)
							{
								__traits(getMember, this, "addChild")(castedItemBinding);
								goto AfterError;
							}
						}
					}
					// Search in the item
					static if (__traits(hasMember, this, "item") == true)
					{
						static if (__traits(hasMember, item, "addChild") == true)
						{
							foreach (overload; __traits(getOverloads, typeof(item), "addChild")) 
							{
								alias ParameterTypeTuple!(overload) MyParameterTypeTuple;
								static if (MyParameterTypeTuple.length == 1)
								{
									MyParameterTypeTuple[0]	castedItemBinding = cast(MyParameterTypeTuple[0])(child);
									if (castedItemBinding !is null)
									{
										__traits(getMember, item, "addChild")(castedItemBinding);
										goto AfterError;
									}
								}
							}
						}
					}
				}
				throw new Exception(format("can't add item at key \"%d\" as child without an appropriate addChild method", lua_tointeger(L, -2)));
				AfterError: {}
			}
		}

		override void	valuesFromLuaTable(lua_State* L)
		{
			if (!lua_istable(L, -1))
				throw new Exception("the lua value is not a table\n");

			// No property binding or slot call while the item is in creation to ensure there is no particular initialisation order between properties of an object
			mCreating = true;

			/* table is in the stack at index 't' */
			lua_pushnil(L);  /* first key */
			while (lua_next(L, -2) != 0) {
				/* uses 'key' (at index -2) and 'value' (at index -1) */
				valueFromLua(L);

				/* removes 'value'; keeps 'key' for next iteration */
				lua_pop(L, 1);
			}
			lua_pop(L, 1); // Remove param 1 (table)

			mCreating = false;
		}

		override void pushToLua(lua_State* L)
		{
			dquick.script.utils.valueToLua!(typeof(this))(L, this);
		}

		static if (__traits(hasMember, typeof(this), "mItemBindingLuaEnvDummyClosureReference") == false)
			int	mItemBindingLuaEnvDummyClosureReference;
		override int	itemBindingLuaEnvDummyClosureReference()
		{
			return mItemBindingLuaEnvDummyClosureReference;
		}
	)";
}

static string	genProperties(T)()
{
	string result = "";

	foreach (member; __traits(allMembers, T))
	{
		static if (__traits(compiles, PropertyType!(T, member)))
		{
			alias PropertyType!(T, member)	MyPropertyType;
			static if (is(MyPropertyType == void) == false) // Property
			{
				static if (__traits(compiles, fullyQualifiedName2!(MyPropertyType)) && // Hack because of a bug in fullyQualifiedName
						   member != "__ctor") 
				{
					static if (is(MyPropertyType : Object))
					{
										
						result ~= format("	void															__%s(%s value) {
												if (!(value is null && ____%sItemBinding is null) && !(____%sItemBinding && value is ____%sItemBinding.item))
												{
													if (____%sItemBinding)
														(cast(dquick.script.dmlEngine.DMLEngine)dmlEngine).unregisterItem!(%s)(____%sItemBinding.item);
													if (value)
														____%sItemBinding = (cast(dquick.script.dmlEngine.DMLEngine)dmlEngine).registerItem!(%s)(value);
													else
														____%sItemBinding = null;
													__%s.emit(____%sItemBinding);
												}																
											}
											",
											getSignalNameFromPropertyName(member), fullyQualifiedName2!(MyPropertyType),
											member, member, member,
											member,
											fullyQualifiedName2!(MyPropertyType), member,
											member, fullyQualifiedName2!(MyPropertyType),
											member,
											getSignalNameFromPropertyName(member~"ItemBinding"), member);	// Item Signal

						result ~= format("	dquick.script.itemBinding.ItemBinding!(%s)					____%sItemBinding;\n", fullyQualifiedName2!(MyPropertyType), member); // ItemBinding
						result ~= format("	dquick.script.itemBinding.ItemBinding!(%s)					__%sItemBinding() {
												return ____%sItemBinding;
											}
											",
											fullyQualifiedName2!(MyPropertyType), member,
											member); // ItemBinding Getter
						result ~= format("	void															__%sItemBinding(dquick.script.itemBinding.ItemBinding!(%s) value) {
												if (value != ____%sItemBinding)
												{
													if (____%sItemBinding !is null)
														(cast(dquick.script.dmlEngine.DMLEngine)dmlEngine).unregisterItem!(%s)(____%sItemBinding.item);
														____%sItemBinding = value;
													if (____%sItemBinding !is null)
													{
														(cast(dquick.script.dmlEngine.DMLEngine)dmlEngine).registerItem!(%s)(____%sItemBinding.item);
														item.%s = value.item;
													}
													else
													{
														item.%s = null;
													}
													__%s.emit(value);
												}
											}
											",
											member, fullyQualifiedName2!(MyPropertyType),
											member,
											member,
											fullyQualifiedName2!(MyPropertyType), member,
											member,
											member,
											fullyQualifiedName2!(MyPropertyType), member,
											member,
											member,
											getSignalNameFromPropertyName(member~"ItemBinding"));	// ItemBinding Setter
						//static if (__traits(hasMember, T, getSignalNameFromPropertyName(member))) // Has a signal
							result ~= format("	mixin Signal!(dquick.script.itemBinding.ItemBinding!(%s))	__%s;\n", fullyQualifiedName2!(MyPropertyType), getSignalNameFromPropertyName(member~"ItemBinding"));

						result ~= format("	dquick.script.nativePropertyBinding.NativePropertyBinding!(dquick.script.itemBinding.ItemBinding!(%s), dquick.script.itemBinding.ItemBinding!T, \"__%sItemBinding\")	%s;\n", fullyQualifiedName2!(MyPropertyType), member, member~"Property");
					}
					else
					{
						static if (isDelegate!MyPropertyType)
							result ~= format("	dquick.script.delegatePropertyBinding.DelegatePropertyBinding!(%s, T, \"%s\")\t%s;\n", fullyQualifiedName2!(MyPropertyType), member, member~"Property");
						else
							result ~= format("	dquick.script.nativePropertyBinding.NativePropertyBinding!(%s, T, \"%s\")\t%s;\n", fullyQualifiedName2!(MyPropertyType), member, member~"Property");
					}
				}
			}
			static if (is(MyPropertyType == void) == true)
			{
				static if (__traits(compiles, generateMethodBinding!(T, member))) // Method
				{
					result ~= generateMethodBinding!(T, member);
				}
			}
			static if (__traits(compiles, EnumMembers!(__traits(getMember, T, member))) && is(OriginalType!(__traits(getMember, T, member)) == int)) // If its an int enum
			{
				result ~= format("alias %s	%s;", fullyQualifiedName2!(__traits(getMember, T, member)), member);
			}
		}
	}

	return result;
}

string	generateFunctionOrMethodBinding(alias overload)()
{
	string result;

	// Collect all argument in a tuple
	string	parameters;
	alias ParameterTypeTuple!(overload) MyParameterTypeTuple;

	foreach (index, paramType; MyParameterTypeTuple)
	{
		static if (is(paramType == class) || is(paramType == interface))
			parameters ~= format("dquick.script.itemBinding.ItemBindingBase!(%s) param%d, ", fullyQualifiedName2!(paramType), index);
		else
			parameters ~= format("%s param%d, ", fullyQualifiedName2!(paramType), index);
	}
	parameters = chomp(parameters, ", ");

	string	callParameters;
	foreach (index, paramType; MyParameterTypeTuple)
	{
		static if (is(paramType == class) || is(paramType == interface))
			callParameters ~= format("cast(%s)(param%d.itemObject), ", fullyQualifiedName2!(paramType), index);
		else
			callParameters ~= format("param%d, ", index);
	}
	callParameters = chomp(callParameters, ", ");

	result ~= format("%s	%s(%s)\n", fullyQualifiedName2!(ReturnType!(overload)), __traits(identifier, overload), parameters);
	result ~= format("{\n");
	static if (__traits(isStaticFunction, overload))
		result ~= format("	return %s(%s);\n", fullyQualifiedName2!(overload), callParameters);
	else
		result ~= format("	return item.%s(%s);\n", __traits(identifier, overload), callParameters);
	result ~= format("}\n");

	return result;
}

string	generateMethodBinding(T, string member)()
{
	string result;

	foreach (overload; __traits(getOverloads, T, member)) 
	{
		static if (	isCallable!(overload) &&
					isSomeFunction!(overload) &&
				   !__traits(isStaticFunction, overload) &&
					   !isDelegate!(overload) &&
					   member != "__ctor" && member != "__dtor" /*dont want constructor nor destructor*/ &&
					   !__traits(hasMember, object.Object, member) /*dont want objects base methods*/)
		{
			static if (__traits(compiles, fullyQualifiedName2!(ReturnType!(overload)))) // Hack because of a bug in fullyQualifiedName
			{
				result ~= generateFunctionOrMethodBinding!(overload);
			}
		}
	}

	return result;
}

template ItemBindingBaseTypeTuple2(A...) // Transform types in ItemBindingBases
{
	static if (A.length == 0)
		alias A	ItemBindingBaseTypeTuple2;
	else
		alias TypeTuple!(ItemBindingBase!(A[0]), ItemBindingBaseTypeTuple2!(A[1 .. $])) ItemBindingBaseTypeTuple2;
}

template ItemBindingBaseTypeTuple(A) // Return base types transformed in ItemBindingBases
{
	alias ItemBindingBaseTypeTuple2!(BaseTypeTuple!(A))	ItemBindingBaseTypeTuple;
}

interface ItemBindingBase(T) : dquick.script.iItemBinding.IItemBinding, ItemBindingBaseTypeTuple!(T) // Proxy the T inheritance hierarchy
{
	Object	itemObject();
}

class ItemBinding(T) : ItemBindingBase!(T) // Proxy that auto bind T
{
	this(T item)
	{
		this.item = item;

		foreach (member; __traits(allMembers, typeof(this)))
		{
			static if (is(typeof(__traits(getMember, this, member)) : dquick.script.propertyBinding.PropertyBinding)) // Instantiate property binding
			{
				const string propertyName = getPropertyNameFromPropertyDeclaration(member);
				static if (__traits(hasMember, this, "____"~propertyName~"ItemBinding")) // Instanciate subitem binding
				{
					__traits(getMember, this, member) = new typeof(__traits(getMember, this, member))(this, this);  // Instantiate property binding linked to __propertyName inside this

					static if (__traits(hasMember, this.item, getSignalNameFromPropertyName(propertyName)))
						__traits(getMember, this.item, getSignalNameFromPropertyName(propertyName)).connect(&__traits(getMember, this, "__"~getSignalNameFromPropertyName(propertyName))); // Signal
					__traits(getMember, this, "__"~getSignalNameFromPropertyName(propertyName))(__traits(getMember, item, propertyName)); // Set initial value
				}
				else // Simple type
				{
					__traits(getMember, this, member) = new typeof(__traits(getMember, this, member))(this, item);  // Instantiate property binding linked to member inside item
				}
			}
		}
	}

	// Item is instancied in the dmlEngine
	this()
	{
		T item = new T;
		this(item);
	}

	T	item;

	Object	itemObject() { return item;}

	mixin(genProperties!(T));
	
	mixin(ITEM_BINDING());
}