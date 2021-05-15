#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.1.0"

public Plugin myinfo = 
{
	name = "Dispenser Here Redux",
	author = "RetroTV",
	description = "New syntax and additional options",
	version = PLUGIN_VERSION,
	url = ""
};

char voiceMenu1[4];
char voiceMenu2[4];

lastUsed[MAXPLAYERS + 1] = { 0, ... };
building[MAXPLAYERS + 1] = { 0, ... };

Handle g_blueprint = INVALID_HANDLE;
// Handle g_prop = INVALID_HANDLE;
Handle g_restriction = INVALID_HANDLE;
Handle g_remove = INVALID_HANDLE;
Handle g_limit = INVALID_HANDLE;

Handle g_admin = INVALID_HANDLE;

public void OnPluginStart()
{
	RegConsoleCmd("voicemenue", CommandVoiceMenu);
	
	g_blueprint   = CreateConVar("sm_disp_blueprint", "1", "Enable/Disable the blueprint");
	// g_prop 		  = CreateConVar("sm_disp_prop", "1", "Enable/Disable the prop");
	g_restriction = CreateConVar("sm_disp_time", "1", "Time between spawn the model");
	g_remove 	  = CreateConVar("sm_disp_remove", "10.0", "Time to remove the model");
	g_limit 	  = CreateConVar("sm_disp_limit", "0", "building per person. 0 to disable checking.");
	g_admin		  = CreateConVar("sm_disp_admin", "0", "Enable/disable Admin flag check");
}

public void OnMapStart()
{
	PrecacheModel("models/buildables/teleporter.mdl");
	PrecacheModel("models/buildables/dispenser_lvl3.mdl");
	PrecacheModel("models/buildables/sentry3.mdl");
	PrecacheModel("models/buildables/teleporter_blueprint_enter.mdl");
	PrecacheModel("models/buildables/dispenser_blueprint.mdl");
	PrecacheModel("models/buildables/sentry1_blueprint.mdl");

	for(int i = 1; i <= MaxClients; i++)
	{
		building[i] = 0;
	}
}

public Action CommandVoiceMenu(int client, int args)
{
	if(IsPlayerAlive(client))
	{
		GetCmdArg(1, voiceMenu1, sizeof(voiceMenu1));
		GetCmdArg(2, voiceMenu2, sizeof(voiceMenu2));
		
		if(StringToInt(voiceMenu1) == 1)
		{
			int type = StringToInt(voiceMenu2);
			
			if(type >= 3 && type <= 5)
			{
				CommandProp(client, type - 3);
			}
		}
	}
}

public Action CommandProp(int client, int args)
{
	int currentTime = GetTime();
	
	if(currentTime - lastUsed[client] < GetConVarInt(g_restriction)) { return Plugin_Handled; }
	lastUsed[client] = currentTime;
	
	if(GetConVarInt(g_admin) == 1 && !(GetUserFlagBits(client) & ADMFLAG_GENERIC)) return Plugin_Handled;
	if(GetConVarInt(g_limit) != 0 && building[client] >= GetConVarInt(g_limit)) return Plugin_Handled;
	
	building[client]++;
	
	char propModel[64];
	char propModelBlueprint[64];
	
	propModel = GetPropModel(args);
	propModelBlueprint = GetPropModelBlueprint(args);
	
	int prop = CreateEntityByName("prop_physics_override");
	
	if(IsValidEntity(prop))
	{
		SetEntityModel(prop, propModel);
		SetEntityMoveType(prop, MOVETYPE_VPHYSICS);
		SetEntProp(prop, Prop_Send, "m_CollisionGroup", 1);
		SetEntProp(prop, Prop_Send, "m_usSolidFlags", 16);
		DispatchSpawn(prop);

		float pos[3];
		float vecVelocity[3];
		
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
		
		pos[2] += 30;
		vecVelocity[0] = 0.0;
		vecVelocity[1] = 0.0;
		vecVelocity[2] = 500.0;
		
		TeleportEntity(prop, pos, NULL_VECTOR, vecVelocity);

		CreateTimer(GetConVarFloat(g_remove), RemoveEnt, EntIndexToEntRef(prop));
	}
	
	if(GetConVarBool(g_blueprint))
	{
		int prop2 = CreateEntityByName("prop_physics_override");
		
		if(IsValidEntity(prop2))
		{
			SetEntityModel(prop2, propModelBlueprint);
			SetEntityMoveType(prop2, MOVETYPE_NONE);
			DispatchSpawn(prop2);
			
			float pos[3];
			
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
			TeleportEntity(prop2, pos, NULL_VECTOR, NULL_VECTOR);
			
			CreateTimer(GetConVarFloat(g_remove), RemoveEnt, EntIndexToEntRef(prop2));
		}
	}
	
	return Plugin_Handled;
}

public Action RemoveEnt(Handle timer, any entid)
{
	int ent = EntRefToEntIndex(entid);
	
	if(IsValidEdict(ent) && ent > MaxClients)
	{
		AcceptEntityInput(ent, "Kill");
	}
}

char[] GetPropModel(int args)
{
	char propModel[64];
	
	switch(args)
	{
		case 0:
		{
			propModel = "models/buildables/teleporter.mdl";
		}
		case 1:
		{
			propModel = "models/buildables/dispenser_lvl3.mdl";
		}
		case 2:
		{
			propModel = "models/buildables/sentry3.mdl";
		}
		default:
		{
			propModel = "";
		}
	}
	
	return propModel;
}

char[] GetPropModelBlueprint(int args)
{
	char propModelBlueprint[64];
	
	switch(args)
	{
		case 0:
		{
			propModelBlueprint = "models/buildables/teleporter_blueprint_enter.mdl";
		}
		case 1:
		{
			propModelBlueprint = "models/buildables/dispenser_blueprint.mdl";
		}
		case 2:
		{
			propModelBlueprint = "models/buildables/sentry1_blueprint.mdl";
		}
		default:
		{
			propModelBlueprint = "";
		}
	}
	
	return propModelBlueprint;
}