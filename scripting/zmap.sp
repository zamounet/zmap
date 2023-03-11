#include <system2>
#include <sourcemod>

enum struct DownloadInformation
{
    int issuer;
    char mapName[PLATFORM_MAX_PATH];
    char mapNameExtended[PLATFORM_MAX_PATH];
    char outputPath[PLATFORM_MAX_PATH];
}

ConVar g_Cvar_downloadurl;
char baseOutputPath[PLATFORM_MAX_PATH] = "addons/sourcemod/data/"
ArrayList DownloadedMaps;

public void OnPluginStart()
{
    g_Cvar_downloadurl = CreateConVar("sv_zmapdownloadurl", "", "url of maps");
    RegAdminCmd("sm_zmap", Command_InstallMap, ADMFLAG_ROOT, "Install a map from a mirror");

    DownloadedMaps = CreateArray(sizeof(DownloadInformation));
}

public void OnMapEnd() {
    ClearArray(DownloadedMaps);
}

public Action Command_InstallMap(int client, int args)
{
    char mapname[PLATFORM_MAX_PATH];
    char extendedMapName[PLATFORM_MAX_PATH];
    char downloadUrl[PLATFORM_MAX_PATH];
    char outputPath[PLATFORM_MAX_PATH];
    char uselessbuffer[PLATFORM_MAX_PATH];

    if (args < 1)
    {
        ReplyToCommand(client, "[ZMAP] Usage: !zmap <map_name>");
        return Plugin_Handled;
    }

    GetCmdArg(1, mapname, sizeof(mapname));

    if (FindMap(mapname, uselessbuffer, sizeof(uselessbuffer)) != FindMap_NotFound)
	{
        PrintToChatAll("[ZMAP] Changing map to %s...", mapname);

        DataPack dp;
        CreateDataTimer(3.0, Timer_ChangeMap, dp);
        dp.WriteString(mapname);
        
		return Plugin_Handled;
	}

    g_Cvar_downloadurl.GetString(downloadUrl, sizeof(downloadUrl))
    
    Format(extendedMapName, sizeof(extendedMapName), "%s%s", mapname, ".bsp.bz2");
    Format(outputPath, sizeof(outputPath), "%s%s", baseOutputPath, extendedMapName);
    StrCat(downloadUrl, sizeof(downloadUrl), extendedMapName);

    DownloadInformation download;

    download.issuer = client;
    strcopy(download.mapName, sizeof(download.mapName), mapname);
    strcopy(download.mapNameExtended, sizeof(download.mapNameExtended), extendedMapName);
    strcopy(download.outputPath, sizeof(download.outputPath), outputPath);

    int save_index = PushArrayArray(DownloadedMaps, download)

    PrintToChat(download.issuer, "[ZMAP] Dowloading %s....", download.mapName)
    System2HTTPRequest httpRequest = new System2HTTPRequest(DownloadCallback, downloadUrl);
    httpRequest.Any = save_index
    httpRequest.SetOutputFile(outputPath);
    httpRequest.GET();

    delete httpRequest;
    
    return Plugin_Handled;
}

public Action Timer_ChangeMap(Handle timer, DataPack dp)
{
	char map[PLATFORM_MAX_PATH];

	dp.Reset();
	dp.ReadString(map, sizeof(map));

    ForceChangeLevel(map, "sm_zmap Command");

	return Plugin_Stop;
}

public void ExtractCallback(bool success, const char[] command, System2ExecuteOutput output, any data) {
    DownloadInformation download;
    DownloadedMaps.GetArray(data, download)
    DeleteFile(download.outputPath);
    PrintToChatAll("[ZMAP] %s has been installed", download.mapName);
    PrintToChatAll("[ZMAP] Changing map to %s...", download.mapName);

    DataPack dp;
    dp.WriteString(download.mapName);
    CreateDataTimer(3.0, Timer_ChangeMap, dp);
}

public void DownloadCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) {
    char outputPath[PLATFORM_MAX_PATH];
    DownloadInformation download;

    DownloadedMaps.GetArray(request.Any, download)
    request.GetOutputFile(outputPath, sizeof(outputPath));

    if (!success || response.StatusCode != 200) {
        PrintToChat(download.issuer, "[ZMAP] %s could not be located.", download.mapName)
        DeleteFile(outputPath);
    } else {
        PrintToChat(download.issuer, "[ZMAP] Installing %s....", download.mapName)
        System2_Extract(ExtractCallback, outputPath, "maps/", request.Any);
    }
}