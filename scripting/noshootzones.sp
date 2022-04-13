#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <csgo_colors>

#define MODEL "models/props/cs_office/vending_machine.mdl"

ConVar g_hCvar;
KeyValues g_hKV;
char g_sPath[PLATFORM_MAX_PATH];
float g_fZonePos[101][3], g_fRad;
int g_iZoneMaxNum, g_iZoneIndex[101] = {-1, ...}, g_iNoShoot[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "NoShootZones",
	author = "stims & hirowatch & HolyHender",
	description = "Установка зон, в которых нельзя стрелять.",
	version = "2.0",
	url = "http://dev-cs.ru & https://hlmod.ru"
};

public void OnPluginStart()
{
	g_hKV = new KeyValues("NoShootZones");

	BuildPath(Path_SM, g_sPath, sizeof(g_sPath), "configs/noshootzones.ini");

	if(!g_hKV.ImportFromFile(g_sPath))
	{
		SetFailState("Не обнаружен конфиг по пути %s", g_sPath);
	}

	HookEvent("round_start", EventRoundStart, EventHookMode_PostNoCopy);
	RegAdminCmd("sm_nsz", NoShootZonesCommand, ADMFLAG_ROOT);
	LoadTranslations("noshootzones.phrases");

	(g_hCvar = CreateConVar("sm_nsz_rad", "210.0", "Радиус зоны (в единицах). Примерная высота игрока - 72 единицы.")).AddChangeHook(OnConVarChanged);
	g_fRad = g_hCvar.FloatValue;

	AutoExecConfig(true, "noshootzones");
}

void OnConVarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(cvar == g_hCvar)
	{
		g_fRad = cvar.FloatValue;
	}
}
 
public void OnMapStart()
{
	char map[65];
	g_iZoneMaxNum = 0;

	GetCurrentMap(map, sizeof(map));
	if(g_hKV.JumpToKey(map))
	{
		char Key[5];
		float defvalue[3] = { 387335538.000000, 0.000000, 0.000000 };

		for(int x = 1; x < 101; x++)
		{
			IntToString(x, Key, 5);
			g_hKV.GetVector(Key, g_fZonePos[x], defvalue);
			
			if(g_fZonePos[x][0] == 387335538.000000)
			{
				break;
			}

			g_iZoneMaxNum++;
		}

		if(0 < g_iZoneMaxNum < 100)
		{
			for(int x = g_iZoneMaxNum; x < 101; x++)
			{
				g_iZoneIndex[x] = -1;
			}
		}
	}

	PrecacheModel(MODEL);
}

void EventRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iZoneMaxNum > 0)
	{
		for(int x = 1; x <= g_iZoneMaxNum; x++)
		{
			g_iZoneIndex[x] = CreateZone(g_fZonePos[x]);
		}
	}
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			g_iNoShoot[i] = 0;
		}
	}
}


stock int CreateZone(float poss[3])
{
	int trigger = CreateEntityByName("trigger_multiple", -1);

	if(trigger > 0)
	{
		int iEffects;
		float vecs[3];

		DispatchKeyValue(trigger, "spawnflags", "1");
		DispatchKeyValue(trigger, "wait", "0");
		DispatchSpawn(trigger);
		ActivateEntity(trigger);
		SetEntityModel(trigger, MODEL);
		TeleportEntity(trigger, poss, NULL_VECTOR, NULL_VECTOR);
		
		vecs[0] = -g_fRad;
		vecs[1] = -g_fRad;
		vecs[2] = 0.0;
		SetEntPropVector(trigger, Prop_Send, "m_vecMins", vecs);
		
		vecs[0] = g_fRad;
		vecs[1] = g_fRad;
		vecs[2] = 72.0;
		SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", vecs);
		
		SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);
		iEffects = GetEntProp(trigger, Prop_Send, "m_fEffects");
		iEffects |= 32;
		SetEntProp(trigger, Prop_Send, "m_fEffects", iEffects);

		HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch);
		HookSingleEntityOutput(trigger, "OnEndTouch", OnEndTouch);
		
		return trigger;
	}

	return -1;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{ 
	if(IsValidClient(client) && g_iNoShoot[client] && (buttons & IN_ATTACK)) 
	{
		return Plugin_Handled;
	}

	return Plugin_Continue; 
}

void OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if(IsValidClient(activator))
	{
		g_iNoShoot[activator] = 1;
		PrintHintText(activator, "%t", "Prohibition");
	}
}

void OnEndTouch(const char[] output, int caller, int activator, float delay)
{
	if(IsValidClient(activator))
	{
		PrintHintText(activator, "%t", "No Prohibition");
		g_iNoShoot[activator] = 0;
	}
}

Action NoShootZonesCommand(int client, int args)
{
	MenuGlobal(client).Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

void GetEndPos(int client, float end_pos[3])
{
	float EyePosition[3], EyeAngles[3];

	GetClientEyePosition(client, EyePosition);
	GetClientEyeAngles(client, EyeAngles);
	TR_TraceRayFilter(EyePosition, EyeAngles, MASK_SOLID, RayType_Infinite, Filter, client);
	TR_GetEndPosition(end_pos);
}

bool Filter(int ent, int mask, int client)
{
	return client != ent;
}

void DelZone(int zone_num, int index)
{
	if(index > 0 && IsValidEntity(index))
	{
		AcceptEntityInput(index, "Kill");
	}

	g_iZoneIndex[zone_num] = -1;
	g_fZonePos[zone_num][0] = 0.0;
	g_fZonePos[zone_num][1] = 0.0;
	g_fZonePos[zone_num][2] = 0.0;
}

bool IsValidClient(int client)
{
	if(client < 1 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsFakeClient(client))
	{
		return false;
	}

	return true;
}

Menu MenuGlobal(int client)
{
	char buff[128];
	Menu menu = new Menu(HandlerOfMenuGlobal);

	menu.SetTitle("%T\n ", "Menu Title", client);

	FormatEx(buff, sizeof(buff), "%T", "Menu Create", client);
	menu.AddItem("", buff);

	FormatEx(buff, sizeof(buff), "%T", "Menu Delete", client);
	menu.AddItem("", buff);

	FormatEx(buff, sizeof(buff), "%T", "Menu Save", client);
	menu.AddItem("", buff);

	return menu;
}

int HandlerOfMenuGlobal(Menu menu, MenuAction action, int client, int item)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch(item)
			{
				case 0:
				{
					if(g_iZoneMaxNum > 99)
					{
						CGOPrintToChat(client, "%t", "Limit");
					}
					else
					{
						float fEndPos[3];
						int index;

						GetEndPos(client, fEndPos);
						index = CreateZone(fEndPos);

						if(index > 0)
						{
							g_iZoneMaxNum ++;
							g_iZoneIndex[g_iZoneMaxNum] = index;
							g_fZonePos[g_iZoneMaxNum][0] = fEndPos[0];
							g_fZonePos[g_iZoneMaxNum][1] = fEndPos[1];
							g_fZonePos[g_iZoneMaxNum][2] = fEndPos[2];
							CGOPrintToChat(client, "%t", "Zone Created");
						}
						else
						{
							CGOPrintToChat(client, "%t", "Error");
						}
					}
				}

				case 1:
				{
					if(g_iZoneMaxNum < 1)
					{
						CGOPrintToChat(client, "%t", "Not Found 1");
					}
					else
					{
						int iNum;
						float fEndPos[3];
						
						GetEndPos(client, fEndPos);

						for (int x = 1; x <= g_iZoneMaxNum; x++)
						{
							if(GetVectorDistance(fEndPos, g_fZonePos[x]) < 75.0)
							{
								iNum = x;
								break;
							}
						}
						
						if(iNum < 1)
						{
							CGOPrintToChat(client, "%t", "Not Found 2");
						}
						else
						{
							DelZone(iNum, g_iZoneIndex[iNum]);
							CGOPrintToChat(client, "%t", "Successful Del");
						}
					}
				}

				case 2:
				{
					char sMap[65];
					GetCurrentMap(sMap, sizeof(sMap));
					
					if(g_hKV.JumpToKey(sMap))
					{
						g_hKV.DeleteThis();
						g_hKV.Rewind();
					}
					
					if(g_iZoneMaxNum > 0)
					{
						char sKey[5];
						int c = 1;

						g_hKV.JumpToKey(sMap, true);

						for(int x = 1; x <= g_iZoneMaxNum; x++)
						{
							if(g_iZoneIndex[x] > 0)
							{
								IntToString(c, sKey, sizeof(sKey));
								g_hKV.SetVector(sKey, g_fZonePos[x]);
								c++;
							}
						}
					}

					g_hKV.Rewind();
					g_hKV.ExportToFile(g_sPath);

					CGOPrintToChat(client, "%t", "Successful Save", g_sPath);
				}
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}
}