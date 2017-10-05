#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <basecomm>

#define PLUGIN_VERSION "1.0.0"

ConVar cvarDisableDoveSpawn, cvarDisableNonAuthedSpam;
Handle authClientTimer[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[NGS] Game Fixes",
	author = "TheXeon",
	description = "Small plugin including changes for NGS server.",
	version = PLUGIN_VERSION,
	url = "https://www.neogenesisnetwork.net/"
}

public void OnPluginStart()
{
	cvarDisableNonAuthedSpam = CreateConVar("sm_ngsfixes_disable_authspam", "1", "Should players be kicked if they don\'t auth?");
	cvarDisableDoveSpawn = CreateConVar("sm_ngsfixes_disable_doves", "1", "Should the plugin disable dove spawning.");
	HookUserMessage(GetUserMessageId("SpawnFlyingBird"), UserMsg_SpawnBird, true);
}

public Action UserMsg_SpawnBird(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	if (!cvarDisableDoveSpawn.BoolValue) return Plugin_Continue;
	return Plugin_Stop;
}

public void OnClientConnected(int client)
{
	if (cvarDisableNonAuthedSpam.BoolValue && !IsFakeClient(client))
		authClientTimer[client] = CreateTimer(2.0, AuthCheckTimer, GetClientUserId(client), TIMER_REPEAT);
}

public Action AuthCheckTimer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	char auth[24];
	if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth)) || StrContains("STEAM_ID_STOP_IGNORING_RETVALS", auth, false) != -1)
	{
		if (IsPlayerAlive(client))
		{
			ChangeClientTeam(client, 1);
			PrintToChat(client, "Your client has not been authed, please reconnect.");
		}
		BaseComm_SetClientGag(client, true);
		BaseComm_SetClientMute(client, true);
		ServerCommand("namelockid %d 1", userid);
	}
	else
	{
		KillTheTimer(client);
	}
	return Plugin_Continue;
}

stock void KillTheTimer(int client)
{
	KillTimer(authClientTimer[client]);
	authClientTimer[client] = null;
}

public void OnClientDisconnect(int client)
{
	if (authClientTimer[client] != null)
	{
		KillTimer(authClientTimer[client]);
		authClientTimer[client] = null;
	}
}