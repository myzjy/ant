#include "audio.h"
#include <cassert>
#include <lua.hpp>
#include "fmod_studio.hpp"
#include "fmod.hpp"
#include "fmod_errors.h"

audio& audio::instance()
{
	static audio s_audio;
	return s_audio;
}

void ERRCHECK_fn(FMOD_RESULT result, const char* file, int line)
{
	if (result != FMOD_OK) {
		printf("audio %s(%d): FMOD error %d - %s", file, line, result, FMOD_ErrorString(result));
	}
	assert(result == FMOD_OK);
}

#define ERRCHECK(_result) ERRCHECK_fn(_result, __FILE__, __LINE__)

bool audio::init()
{
	ERRCHECK(FMOD::Studio::System::create(&studio_));
	FMOD::System* system_{ nullptr };
	// The example Studio project is authored for 5.1 sound, so set up the system output mode to match
	ERRCHECK(studio_->getCoreSystem(&system_));
	ERRCHECK(system_->setSoftwareFormat(0, FMOD_SPEAKERMODE_5POINT1, 0));
	ERRCHECK(studio_->initialize(1024, FMOD_STUDIO_INIT_NORMAL, FMOD_INIT_NORMAL, nullptr));
	return true;
}

FMOD::Studio::Bank* audio::load_bank(const char* buffer, int length)
{
	FMOD::Studio::Bank* bank = nullptr;
	ERRCHECK(studio_->loadBankMemory(buffer, length, FMOD_STUDIO_LOAD_MEMORY, FMOD_STUDIO_LOAD_BANK_NORMAL, &bank));
	return bank;
}

void audio::unload_bank(FMOD::Studio::Bank* bank)
{
	if (!bank) {
		return;
	}
	ERRCHECK(bank->unload());
}

FMOD::Studio::EventInstance* audio::create_event(const char* event_name)
{
	FMOD::Studio::EventDescription* eventDescription = nullptr;
	ERRCHECK(studio_->getEvent(event_name, &eventDescription));
	FMOD::Studio::EventInstance* sound = nullptr;
	ERRCHECK(eventDescription->createInstance(&sound));
	return sound;
}

void audio::get_bank_count(int* count)
{
	ERRCHECK(studio_->getBankCount(count));
}

void audio::get_bank_list(FMOD::Studio::Bank** list, int capacity, int* count)
{
	ERRCHECK(studio_->getBankList(list, capacity, count));
}

void audio::get_event_count(FMOD::Studio::Bank* bank, int* count)
{
	if (!bank) {
		return;
	}
	ERRCHECK(bank->getEventCount(count));
}

void audio::get_event_list(FMOD::Studio::Bank* bank, FMOD::Studio::EventDescription** list, int capacity, int* count)
{
	if (!bank) {
		return;
	}
	ERRCHECK(bank->getEventList(list, capacity, count));
}

bool audio::update()
{
	ERRCHECK(studio_->update());
	return true;
}

void audio::release()
{
	ERRCHECK(studio_->unloadAll());
	ERRCHECK(studio_->flushCommands());
	ERRCHECK(studio_->release());
}


static int
laudio_init(lua_State* L) {
	if (!audio::instance().init()) {
		return luaL_error(L, "Failed to initialise audio.");
	}
	return 0;
}

static int
laudio_load_bank(lua_State* L) {
	if (lua_type(L, 1) == LUA_TSTRING) {
		size_t sz;
		const char* data = lua_tolstring(L, 1, &sz);
		auto ret = audio::instance().load_bank(data, sz);
		if (ret) {
			lua_pushlightuserdata(L, ret);
			return 1;
		}
	}
	return 0;
}

static int
laudio_unload_bank(lua_State* L) {
	if (lua_type(L, 1) == LUA_TLIGHTUSERDATA) {
		audio::instance().unload_bank((FMOD::Studio::Bank*)lua_topointer(L, 1));
	}
	return 0;
}

static int
laudio_bank_count(lua_State* L) {
	int count;
	audio::instance().get_bank_count(&count);
	lua_pushinteger(L, count);
	return 1;
}

static int
laudio_bank_list (lua_State* L) {
	int count;
	audio::instance().get_bank_count(&count);
	if (count > 0) {
		std::vector<FMOD::Studio::Bank*> banklist;
		banklist.resize(count);
		audio::instance().get_bank_list(&banklist[0], count, &count);
		lua_newtable(L);
		for (int i = 0; i < count; i++) {
			lua_pushlightuserdata(L, banklist[i]);
			lua_rawseti(L, -2, i + 1);
		}
		return 1;
	}
	return 0;
}

static int
laudio_event_count(lua_State* L) {
	FMOD::Studio::Bank* bank = nullptr;
	if (lua_type(L, 1) == LUA_TLIGHTUSERDATA) {
		bank = (FMOD::Studio::Bank*)lua_topointer(L, 1);
	}
	int count;
	audio::instance().get_event_count(bank, &count);
	lua_pushinteger(L, count);
	return 1;
}

static int
laudio_bank_name(lua_State* L) {
	FMOD::Studio::Bank* ed = nullptr;
	if (lua_type(L, 1) == LUA_TLIGHTUSERDATA) {
		ed = (FMOD::Studio::Bank*)lua_topointer(L, 1);
		char temp[256];
		int retrieved;
		ed->getPath(temp, 256, &retrieved);
		lua_pushlstring(L, temp, retrieved);
		return 1;
	}
	return 0;
}

static int
laudio_event_name(lua_State* L) {
	FMOD::Studio::EventDescription* ed = nullptr;
	if (lua_type(L, 1) == LUA_TLIGHTUSERDATA) {
		ed = (FMOD::Studio::EventDescription*)lua_topointer(L, 1);
		char temp[256];
		int retrieved;
		ed->getPath(temp, 256, &retrieved);
		lua_pushlstring(L, temp, retrieved);
		return 1;
	}
	return 0;
}

static int
laudio_event_list(lua_State* L) {
	FMOD::Studio::Bank* bank = nullptr;
	if (lua_type(L, 1) == LUA_TLIGHTUSERDATA) {
		bank = (FMOD::Studio::Bank*)lua_topointer(L, 1);
	}
	int count;
	audio::instance().get_event_count(bank, &count);
	if (count > 0) {
		std::vector<FMOD::Studio::EventDescription*> eventlist;
		eventlist.resize(count);
		audio::instance().get_event_list(bank, &eventlist[0], count, &count);
		lua_newtable(L);
		for (int i = 0; i < count; i++) {
			lua_pushlightuserdata(L, eventlist[i]);
			lua_rawseti(L, -2, i + 1);
		}
		return 1;
	}
	return 0;
}

static int
laudio_create_event(lua_State* L) {
	const char* event_name = lua_tostring(L, 1);
	lua_pushlightuserdata(L, audio::instance().create_event(event_name));
	return 1;
}

static int
laudio_destroy_event(lua_State* L) {
	if (lua_type(L, 1) == LUA_TLIGHTUSERDATA) {
		auto* event_inst = (FMOD::Studio::EventInstance*)lua_topointer(L, 1);
		if (event_inst) {
			event_inst->release();
		}
	}
	return 0;
}

static int
laudio_play(lua_State* L) {
	if (lua_type(L, 1) == LUA_TLIGHTUSERDATA) {
		auto* event_inst = (FMOD::Studio::EventInstance*)lua_topointer(L, 1);
		if (event_inst) {
			event_inst->start();
		}
	}
	return 0;
}

static int
laudio_stop(lua_State* L) {
	if (lua_type(L, 1) == LUA_TLIGHTUSERDATA) {
		auto* event_inst = (FMOD::Studio::EventInstance*)lua_topointer(L, 1);
		auto immediate = lua_toboolean(L, 2);
		if (event_inst) {
			event_inst->stop(immediate ? FMOD_STUDIO_STOP_IMMEDIATE : FMOD_STUDIO_STOP_ALLOWFADEOUT);
		}
	}
	return 0;
}

static int
laudio_update(lua_State* L) {
	audio::instance().update();
	return 0;
}

static int
laudio_shutdown(lua_State* L) {
	audio::instance().release();
	return 0;
}


extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int
luaopen_audio(lua_State * L) {
	luaL_Reg l[] = {
		{ "init",     laudio_init },
		{ "update",   laudio_update },
		{ "get_bank_count", laudio_bank_count},
		{ "get_bank_list", laudio_bank_list},
		{ "shutdown", laudio_shutdown },
		{ "load_bank", laudio_load_bank },
		{ "unload_bank", laudio_unload_bank },
		{ "get_bank_name", laudio_bank_name},
		{ "get_event_list", laudio_event_list },
		{ "get_event_count", laudio_event_count },
		{ "get_event_name", laudio_event_name},
		{ "create", laudio_create_event },
		{ "destroy", laudio_destroy_event },
		{ "play", laudio_play},
		{ "stop", laudio_stop},
		{ nullptr, nullptr },
	};
	luaL_newlib(L, l);
	return 1;
}