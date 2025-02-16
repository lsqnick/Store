#define Module_Player

void Players_OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn_Pre, EventHookMode_Pre);
    HookEvent("player_death", Event_PlayerDeath_Pre, EventHookMode_Pre);
    HookEvent("player_team",  Event_PlayerTeam_Pre,  EventHookMode_Pre);

#if defined Module_Skin
    Skin_OnPluginStart();
#endif

#if defined Module_Hats
    Store_RegisterHandler("hat", Hats_OnMapStart, Hats_Reset, Hats_Config, Hats_Equip, Hats_Remove, true);
#endif

#if defined Module_Neon
    //  neon id -> color
    //  modify in dev1.92
    Store_RegisterHandler("neon", Neon_OnMapStart, Neon_Reset, Neon_Config, Neon_Equip, Neon_Remove, true); 
#endif

#if defined Module_Aura
    Store_RegisterHandler("aura", Aura_OnMapStart, Aura_Reset, Aura_Config, Aura_Equip, Aura_Remove, true);
#endif

#if defined Module_Part
    Store_RegisterHandler("particle", Part_OnMapStart, Part_Reset, Part_Config, Part_Equip, Part_Remove, true);
#endif

#if defined Module_Trail
    Store_RegisterHandler("trail", Trails_OnMapStart, Trails_Reset, Trails_Config, Trails_Equip, Trails_Remove, true);
#endif
}

void Players_OnClientDisconnect(int client)
{
#if defined Module_Aura
    Aura_OnClientDisconnect(client);
#endif

#if defined Module_Neon
    Neon_OnClientDisconnect(client);
#endif

#if defined Module_Part
    Part_OnClientDisconnect(client);
#endif

#if defined Module_Skin
    Skin_OnClientDisconnect(client);
#endif

#if defined Module_Trail
    Trails_OnClientDisconnect(client);
#endif
}

public Action Event_PlayerSpawn_Pre(Event event, const char[] name, bool dontBroadcast)
{
    if (event.GetInt("teamnum", -1) == 0)
        return Plugin_Continue;

    int client = GetClientOfUserId(event.GetInt("userid"));

    if(IsFakeClient(client) || g_iClientTeam[client] <= 1)
        return Plugin_Continue;

    RequestFrame(OnClientSpawnPost, client);

#if defined Module_Skin
    Store_OnPlayerSpawn(client);
    Store_RemoveClientGloves(client, -1);
    Store_ResetPlayerSkin(client);
    Store_PreSetClientModel(client);
    //  32tick ~ 0.032
    //  64tick ~ 0.016
    // 128tick ~ 0.008
    CreateTimer(0.0, Timer_ClearCamera, client);
    if(g_tKillPreview[client] != null) TriggerTimer(g_tKillPreview[client], false);
#endif

    return Plugin_Continue;
}

public void OnClientSpawnPost(int client)
{
    if(!IsClientInGame(client) || !IsPlayerAlive(client))
        return;
    
#if defined Module_Skin
    Store_RemoveClientGloves(client, -1);
#endif

#if defined Module_Trail
    Store_SetClientTrail(client);
#endif

#if defined Module_Hats && !defined Module_Skin
    Store_SetClientHat(client);
#endif

    // particles should be delay.
    CreateTimer(UTIL_GetRandomInt(5, 30) * 0.1, Timer_DelaySpawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DelaySpawn(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if(!client || !IsPlayerAlive(client))
        return Plugin_Stop;

#if defined Module_Aura
    Store_SetClientAura(client);
#endif

#if defined Module_Neon
    Store_SetClientNeon(client);
#endif

#if defined Module_Part
    Store_SetClientPart(client);
#endif

    return Plugin_Stop;
}

public Action Event_PlayerDeath_Pre(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if(IsFakeClient(client))
        return Plugin_Continue;

#if defined Module_Skin
    RequestFrame(Broadcast_DeathSound, client);
    RequestFrame(FirstPersonDeathCamera, client);
#endif

    DeathReset(client);

    return Plugin_Continue;
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
    g_iClientTeam[client] = 2;

    DeathReset(client);

#if defined Module_Skin
    Store_ResetPlayerSkin(client);
#endif
}

public void ZE_OnPlayerInfected(int client, int attacker, bool motherZombie, bool teleportOverride, bool teleport)
{
    g_iClientTeam[client] = 2;

    DeathReset(client);

#if defined Module_Skin
    Store_ResetPlayerSkin(client);
#endif
}

void DeathReset(int client)
{
    #pragma unused client

#if defined Module_Aura
    Store_RemoveClientAura(client);
#endif

#if defined Module_Neon
    Store_RemoveClientNeon(client);
#endif

#if defined Module_Part
    Store_RemoveClientPart(client);
#endif

    for(int i = 0; i < STORE_MAX_SLOTS; ++i)
    {
#if defined Module_Hats
        Store_RemoveClientHats(client, i);
#endif

#if defined Module_Trail
        Store_RemoveClientTrail(client, i);
#endif
    }
}

public Action Event_PlayerTeam_Pre(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int newteam = event.GetInt("team");
    int oldteam = event.GetInt("oldteam");

    g_iClientTeam[client] = newteam;
    
    if(oldteam > 1 && newteam <= 1)
    {
#if defined Module_Aura
        Store_RemoveClientAura(client);
#endif
        
#if defined Module_Neon
        Store_RemoveClientNeon(client);
#endif

#if defined Module_Part
        Store_RemoveClientPart(client);
#endif

#if defined Module_Trail
        for(int i = 0; i < STORE_MAX_SLOTS; ++i)
            Store_RemoveClientTrail(client, i);
#endif

#if defined Module_Hats
        for(int i = 0; i < STORE_MAX_SLOTS; ++i)
            Store_RemoveClientHats(client, i);
#endif
    }

#if defined TeamArms
    RequestFrame(OnClientTeamPost, client);
#endif

    return Plugin_Continue;
}

#if defined TeamArms
void OnClientTeamPost(int client)
{
    if(!IsClientInGame(client) || !IsPlayerAlive(client) || g_iClientTeam[client] > 1)
        return;

    Store_PreSetClientModel(client);
}
#endif

stock void Call_OnParticlesCreated(int client, int entity)
{
    static Handle gf = null;
    if (gf == null)
    {
        // create
        gf = CreateGlobalForward("Store_OnParticlesCreated", ET_Ignore, Param_Cell, Param_Cell);
    }

    Call_StartForward(gf);
    Call_PushCell(client);
    Call_PushCell(entity);
    Call_Finish();
}