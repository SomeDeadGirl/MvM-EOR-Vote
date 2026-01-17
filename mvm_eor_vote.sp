#include <sourcemod>
#include <mapchooser>
#include <nextmap>
#include <nativevotes>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
    name = "MvM_EOR_Vote",
    author = "gloom",
    description = "Forces an RTV vote on MvM mission complete or admin command.",
    version = "1.0",
    url = ""
};

ConVar g_Cvar_ChangeTime;

bool g_CanRTV = false;
bool g_InChange = false;

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("rockthevote.phrases");

    // Cvar for when to change the map after the vote passes
    g_Cvar_ChangeTime = CreateConVar("sm_autortv_changetime", "0", 
        "When to change the map after a successful RTV: 0 - Instant, 1 - RoundEnd, 2 - MapEnd", 
        _, true, 0.0, true, 2.0);

    // Admin command to force the vote manually
    RegAdminCmd("sm_forcertv", Command_ForceRTV, ADMFLAG_VOTE, "Forces the RTV vote to start immediately");

    // Hook for MvM Mission Complete
    HookEvent("mvm_mission_complete", Event_MissionComplete, EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
    g_CanRTV = true;
    g_InChange = false;
}

public void OnMapEnd()
{
    g_CanRTV = false;
}

// Admin Command
public Action Command_ForceRTV(int client, int args)
{
    if (!g_CanRTV)
    {
        ReplyToCommand(client, "[SM] Cannot start RTV yet.");
        return Plugin_Handled;
    }

    StartRTV();
    return Plugin_Handled;
}

// MvM Mission Complete Hook
public void Event_MissionComplete(Event event, const char[] name, bool dontBroadcast)
{
    // Delay slightly so players see the mission complete screen
    CreateTimer(5.0, Timer_StartRTV_Delayed);
}

public Action Timer_StartRTV_Delayed(Handle timer)
{
    if (g_CanRTV && !g_InChange)
    {
        StartRTV();
    }
    return Plugin_Stop;
}

void StartRTV()
{
    if (g_InChange) return;

    // Check if a vote is already happening via MapChooser
    if (!CanMapChooserStartVote())
    {
        PrintToChatAll("[SM] RTV vote is already in progress or cannot be started.");
        return;
    }

    // Check if the map vote already happened at end of map
    if (EndOfMapVoteEnabled() && HasEndOfMapVoteFinished())
    {
        // If the end of map vote already finished, just change the map immediately
        char map[PLATFORM_MAX_PATH];
        if (GetNextMap(map, sizeof(map)))
        {
            GetMapDisplayName(map, map, sizeof(map));
            PrintToChatAll("[SM] %t", "Changing Maps", map);
            CreateTimer(5.0, Timer_ChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
            g_InChange = true;
        }
        return;
    }

    // Initiate the MapChooser vote
    MapChange when = view_as<MapChange>(g_Cvar_ChangeTime.IntValue);
    
    // This displays the NativeVote with the map list
    if (InitiateMapChooserVote(when))
    {
        PrintToChatAll("[SM] Vote for next map has started.");
    }
}

public Action Timer_ChangeMap(Handle hTimer)
{
    g_InChange = false;
    LogMessage("Auto RTV changing map");
    char map[PLATFORM_MAX_PATH];
    if (GetNextMap(map, sizeof(map)))
    {
        ForceChangeLevel(map, "Auto Force RTV");
    }
    return Plugin_Stop;
}