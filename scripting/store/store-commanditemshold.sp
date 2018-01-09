#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <store>
#include <smjansson>

#define MAX_COMMANDITEMS 512

enum CommandItem
{
	String:CommandItemName[STORE_MAX_NAME_LENGTH],
	String:CommandItemText[255],
	String:CommandItemRetain[255],
	CommandItemTeams[5]
}

int g_commandItems[MAX_COMMANDITEMS][CommandItem];
int g_commandItemCount;

StringMap g_commandItemsNameIndex;

public Plugin myinfo = {
	name        = "[Store] CommandItems Hold",
	author      = "alongub edited by shanapu / TheXeon",
	description = "CommandItems component for [Store]",
	version     = "1.0.1a",
}

/**
 * Plugin is loading.
 */
public void OnPluginStart()
{
    LoadTranslations("store.phrases");
    Store_RegisterItemType("commanditemhold", OnCommandItemUse, OnCommandItemAttributesLoad);
}

/** 
 * Called when a new API library is loaded.
 */
public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "store-inventory"))
	{
		Store_RegisterItemType("commanditemhold", OnCommandItemUse, OnCommandItemAttributesLoad);
	}	
}

public void Store_OnReloadItems() 
{
	if (g_commandItemsNameIndex != null)
	{
		CloseHandle(g_commandItemsNameIndex);
		g_commandItemsNameIndex = null;
	}
		
	g_commandItemsNameIndex = new StringMap();
	g_commandItemCount = 0;
}

public void OnCommandItemAttributesLoad(const char[] itemName, const char[] attrs)
{
	strcopy(g_commandItems[g_commandItemCount][CommandItemName], STORE_MAX_NAME_LENGTH, itemName);
		
	g_commandItemsNameIndex.SetValue(g_commandItems[g_commandItemCount][CommandItemName], g_commandItemCount);
	
	Handle json = json_load(attrs);
	json_object_get_string(json, "command", g_commandItems[g_commandItemCount][CommandItemText], 255);
	json_object_get_string(json, "retain", g_commandItems[g_commandItemCount][CommandItemRetain], 255);

	Handle teams = json_object_get(json, "teams");

	for (int i = 0, size = json_array_size(teams); i < size; i++)
		g_commandItems[g_commandItemCount][CommandItemTeams][i] = json_array_get_int(teams, i);

	delete teams;
	delete json;

	g_commandItemCount++;
}

public Store_ItemUseAction OnCommandItemUse(int client, int itemId, bool equipped)
{
	if (!IsClientInGame(client))
	{
		return Store_DoNothing;
	}

	char itemName[STORE_MAX_NAME_LENGTH];
	Store_GetItemName(itemId, itemName, sizeof(itemName));

	int commandItemhold = -1;
	if (!g_commandItemsNameIndex.GetValue(itemName, commandItemhold))
	{
		PrintToChat(client, "%s%t",  "No item attributes");
		return Store_DoNothing;
	}

	int clientTeam = GetClientTeam(client);

	bool teamAllowed = false;
	for (int teamIndex = 0; teamIndex < 5; teamIndex++)
	{
		if (g_commandItems[commandItemhold][CommandItemTeams][teamIndex] == clientTeam)
		{
			teamAllowed = true;
			break;
		}
	}

	if (!teamAllowed)
	{
		return Store_DoNothing;
	}

	char clientName[64];
	char sanitizedName[MAX_NAME_LENGTH];
	GetClientName(client, clientName, sizeof(clientName));
	
	int j = 0;
	for (int i = 0; i <= strlen(clientName); i++)
	{
		if (IsCharAlpha(clientName[i]) || IsCharNumeric(clientName[i]) || IsCharSpace(clientName[i]))
			sanitizedName[j] = clientName[i];
		else
			sanitizedName[j] = 32;
		j++;
	}
	sanitizedName[j] = '\0';
	
	char clientTeamStr[13];
	IntToString(clientTeam, clientTeamStr, sizeof(clientTeamStr));

	char clientAuth[32];
	GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth), true);

	char clientUser[11];
	Format(clientUser, sizeof(clientUser), "#%d", GetClientUserId(client));

	char commandText[255];
	strcopy(commandText, sizeof(commandText), g_commandItems[commandItemhold][CommandItemText]);

	ReplaceString(commandText, sizeof(commandText), "{clientName}", sanitizedName, false);
	ReplaceString(commandText, sizeof(commandText), "{clientTeam}", clientTeamStr, false);		
	ReplaceString(commandText, sizeof(commandText), "{clientAuth}", clientAuth, false);
	ReplaceString(commandText, sizeof(commandText), "{clientUser}", clientUser, false);		

	ServerCommand(commandText);
	
	if(StrEqual(g_commandItems[commandItemhold][CommandItemRetain], "false", false))
		return Store_DeleteItem;
	
	return Store_DoNothing;
}