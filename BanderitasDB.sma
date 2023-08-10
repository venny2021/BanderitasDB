#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <sqlx>
#include <fakemeta>
#include <tfcx>
#include <curl>


#define PLUGIN "EOTR Flags" // End of the Round Flags
#define VERSION "1.0"
#define AUTHOR "ZePinkie"

#define SQLITE		0
#define MYSQL		1

// Editables
#define SAVE_TYPE		1
#define ADMIN_ACCESS_LETTER	"e"
#define TOP_DEFAULT_NUMBER	15
#define CURL_BUFFER_SIZE 512

// Ian
new redScore = 0, blueScore = 0; // Inicializamos los scores en 0 cada vez que empieza el sv
new g_mp_timelimit
new szMapName[32];
new szPreviousMapName[32];
new Handle:g_hSqlHandle, g_szQuery[512];
new MatchID, prevMatchId, prevCapturasAzul, prevMapname[32]; // esto en pawn
new bool:Insertado = false
new bool:FirstUpdate=true;
new const g_iTimeBetweenCalls = 3;
new g_iLastCall;


    

#if SAVE_TYPE == MYSQL
new const SQL_CONNECT_DATA[][] = {
	"server", // Server
	"user", // USER
	"pass",  // PASS
	"db" // DBaa
};
#endif

public plugin_end()
{
	SQL_FreeHandle(g_hSqlHandle);
	new pCvarTimeLeft = get_cvar_pointer("mp_timelimit")
	new iTimeLimit = get_pcvar_num( pCvarTimeLeft )
	/* if(equali(prevMapname,szMapName) &&  )
		{
			curl_request_stats()
		} */
}

public plugin_init()
{
  register_plugin(PLUGIN, VERSION, AUTHOR)
  
  //FER
  register_clcmd("say !score", "cmdScore");
  register_clcmd("say !scores", "cmdScore");
  //FER
  
  // Ian
  register_message(get_user_msgid("TeamScore"), "traerBanderas");
  g_mp_timelimit = get_cvar_pointer("mp_timelimit");
  set_task(2.0,"verTiempo");
  register_cvar("score_delay","1.0") // tiempo en segundos
  // fin ian
  
  #if SAVE_TYPE == MYSQL
  SQL_SetAffinity("mysql");
  g_hSqlHandle = SQL_MakeDbTuple(SQL_CONNECT_DATA[0], SQL_CONNECT_DATA[1], SQL_CONNECT_DATA[2], SQL_CONNECT_DATA[3]);
  #endif
  g_iLastCall = get_systime();
}

public client_putinserver(id)
{
  server_print("Chequeando Players")
  if (Insertado == true)
    return PLUGIN_HANDLED// Si esto ya corrió no hay necesidad de correrlo de vuelta
  else
    set_task(2.0, "initializemap",9991,"",0) // Si no, corremos la task
    
   return PLUGIN_CONTINUE
}

public initializemap(taskid)
{
    new players[32], num
    get_players(players, num, "") // Check teams of all connected players.
	
	//Traer Score de la partida anterior (por ahora sin importar el mapa)
	formatex(g_szQuery, charsmax(g_szQuery), "SELECT MatchID, CapturasAzul, Mapname FROM partidas ORDER BY 1 DESC LIMIT 1");
	
    SQL_ThreadQuery(g_hSqlHandle,"QueryHandler_GetPreviousMap", g_szQuery);
	// First Part

    if (num < 7)
    {
        server_print("No hay players suficientes (%i) para grabar partida",num)
		    Insertado = false
        return // Si hay menos de 8 jugadores no hacer nada
    }
    else
    {
        if (Insertado == true)
            return // Si esto ya corrió no hay necesidad de correrlo de vuelta
        new dia, mes, ano, hora, minuto, segundo
        date(ano, mes, dia)
        time(hora, minuto, segundo)
        new Fecha[64]
        formatex(Fecha, 63, "%i-%i-%i %i:%i:%i", ano, mes, dia, hora, minuto, segundo)

        //Base de datos cada vez que se cambia de mapa
        get_mapname(szMapName, charsmax(szMapName));
        FormatQuery(g_szQuery, charsmax(g_szQuery), "INSERT INTO partidas (Mapname, CapturasAzul, Equipo1, Equipo2, Equipo1_steamId, Equipo2_steamId , Espectadores, Fecha) VALUES ('%s', '%i', 'Azul', 'Rojo', 'SteamIdAzul', 'SteamIdRojo', 'Specs', '%s')"
                                                    , szMapName, blueScore, Fecha ); // Primer Query cuando inicia el map
        SQL_ThreadQuery(g_hSqlHandle,"QueryHandler_InsertMatch", g_szQuery);

        formatex(g_szQuery, charsmax(g_szQuery), "SELECT MatchID FROM partidas WHERE Mapname = '%s' ORDER BY 1 DESC LIMIT 1", szMapName)
        SQL_ThreadQuery(g_hSqlHandle,"QueryHandler_GetMatchID", g_szQuery);
        Insertado = true
        remove_task(9991,0)
    }
}

// Ian traer Flags cada vez q updatean
public traerBanderas()
{
    if (Insertado == false)
    {
        server_print("No se insertó")
        return // Si hay menos de 8 jugadores no hacer nada
    }
  new players[32], num
  get_players(players, num, "") // Check teams of all connected players.
  if (num < 7)
    return // Si hay menos de 8 jugadores no hacer nada
    
  // esta funcion la llama cada vez que se actualiza algo de un equipo
  // p ejemplo, cuando alguien cambia de team
  static team[4]
  get_msg_arg_string(1, team, charsmax(team)) // traer los equipos cuando se llama al teamScore
	
	switch (team[0]) // agarrar la primer letra del nombre del team
	{
		// Red
		case 'B': blueScore = get_msg_arg_int(2)
		// Blue
		case 'R': redScore = get_msg_arg_int(2)
	}

	new playername[32], Bluepl_steamId[255];
	new Bluepl[255], Redpl[255];
	new NuevoNombreSteamId[255]
	new steamId[32];
	new id;
	//new Spectators[255]

    for (id = 0; id <= num; id++)
    {
        get_user_name( players[id],playername, 32)
        get_user_authid( players[id], steamId, charsmax(steamId))
        if (get_user_team(players[id]) != 1 && get_user_team(players[id]) != 2 )
        {
            //add(Spectators, 254, playername, 32)
            //add(Spectators, 254, " - ", 3)
        }
        else if ( get_user_team(players[id]) == 1)
        {
			while(contain(playername,"'") != -1)
			{
				replace(playername, charsmax(playername), "'", "");
			}
            add(Bluepl, 254, playername, 32)
            add(Bluepl, 254, " - ", 3)
            add(Bluepl_steamId, 254, steamId, 32)
            add(Bluepl_steamId, 254, " - ", 3)
        }
        else if ( get_user_team(players[id]) == 2)
        {
			while(contain(playername,"'") != -1)
			{
				replace(playername, charsmax(playername), "'", "");
			}
            add(Redpl, 254, playername, 32)
            add(Redpl, 254, " - ", 3)
            add(NuevoNombreSteamId, 254, steamId, 32)
            add(NuevoNombreSteamId, 254, " - ", 3)
        }
    }

  	// llamar a la db y updatear scores
  	
	if(blueScore == 10 && FirstUpdate)
	{
		server_print("UPDATE redpl %s, redplStemId %s", Redpl, NuevoNombreSteamId)
		formatex(g_szQuery, charsmax(g_szQuery), "UPDATE partidas SET CapturasAzul='%i', Equipo1='%s', Equipo2='%s', Equipo1_steamId='%s', Equipo2_steamId='%s', Espectadores='' WHERE MatchID = %i ", blueScore, Bluepl, Redpl, Bluepl_steamId, NuevoNombreSteamId, MatchID )
		FirstUpdate = false;
	}else{
		formatex(g_szQuery, charsmax(g_szQuery), "UPDATE partidas SET CapturasAzul='%i' WHERE MatchID = %i ", blueScore, MatchID )
	}
	SQL_ThreadQuery(g_hSqlHandle,"QueryHandler_Dump", g_szQuery); // UPDATEAMOS LA TABLA CON LAS CAPTURAS
  
  //client_print(0,print_chat,"El equipo azul tiene %i puntos de captura",blueScore)

}

// Revisar tiempo de delay entre puntajes
public verTiempo()
{
  new Float:time = get_cvar_float("score_delay")
  if(time != 0.0)
  {
    time = floatabs(time)
    if(time < 1.0)
      time = 1.0

    update_scores()
    set_task(time,"update_scores",1,"",0,"b") // aca llamamos a update scores, cada delay que dijimos
  }
}


// Actualizar puntines

public update_scores()
{
    if (Insertado == false)
    {
        server_print("No se insertó")
        return // Si hay menos de 8 jugadores no hacer nada
    }
  // Esto se llama cada vez que pasa x cantidad de tiempo, segun diga el delay de score_delay
  static s;
  if(get_pcvar_float(g_mp_timelimit))
  {
    s = get_timeleft()
    if (s <= 3)
    {
		new players[32], num
		get_players(players, num, "") // Check teams of all connected players.
		if (num < 7)
		return
		//Llamar a la DB y updatear los scores
		//client_print(0,print_chat,"El equipo azul tiene %i banderas faltando %i segundos",blueScore, s)
		FormatQuery(g_szQuery, charsmax(g_szQuery), "UPDATE partidas SET CapturasAzul = %i WHERE MatchID = %i ", blueScore, MatchID )
		
		SQL_ThreadQuery(g_hSqlHandle,"QueryHandler_Dump", g_szQuery); // UPDATEAMOS LA TABLA CON LAS CAPTURAS
    }
  // send to bot here, cada segundo o en el delay que manda
  }
}
/// Puntaje anterior

public cmdScore(id)
{	
	client_print(0,print_chat, "El score del mapa anterior fue %i en %s",prevCapturasAzul,prevMapname);
	return PLUGIN_CONTINUE;
}

public client_PreThink(id)
{
	if( !is_user_alive(id) )
	{
		return PLUGIN_CONTINUE;
	}
	
	static iCurTime;
	
	if(((iCurTime = get_systime()) - g_iLastCall) > g_iTimeBetweenCalls)
	{
		if(entity_get_int(id,EV_INT_button) & IN_SCORE)
		{
			g_iLastCall = iCurTime;
			new timeleft = get_timeleft();
			set_hudmessage(255, 255, 255, 0.01, 0.3, 0, 0, 3.0, 0.1, 0.2, 13);
			show_hudmessage(id,"Timeleft: %d:%02d^nScore: %i",timeleft / 60, timeleft % 60, prevCapturasAzul);
		}
	}
	return PLUGIN_CONTINUE
}

//Cosas de SQL y handlers

stock FormatQuery(szQueryStorage[], iSize, szQuery[], any:...)
{
	replace(g_szQuery, charsmax(g_szQuery),"'","\'")
	vformat(szQueryStorage, iSize, szQuery, 4);
}

public QueryHandler_InsertMatch(FailState, Handle:hQuery, szError[], iError, Data[], iDataSize)
{
  server_print(" --> Resolved query %d, took %f seconds", Data[0], 1.0)
	if (FailState)
	{
		if (FailState == TQUERY_CONNECT_FAILED)
		{
			server_print(" --> Connection failed!")
		} else if (FailState == TQUERY_QUERY_FAILED) {
			server_print(" --> Query failed!")
		}
		server_print(" --> Error code: %d (Message: ^"%s^")", iError, szError)
	}
}

public QueryHandler_GetMatchID(FailState, Handle:hQuery, szError[], iError, Data[], iDataSize)
{
	server_print(" --> Resolved query %d, took %f seconds", Data[0], 1.0)
	if (FailState)
	{
		if (FailState == TQUERY_CONNECT_FAILED)
		{
			server_print(" --> Connection failed!")
		} else if (FailState == TQUERY_QUERY_FAILED) {
			server_print(" --> Query failed!")
		}
		server_print(" --> Error code: %d (Message: ^"%s^")", iError, szError)
		
		new querystring[1024]
		SQL_GetQueryString(hQuery, querystring, 1023)
		server_print(" --> Original query: %s", querystring)
	} else {
		GetMatchId(hQuery)
	}
}


public QueryHandler_GetPreviousMap(FailState, Handle:hQuery, szError[], iError, Data[], iDataSize)
{
	server_print(" --> Resolved query %d, took %f seconds", Data[0], 1.0)
	if (FailState)
	{
		if (FailState == TQUERY_CONNECT_FAILED)
		{
			server_print(" --> Connection failed!")
		} else if (FailState == TQUERY_QUERY_FAILED) {
			server_print(" --> Query failed!")
		}
		server_print(" --> Error code: %d (Message: ^"%s^")", iError, szError)
		
		new querystring[1024]
		SQL_GetQueryString(hQuery, querystring, 1023)
		server_print(" --> Original query: %s", querystring)
	} else {
		GetPreviousMap(hQuery)
	}
}

HacerQueryPuntos(Handle:query)
{
	static querystring[2048]
	SQL_GetQueryString(query, querystring, 2047)
	server_print("Original query string: %s", querystring)

}

GetMatchId(Handle:query)
{
	new columns = SQL_NumColumns(query)
	new rows = SQL_NumResults(query)
	static querystring[2048]
	
	SQL_GetQueryString(query, querystring, 2047)
	
	server_print("Original query string: %s", querystring)
	server_print("Query columns: %d rows: %d", columns, rows)

    MatchID = SQL_ReadResult(query, 0)
    server_print("MatchID = %i", MatchID)
}

GetPreviousMap(Handle:query)
{
	new columns = SQL_NumColumns(query)
	new rows = SQL_NumResults(query)
	static querystring[2048]
	
	SQL_GetQueryString(query, querystring, 2047)
	
	server_print("Original query string: %s", querystring)
	server_print("Query columns: %d rows: %d", columns, rows)

    SQL_ReadResult(query, 0, prevMatchId)
	SQL_ReadResult(query, 0, prevCapturasAzul)
	SQL_ReadResult(query, 2, prevMapname, 31)
    server_print("MatchID Ant = %i, Score Ant = %i, MapAnterior = %s", prevMatchId, prevCapturasAzul, prevMapname)
}

public QueryHandler_Dump(FailState, Handle:hQuery, szError[], iError, Data[], iDataSize)
{
	server_print(" --> Resolved query %d, took %f seconds", Data[0], 1.0)
	if (FailState)
	{
		if (FailState == TQUERY_CONNECT_FAILED)
		{
			server_print(" --> Connection failed!")
		} else if (FailState == TQUERY_QUERY_FAILED) {
			server_print(" --> Query failed!")
		}
		server_print(" --> Error code: %d (Message: ^"%s^")", iError, szError)
	} else {
		HacerQueryPuntos(hQuery)
	}
}

public curl_request_stats()
{
	new data[1]
	new CURL:curl = curl_easy_init()
	curl_easy_setopt(curl, CURLOPT_BUFFERSIZE, CURL_BUFFER_SIZE)
	curl_easy_setopt(curl, CURLOPT_URL, "your/endpoint/logs")
	curl_easy_setopt(curl, CURLOPT_WRITEDATA, data[0])
	curl_easy_perform(curl, "complite", data, sizeof(data))
}

public complite(CURL:curl, CURLcode:code, data[])
{
	if(code == CURLE_WRITE_ERROR)
	{
		server_print("transfer aborted")
	}else
	{
     	server_print("curl complete")
	}
	fclose(data[0])
	curl_easy_cleanup(curl)
}
