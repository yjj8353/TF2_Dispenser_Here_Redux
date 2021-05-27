#include <sourcemod>
#include <sdktools>
#include <tf2>			// TF*
#include <tf2_stocks>	// TF2_*

#pragma semicolon 1;
#pragma newdecls required;

public Plugin myinfo = 
{
	name 		= "[TF2] Dispenser Here Redux",
	author 		= "RetroTV",
	description = "New syntax and additional options",
	version 	= "1.1.0",
	url			= ""
};

char voiceMenu1[4];
char voiceMenu2[4];

int lastUsed[MAXPLAYERS + 1] = { 0, ... };
int building[MAXPLAYERS + 1] = { 0, ... };

Handle g_enable 	    = INVALID_HANDLE;
Handle g_blueprint 	    = INVALID_HANDLE;
Handle g_prop 		    = INVALID_HANDLE;
Handle g_dispenserLevel = INVALID_HANDLE;
Handle g_sentryLevel    = INVALID_HANDLE;
Handle g_restriction    = INVALID_HANDLE;
Handle g_remove 	    = INVALID_HANDLE;
Handle g_limit 		    = INVALID_HANDLE;
Handle g_admin 		    = INVALID_HANDLE;

public void OnPluginStart()
{
	RegConsoleCmd("voicemenu", CommandVoiceMenu);
	
	/********************************************************************
	 * g_enable		    : 플러그인 활성화 여부
	 * g_blueprint	    : 청사진 활성화 여부
	 * g_prop		    : 건물(텔레포터, 디스펜서, 센트리) 프롭 활성화 여부
	 * g_dispenserLevel : 디스펜서 소환시 보여줄 디스펜서 프롭의 레벨
	 * g_sentryLevel    : 센트리 소환시 보여줄 센트리 프롭의 레벨
	 * g_restriction    : 건물 프롭 생성허용 간격 시간
	 * g_remove	        : 건물 프롭이 생성 후 삭제되는데 걸리는 시간
	 * g_limit		    : 건물 프롭이 생성되는 최대 개수 제한 (유저당)
	 * g_admin		    : 관리자 플래그
	 ********************************************************************/
	
	g_enable	     = CreateConVar("sm_disp_enable", "1", "Enable/Disable dispenser here plugin", _, true, 0.0, true, 1.0);
	g_blueprint      = CreateConVar("sm_disp_blueprint", "1", "Enable/Disable the blueprint", _, true, 0.0, true, 1.0);
	g_prop 		     = CreateConVar("sm_disp_prop", "1", "Enable/Disable the prop", _, true, 0.0, true, 1.0);
	g_dispenserLevel = CreateConVar("sm_disp_dispenserlv", "3", "Dispenser Prop Level", _, true, 0.0, true, 3.0);
	g_sentryLevel    = CreateConVar("sm_disp_sentrylv", "3", "Sentey Prop Level", _, true, 0.0, true, 3.0);
	g_restriction    = CreateConVar("sm_disp_time", "1", "Time between spawn the model");
	g_remove 	     = CreateConVar("sm_disp_remove", "10.0", "Time to remove the model");
	g_limit 	     = CreateConVar("sm_disp_limit", "0", "building per person. 0 to disable checking.");
	g_admin		     = CreateConVar("sm_disp_admin", "0", "Enable/disable Admin flag check");
}

public void OnMapStart()
{	
	PrecacheModel("models/buildables/teleporter.mdl");
	PrecacheModel("models/buildables/dispenser_light.mdl");
	PrecacheModel("models/buildables/dispenser_lvl2_light.mdl");
	PrecacheModel("models/buildables/dispenser_lvl3_light.mdl");
	PrecacheModel("models/buildables/sentry1.mdl");
	PrecacheModel("models/buildables/sentry2.mdl");
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
	if(GetConVarBool(g_enable) && IsPlayerAlive(client))
	{
		GetCmdArg(1, voiceMenu1, sizeof(voiceMenu1));
		GetCmdArg(2, voiceMenu2, sizeof(voiceMenu2));
		
		// X키 == 1
		if(StringToInt(voiceMenu1) == 1)
		{
			int type = StringToInt(voiceMenu2);
			
			// X키 -> 4: Teleporter Here, X키 -> 5 Dispenser Here, X키 -> 6 Sentry Here
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
	
	// 마지막 프롭 생성시간(lastUsed) 값과 현재 시간 값을 비교하여 g_restriction 값보다 작으면 프롭을 생성하지 않음. 
	if(currentTime - lastUsed[client] < GetConVarInt(g_restriction)) { return Plugin_Handled; }
	lastUsed[client] = currentTime;
	
	// g_admin이 활성화 되고, 해당 유저가 어드민이 아닌경우 프롭이 생성되지 않음.
	if(GetConVarInt(g_admin) == 1 && !(GetUserFlagBits(client) & ADMFLAG_GENERIC)) { return Plugin_Handled; }
	
	// g_limit이 1 이상의 값일 경우, 해당 유저의 building 값을 확인하고 g_limit 값보다 더 많은 프롭을 생성하지 못하게 함.
	if(GetConVarInt(g_limit) != 0 && building[client] >= GetConVarInt(g_limit)) { return Plugin_Handled; }
	
	building[client]++;
	
	char propModel[64];
	char propModelBlueprint[64];
	
	int dispenserLevel;
	int sentryLevel;
	
	// g_prop 값의 활성화 여부에 따라, prop 생성을 제한함.
	if(GetConVarBool(g_prop))
	{	
		switch(args)
		{
			case 0: propModel = GetPropModel(args, 0);
			case 1:
			{
				dispenserLevel = (GetConVarInt(g_dispenserLevel) == 0) ? GetRandomInt(1, 3) : GetConVarInt(g_dispenserLevel);
				propModel = GetPropModel(args, dispenserLevel);
			}
			case 2:
			{
				sentryLevel = (GetConVarInt(g_sentryLevel) == 0) ? GetRandomInt(1, 3) : GetConVarInt(g_sentryLevel);
				propModel = GetPropModel(args, sentryLevel);
			}
		}
	}
	
	// g_blueporint 값의 활성화 여부에 따라, blueprint prop 생성을 제한함.
	if(GetConVarBool(g_blueprint))
	{
		propModelBlueprint = GetPropModelBlueprint(args);
	}
	
	// propModel 생성 및 애니메이션
	int propModelEntity = CreateEntityByName("prop_physics_override");
	
	if(IsValidEntity(propModelEntity))
	{
		SetEntityModel(propModelEntity, propModel);
		SetEntityMoveType(propModelEntity, MOVETYPE_VPHYSICS);
		
		// 팀이 BLU면 skin을 1로 세팅 (Default 값인 0는 RED임)
		if(TF2_GetClientTeam(client) == TFTeam_Blue)
		{
			SetEntProp(propModelEntity, Prop_Send, "m_nSkin", 1);
		}
		
		SetEntProp(propModelEntity, Prop_Send, "m_CollisionGroup", 1);
		SetEntProp(propModelEntity, Prop_Send, "m_usSolidFlags", 16);
		DispatchSpawn(propModelEntity);

		float pos[3];
		float vecVelocity[3];
		
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
		
		pos[2] += 30;
		vecVelocity[0] = 0.0;
		vecVelocity[1] = 0.0;
		vecVelocity[2] = 500.0;
		
		TeleportEntity(propModelEntity, pos, NULL_VECTOR, vecVelocity);

		CreateTimer(GetConVarFloat(g_remove), RemoveEnt, EntIndexToEntRef(propModelEntity));
	}
	
	// propModelBlueprint 생성 및 애니메이션
	if(GetConVarBool(g_blueprint))
	{
		int propModelBlueprintEntity = CreateEntityByName("prop_physics_override");
		
		if(IsValidEntity(propModelBlueprintEntity))
		{
			SetEntityModel(propModelBlueprintEntity, propModelBlueprint);
			SetEntityMoveType(propModelBlueprintEntity, MOVETYPE_NONE);
			DispatchSpawn(propModelBlueprintEntity);
			
			float pos[3];
			
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
			TeleportEntity(propModelBlueprintEntity, pos, NULL_VECTOR, NULL_VECTOR);
			
			CreateTimer(GetConVarFloat(g_remove), RemoveEnt, EntIndexToEntRef(propModelBlueprintEntity));
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

// dispenser와 sentry 레벨별 선택 가능하게 구현
char[] GetPropModel(int args, int propLevel)
{
	char propModel[64];
	
	switch(args)
	{
		case 0: propModel = "models/buildables/teleporter.mdl";
		case 1:
		{
			switch(propLevel)
			{
				case 1: propModel = "models/buildables/dispenser_light.mdl";
				case 2: propModel = "models/buildables/dispenser_lvl2_light.mdl";
				case 3: propModel = "models/buildables/dispenser_lvl3_light.mdl";
			}
		}
		case 2: 
		{
			switch(propLevel)
			{
				case 1: propModel = "models/buildables/sentry1.mdl";
				case 2: propModel = "models/buildables/sentry2.mdl";
				case 3: propModel = "models/buildables/sentry3.mdl";
			}
		}
	}
	
	return propModel;
}

char[] GetPropModelBlueprint(int args)
{	
	char propModelBlueprint[64];
	
	switch(args)
	{
		case 0: propModelBlueprint = "models/buildables/teleporter_blueprint_enter.mdl";
		case 1: propModelBlueprint = "models/buildables/dispenser_blueprint.mdl";
		case 2: propModelBlueprint = "models/buildables/sentry1_blueprint.mdl";
	}
	
	return propModelBlueprint;
}
