#define Module_Neon

enum struct Neon
{
    int iColor[4];
    int iBright;
    int iDistance;
    int iFade;
}

static Neon g_eNeons[STORE_MAX_ITEMS];
static int g_iNeons = 0;
static int g_iClientNeon[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};

bool Neon_Config(KeyValues kv, int itemid) 
{ 
    Store_SetDataIndex(itemid, g_iNeons); 
    KvGetColor(kv, "color", g_eNeons[g_iNeons].iColor[0], g_eNeons[g_iNeons].iColor[1], g_eNeons[g_iNeons].iColor[2], g_eNeons[g_iNeons].iColor[3]); 
    g_eNeons[g_iNeons].iBright = kv.GetNum("brightness");
    g_eNeons[g_iNeons].iDistance = kv.GetNum("distance");
    g_eNeons[g_iNeons].iFade = kv.GetNum("distancefade");
    ++g_iNeons;
    return true; 
}

void Neon_OnMapStart()
{
    
}

void Neon_OnClientDisconnect(int client)
{
    Store_RemoveClientNeon(client);
}

void Neon_Reset()
{
    g_iNeons = 0;
}

int Neon_Equip(int client, int id)
{
    RequestFrame(EquipNeon_Delay, client);

    return 0;
}

public void EquipNeon_Delay(int client)
{
    if(IsClientInGame(client) && IsPlayerAlive(client))
        Store_SetClientNeon(client);
}

int Neon_Remove(int client, int id) 
{
    Store_RemoveClientNeon(client);
    return 0; 
}

void Store_RemoveClientNeon(int client)
{
    if(g_iClientNeon[client] != INVALID_ENT_REFERENCE)
    {
        int entity = EntRefToEntIndex(g_iClientNeon[client]);
        if(IsValidEdict(entity))
        {
            AcceptEntityInput(entity, "Kill");
        }
        g_iClientNeon[client] = INVALID_ENT_REFERENCE;
    }
}

void Store_SetClientNeon(int client)
{
    Store_RemoveClientNeon(client);

#if defined GM_ZE
    if(g_iClientTeam[client] == 2)
        return;
#endif

    int m_iEquipped = Store_GetEquippedItem(client, "neon", 0); 
    if(m_iEquipped < 0) 
        return;

    int m_iData = Store_GetDataIndex(m_iEquipped);

    if(g_eNeons[m_iData].iColor[3] != 0)
    {
        float clientOrigin[3];
        GetClientAbsOrigin(client, clientOrigin);

        int iNeon = CreateEntityByName("light_dynamic");
        
        char m_szString[100];
        IntToString(g_eNeons[m_iData].iBright, STRING(m_szString));
        DispatchKeyValue(iNeon, "brightness", m_szString);

        FormatEx(STRING(m_szString), "%d %d %d %d", g_eNeons[m_iData].iColor[0], g_eNeons[m_iData].iColor[1], g_eNeons[m_iData].iColor[2], g_eNeons[m_iData].iColor[3]);
        DispatchKeyValue(iNeon, "_light", m_szString);
        
        IntToString(g_eNeons[m_iData].iFade, STRING(m_szString));
        DispatchKeyValue(iNeon, "spotlight_radius", m_szString);

        IntToString(g_eNeons[m_iData].iDistance, STRING(m_szString));
        DispatchKeyValue(iNeon, "distance", m_szString);

        DispatchKeyValue(iNeon, "style", "0");

        SetEntPropEnt(iNeon, Prop_Send, "m_hOwnerEntity", client);

        DispatchSpawn(iNeon);
        AcceptEntityInput(iNeon, "TurnOn");

        DispatchKeyValue(iNeon, "targetname", "store_item_neon");

        TeleportEntity(iNeon, clientOrigin, NULL_VECTOR, NULL_VECTOR);

        SetVariantString("!activator");
        AcceptEntityInput(iNeon, "SetParent", client, iNeon, 0);

        g_iClientNeon[client] = EntIndexToEntRef(iNeon);

        Call_OnNeonCreated(client, iNeon);
    }
}

stock void Call_OnNeonCreated(int client, int entity)
{
    static Handle gf = null;
    if (gf == null)
    {
        // create
        gf = CreateGlobalForward("Store_OnNeonCreated", ET_Ignore, Param_Cell, Param_Cell);
    }

    Call_StartForward(gf);
    Call_PushCell(client);
    Call_PushCell(entity);
    Call_Finish();
}