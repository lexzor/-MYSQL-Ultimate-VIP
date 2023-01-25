

// Tagul din chat
#define CHAT_PREFIX "^4[PAYPAL VIP]^1"

// Este afisat ca si prefix in titlul meniului
#define MENU_TITLE_PREFIX "\r[PAYPAL VIP]\w"

// Fisierul logs (in /cstrike/addons/amxmodx/logs)
#define LOG_FILE "paypal_vip.log"

// Numele fisierului din configs
#define FOLDER_NAME "paypal_vip"

// Fisierul unde se baga hartile restrictionate, se afla in configs/FOLDER_NAME
#define RESTRICTED_MAPS_FILE "paypal_restricted_maps.ini"

// Configul care executa cvarurile setate, se afla in configs/FOLDER_NAME
#define CONFIG_FILE "paypal_vip_settings.cfg"

// Prefixul pluginului din consola
#define PLUGIN_PREFIX "[PAYPAL_VIP]"

// Cate meniuri sunt bagate in api-ul meniului (2 -> adica weapons menu si account settings)
#define DEFAULT_MENU_ITEMS 2

#define IsValid(%0) (0 < %0 < get_maxplayers())
#define MAX_PASSWORD_LENGTH 24
#define MAX_LOGIN_ATTEMPS 3

#define MAX_IP_LENGTH_WITHOUT_PORT 16 // 22 WITH PORT

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <hamsandwich>
#include <sqlx>
#include <fun>
#include <paypal_vip>

new const   PLUGIN[] = "Paypal VIP",
            VERSION[] = "0.1",
            AUTHOR[] = "lexzor";

//CONFIG FILE

enum _:SETTINGS
{
    PISTOL_ROUNDS,
    bool:REGISTER_STATE,
    DIAMOND_WEAPONS[25],
    DIAMOND_PISTOL,
    DIAMOND_HEGRENADE,
    DIAMOND_SMOKEGRENADE,
    DIAMOND_FLASHBANG,
    DIAMOND_THIGHPACK,
    DIAMOND_HEALTH,
    DIAMOND_ARMOR,
    GOLD_WEAPONS[25],
    GOLD_PISTOL,
    GOLD_HEGRENADE,
    GOLD_SMOKEGRENADE,
    GOLD_FLASHBANG,
    GOLD_THIGHPACK,
    GOLD_HEALTH,
    GOLD_ARMOR,
    SILVER_WEAPONS[25],
    SILVER_PISTOL,
    SILVER_HEGRENADE,
    SILVER_SMOKEGRENADE,
    SILVER_FLASHBANG,
    SILVER_THIGHPACK,
    SILVER_HEALTH,
    SILVER_ARMOR
}

enum _:PLUGIN_DATA
{
    iCurrRound
}

enum _:USER_DATA 
{
    szName[MAX_NAME_LENGTH],
    szAuthID[MAX_AUTHID_LENGTH],
    szInternetAddress[MAX_IP_LENGTH_WITHOUT_PORT],
    iVIPLevel,
    bool:bLogged,
    szPassword[MAX_PASSWORD_LENGTH],
    szEmail[64],
    iLoginAttempts,
    bool:bAutoLogin,
    bool:bAutoMenu,
    bool:bAccountExists,
    iCurrentMenu
}

enum _:WEAPONS
{
	WeapName[200],
	WeaponID[32],
	BpAmmo
}

enum _:SQL_DATA
{
    MYSQL_HOST[64],
    MYSQL_USER[64],
    MYSQL_PASS[64],
    MYSQL_DB[64]
}

enum _:FORWARDS
{
    LOGGED_IN_PRE,
    LOGGED_IN_POST,
    MENU_ITEM_SELECTED
}

enum (+= 1000)
{
    OPEN_MENU_TASK = 1000,
    CHECK_DATABASE_TASK,
    AUTO_MENU_TASK,
}

enum _:MENUAPI
{
    TITLE[64],
    FUNCTION_CALLBACK[20],
    POSITION
}

enum (+=1)
{
    USER_REGISTERED = 0,
    USER_LOGGED_IN
}

enum (+=1)
{
    REGISTER = 0,
    LOGIN
}

new const g_szFileData[][] = 
{
    "# Hello! This is your config file for VIP System.^n",
    "# You will have explanation for every cvar and command.^n",
    "# We won't advertise our discord on your server, you can find discord server only from console server.^n^n^n",
    "# SQL Database. You must complete this^n",
    "paypal_sql_host    ^"127.0.0.1^"^n",
    "paypal_sql_user    ^"root^"^n",
    "paypal_sql_pass    ^"password^"^n",
    "paypal_sql_db    ^"database^"^n^n^n",
    "# This cvar enable(1)/disable(0) register on server.^n",
    "enable_register ^"1^"^n^n^n",
    "# How many rounds should show pistol menu^n",
    "pistol_rounds ^"3^"^n^n^n",
    "# Info: In weapon menu settings, you can set one pistol ID and how many grenades you want the VIP to get.^n",
    "# For pack_weapon flag ^"z^" means the VIP won't get any weapon in his menu, but you can give him a pistol.^n",
    "# For not giving a pistol the ID is 0. If you set both no weapon flag and no pistol id then the menu will show there are no weapons to choose from^n^n",
    "# Weapons menu for VIP Diamond pack^n",
    "diamond_health ^"100^"^n",
    "diamond_armor ^"100^"^n",
    "diamond_weapon ^"abc^"^n",
    "diamond_pistol ^"1^"^n",
    "diamond_grenade ^"1^"^n",
    "diamond_flash ^"2^"^n",
    "diamond_defusekit ^"1^"^n^n^n",
    "# Weapons menu for VIP Gold pack^n",
    "gold_health ^"100^"^n",
    "gold_armor ^"100^"^n",
    "gold_weapon ^"abc^"^n",
    "gold_pistol ^"1^"^n",
    "gold_grenade ^"1^"^n",
    "gold_flash ^"2^"^n",
    "gold_defusekit ^"0^"^n^n^n",
    "# Weapons menu for VIP Silver pack^n",
    "silver_health ^"100^"^n",
    "silver_armor ^"100^"^n",
    "silver_weapon ^"abc^"^n",
    "silver_pistol ^"1^"^n",
    "silver_grenade ^"1^"^n",
    "silver_flash ^"2^"^n",
    "silver_defusekit ^"0^"^n^n^n"
};

new const g_szBlockedMapsData[][] = 
{
    "# Here you can add restricted maps where some benefits of plugin won't work!^n",
    "# You must put it one above another.^n^n^n"
};

new const VIP_MENU_CMD[][] = 
{
    "/vmenu",
    "/vipmenu",
    "/vm",
    "!vipmenu",
    "!vmenu" ,
    "!vm"   
};

new const REGISTER_MENU_CMD [][] = 
{
    "/register",
    "!register"
};


new const LOGIN_MENU_CMD[][] = 
{
    "/login",
    "!login",   
};


new g_eCvar[SETTINGS];
new g_eUserData[MAX_PLAYERS + 1][USER_DATA];
new bool:g_bRestrictedMap;
new g_eForwards[FORWARDS];
new g_iMenuItems;
new g_ePluginData[PLUGIN_DATA];

new const ALPHABET[] = "zabcdefghijklmnopqrs";

new const g_Weapons[][WEAPONS] =
{
    {"", "", 0},
    {"AK47", "weapon_ak47", 90},
    {"M4A1", "weapon_m4a1", 90},
    {"AWP", "weapon_awp", 90},
    {"G3SG-1", "weapon_g3sg1", 90},
    {"SG-550", "weapon_sg550", 90},
    {"Scout", "weapon_scout", 90},
    {"SG-552", "weapon_sg552", 90},
    {"AUG", "weapon_aug", 90},
    {"Galil", "weapon_galil", 90},
    {"Famas", "weapon_famas", 90},
    {"M249", "weapon_m249", 200},
    {"MAC10", "weapon_mac10", 100},
    {"TMP", "weapon_tmp", 120},
    {"MP5 Navy", "weapon_mp5navy", 120},
    {"UMP", "weapon_ump45", 100},
    {"P90", "weapon_p90", 100},
    {"M3 super 90", "weapon_m3", 32},
    {"XM1014", "weapon_xm1014", 32}
};

new const g_Pistols[][WEAPONS] = 
{
    {"", "", 0},
    {"Deagle", "weapon_deagle", 35},
    {"Glock 18", "weapon_glock18", 120},
    {"USP", "weapon_usp", 100},
    {"P228", "weapon_p228", 52},
    {"FN Five-seveN", "weapon_fiveseven", 100},
    {"Dual Elite Berettas", "weapon_elite", 120}

};

new Handle:g_SqlTuple;
new g_Error[512];
new g_eSQL[SQL_DATA];

new Array:g_aMainMenu;

new const g_szTables[][] =
{
    "Player_Accounts"
}

new const g_szTablesInfo[][] =
{
    "( `id` INT(11) NOT NULL AUTO_INCREMENT ,\
	`uname` VARCHAR(96) NOT NULL DEFAULT 'NONE' ,\
	`authid` VARCHAR(64) NOT NULL DEFAULT 'NONE' ,\
	`last_authid` VARCHAR(64) NOT NULL DEFAULT 'NONE' ,\
	`ip` VARCHAR(40) NOT NULL DEFAULT 'NONE' ,\
	`last_ip` VARCHAR(40) NOT NULL DEFAULT 'NONE' ,\
	`email` VARCHAR(40) NOT NULL DEFAULT 'NONE' ,\
	`upassword` VARCHAR(40) NOT NULL DEFAULT 'NONE' ,\
    `vip_level` INT(1) NOT NULL DEFAULT 0 ,\
    `auto_login` INT(1) NOT NULL DEFAULT 0 ,\
    `auto_menu` INT(1) NOT NULL DEFAULT 0 ,\
	PRIMARY KEY (`id`));"
}

//PLUGIN START

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_dictionary("paypal_vip.txt");

    set_settings();

    g_aMainMenu = ArrayCreate(MENUAPI);

    RegisterHam(Ham_Spawn, "player", "fwHamPlayerSpawnPost", 1);

    g_eForwards[LOGGED_IN_PRE] = CreateMultiForward("paypal_user_logged_in_pre", ET_IGNORE, FP_CELL);
    g_eForwards[LOGGED_IN_POST] = CreateMultiForward("paypal_user_logged_in_post", ET_IGNORE, FP_CELL);
    g_eForwards[MENU_ITEM_SELECTED] = CreateMultiForward("paypal_menu_selected", ET_IGNORE, FP_CELL, FP_CELL)

    register_clcmd("say", "sayHook");
    register_clcmd("say_team", "sayHook");

    register_concmd("uEmail", "concmd_email", -1, "", -1, false);
    register_concmd("uPassword", "concmd_password", -1, "", -1, false);

    register_event("TeamInfo", "team_info", "a");
    register_logevent("logev_Restart", 2, "1&Restart_Round", "1&Game_Commencing");
    register_event("HLTV", "ev_NewRound", "a", "1=0", "2=0") 

    register_cvar("paypal_vip", VERSION, FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_UNLOGGED|FCVAR_SPONLY);
}

public plugin_end()
{
    ArrayDestroy(g_aMainMenu);
    SQL_FreeHandle(g_SqlTuple);
    DestroyForward(g_eForwards[LOGGED_IN_PRE])
    DestroyForward(g_eForwards[LOGGED_IN_POST])
    DestroyForward(g_eForwards[MENU_ITEM_SELECTED])
}

public plugin_natives()
{
    register_library("paypal_vip");

    register_native("paypal_get_user_vip_level", "_get_user_vip_level", 0);
    register_native("paypal_set_user_vip_level", "_set_user_vip_level", 0);
    register_native("paypal_is_user_logged_in", "_is_user_logged_in", 0);
    register_native("paypal_register_menu", "_paypal_register_menu", 0);
    register_native("paypal_main_menu", "_paypal_main_menu", 0);
}

public logev_Restart()
{
    g_ePluginData[iCurrRound] = 0
}

public ev_NewRound()
{
    g_ePluginData[iCurrRound]++;
}

public client_connect(id)
{
    g_eUserData[id][iVIPLevel] = NO_VIP;
    g_eUserData[id][bLogged] = false;
    g_eUserData[id][iCurrentMenu] = -1;
    g_eUserData[id][bAutoMenu] = false;
    g_eUserData[id][bAutoLogin] = false;
    reset_strings(id);
}

public client_putinserver(id)
{
    if(is_user_bot(id) || is_user_hltv(id))
        return PLUGIN_CONTINUE;

    get_user_name(id, g_eUserData[id][szName], charsmax(g_eUserData[][szName]))
    get_user_ip(id, g_eUserData[id][szInternetAddress], charsmax(g_eUserData[][szInternetAddress]), 1)
    get_user_authid(id, g_eUserData[id][szAuthID], charsmax(g_eUserData[][szAuthID]))

    check_account(id)

    return PLUGIN_CONTINUE;
}

public sayHook(id)
{
    static szArg[192];
    read_args(szArg, charsmax(szArg));
    remove_quotes(szArg);

    for(new i; i < sizeof(VIP_MENU_CMD); i++)
    {
        if(equali(szArg, VIP_MENU_CMD[i]))
        {     
            set_task(0.1, "vip_menu", id + OPEN_MENU_TASK); 
        }
    }

    
    for(new i; i < sizeof(LOGIN_MENU_CMD); i++)
    {
        if(equali(szArg, LOGIN_MENU_CMD[i]))
        {     
            set_task(0.1, "login_menu", id + OPEN_MENU_TASK); 
        }
    }

    
    for(new i; i < sizeof(REGISTER_MENU_CMD); i++)
    {
        if(equali(szArg, REGISTER_MENU_CMD[i]))
        {     
            set_task(0.1, "reg_menu", id + OPEN_MENU_TASK); 
        }
    }
}

public vip_menu(id)
{
    if(!IsValid(id))
        id -= OPEN_MENU_TASK;

    if(!pp_is_user_logged(id))
    {
        client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "MUST_BE_LOGGED_IN");
        return PLUGIN_HANDLED;
    }

    new iMenu, szTitle[128], szItem[64], szExitName[20], szBackName[20];    

    formatex(szTitle, charsmax(szTitle), "%s %l", MENU_TITLE_PREFIX, "MAIN_MENU_TITLE");

    iMenu = menu_create(szTitle, "vip_menu_handler", false);

    formatex(szItem, charsmax(szItem), "%l", "WEAPON_MENU_OPTION");
    menu_additem(iMenu, szItem);

    formatex(szItem, charsmax(szItem), "%l", "ACCOUNT_SETTINGS");
    menu_additem(iMenu, szItem);

    new eMenuData[MENUAPI], iSize;

    if((iSize = ArraySize(g_aMainMenu)) > 0 )
    {
        for(new i; i < iSize; i++)
        {
            ArrayGetArray(g_aMainMenu, i, eMenuData)
            menu_additem(iMenu, eMenuData[TITLE]);
        }
    }

    formatex(szExitName, charsmax(szExitName), "%l", "MENU_EXIT_NAME");
    formatex(szBackName, charsmax(szBackName), "%l", "MENU_BACK_NAME");

    menu_setprop(iMenu, MPROP_EXITNAME, szExitName);
    menu_setprop(iMenu, MPROP_BACKNAME, szBackName);
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);

    if(is_user_connected(id))
        menu_display(id, iMenu, 0, -1)

    return PLUGIN_CONTINUE;
}

public vip_menu_handler(id, menu, item)
{

    if(item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    if(g_eUserData[id][iVIPLevel] == NO_VIP)
    {
        client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "MUST_BE_VIP");
        return PLUGIN_CONTINUE;
    }

    switch(item)
    {
        case 0:
        {
            if(g_bRestrictedMap == true)
            {
                client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "WEAPON_MENU_BLOCKED");
            }
            else
            {
                weapon_menu(id);
            }
        }

        case 1:
        {
            new szTitle[128], szItem[64], szExitName[20], szBackName[20];
            formatex(szTitle, charsmax(szTitle), "%s %l", MENU_TITLE_PREFIX, "ACCOUNT_SETTINGS_MENU_TITLE")
            new iMenu = menu_create(szTitle, "account_setting_menu_handler");

            formatex(szItem, charsmax(szItem), "%s%l",
            g_eUserData[id][bAutoLogin] ? "\w" : "\d", "AUTO_LOGIN_TOGGLE", g_eUserData[id][bAutoLogin] ? "ON" : "OFF");
            menu_additem(iMenu, szItem);

            formatex(szItem, charsmax(szItem), "%s%l",
            g_eUserData[id][bAutoMenu] ? "\w" : "\d", "AUTO_MENU_TOGGLE", g_eUserData[id][bAutoMenu] ? "ON" : "OFF");
            menu_additem(iMenu, szItem);

            formatex(szExitName, charsmax(szExitName), "%l", "MENU_EXIT_NAME");
            formatex(szBackName, charsmax(szBackName), "%l", "MENU_BACK_NAME");

            menu_setprop(iMenu, MPROP_EXITNAME, szExitName);
            menu_setprop(iMenu, MPROP_BACKNAME, szBackName);
            menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);

            if(is_user_connected(id))
                menu_display(id, iMenu, 0, -1)
        }

        default:
        {
            new ret;

            ExecuteForward(g_eForwards[MENU_ITEM_SELECTED], ret, id, (item - DEFAULT_MENU_ITEMS));
        }
    }

    menu_destroy(menu)
    return PLUGIN_CONTINUE;
}

public account_setting_menu_handler(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    switch(item)
    {
        case 0:
        {
            g_eUserData[id][bAutoLogin] = !g_eUserData[id][bAutoLogin];

            client_print_color(id, print_team_default, "%s %l",
            CHAT_PREFIX, "AUTO_LOGIN_MSG", g_eUserData[id][bAutoLogin] ? "enabled" : "disabled");
        }

        case 1:
        {
            g_eUserData[id][bAutoMenu] = !g_eUserData[id][bAutoMenu];

            client_print_color(id, print_team_default, "%s %l",
            CHAT_PREFIX, "AUTO_MENU_MSG", g_eUserData[id][bAutoMenu] ? "enabled" : "disabled");
        }
    }

    SQL_ThreadQuery(g_SqlTuple,
    "FreeHandle",
    fmt("UPDATE `%s` SET `auto_login` = '%i', `auto_menu` = '%i' WHERE `email` = '%s'",
    g_szTables[0], g_eUserData[id][bAutoLogin] ? 1 : 0, g_eUserData[id][bAutoMenu] ? 1 : 0, g_eUserData[id][szEmail]));

    return PLUGIN_CONTINUE;
}

public login_menu(id)
{
    if(!IsValid(id))
        id -= OPEN_MENU_TASK;

    new szTitle[128], szItem[64], szExitName[20], szBackName[20];
    
    if(pp_is_user_logged(id))
    {
        client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "ALREADY_LOGGED");
        return PLUGIN_HANDLED;    
    }
    
    g_eUserData[id][iCurrentMenu] = LOGIN

    formatex(szTitle, charsmax(szTitle), "%s %l", MENU_TITLE_PREFIX, "LOGIN_MENU_TITLE");

    new iMenu = menu_create(szTitle, "login_menu_handler", false);

    formatex(szItem, charsmax(szItem), "%l", "EMAIL_OPTION", g_eUserData[id][szEmail]);
    menu_additem(iMenu, szItem);

    formatex(szItem, charsmax(szItem), "%l^n", "PASSWORD_OPTION", g_eUserData[id][szPassword]);
    menu_additem(iMenu, szItem);

    formatex(szItem, charsmax(szItem), "%l", "LOG_IN_OPTION");
    menu_additem(iMenu, szItem, "0");

    formatex(szExitName, charsmax(szExitName), "%l", "MENU_EXIT_NAME");
    formatex(szBackName, charsmax(szBackName), "%l", "MENU_BACK_NAME");

    menu_setprop(iMenu, MPROP_EXITNAME, szExitName);
    menu_setprop(iMenu, MPROP_BACKNAME, szBackName);
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);

    if(is_user_connected(id))
        menu_display(id, iMenu, 0, -1)

    return PLUGIN_CONTINUE;
}

public login_menu_handler(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    if(pp_is_user_logged(id))
    {
        client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "ALREADY_LOGGED");
        return PLUGIN_HANDLED;
    }

    new szData[1];
    menu_item_getinfo(menu, item, _, szData, charsmax(szData), _, _, _);
    menu_destroy(menu);

    new iType = str_to_num(szData);

    switch(item)
    {
        case 0:
        {
            client_cmd(id, "messagemode uEmail");
        }

        case 1:
        {
            client_cmd(id, "messagemode uPassword");
        }

        case 2:
        {
            if(!g_eUserData[id][szEmail][0] || !g_eUserData[id][szPassword])
            {
                client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "NO_CREDENTIALS");
                login_menu(id);
                return PLUGIN_HANDLED;
            }

            new ret;
            ExecuteForward(g_eForwards[LOGGED_IN_PRE], ret, id);

            switch(iType)
            {
                case 0:
                {
                    if(g_eUserData[id][bAccountExists] == true)
                    {
                        g_eUserData[id][bLogged] = true;
                        client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "LOGGED_IN_SUCCESFULLY");

                        new ret;
                        ExecuteForward(g_eForwards[LOGGED_IN_POST], ret, id);

                        vip_menu(id)
                    }
                    else
                    {
                        log_in(id)
                    }
                }

                case 1: 
                {
                    register_user(id);
                }
            }
        }
    }   

    return PLUGIN_HANDLED;
}

public reg_menu(id)
{
    if(!IsValid(id))
        id -= OPEN_MENU_TASK;

    new iMenu, szTitle[128], szItem[64], szExitName[20], szBackName[20];

    if(g_eUserData[id][bAccountExists])
    {
        client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "ALREADY_HAS_ACCOUNT");
        return PLUGIN_HANDLED; 
    }
    
    if(pp_is_user_logged(id))
    {
        client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "ALREADY_LOGGED");
        return PLUGIN_HANDLED;    
    }

    g_eUserData[id][iCurrentMenu] = REGISTER;
    
    formatex(szTitle, charsmax(szTitle), "%s %l", MENU_TITLE_PREFIX, "REGISTER_MENU_TITLE");

    iMenu = menu_create(szTitle, "login_menu_handler", false);

    formatex(szItem, charsmax(szItem), "%l", "EMAIL_OPTION", g_eUserData[id][szEmail]);
    menu_additem(iMenu, szItem);

    formatex(szItem, charsmax(szItem), "%l^n", "PASSWORD_OPTION", g_eUserData[id][szPassword]);
    menu_additem(iMenu, szItem);

    formatex(szItem, charsmax(szItem), "%l", "REGISTER_OPTION");
    menu_additem(iMenu, szItem, "1");

    formatex(szExitName, charsmax(szExitName), "%l", "MENU_EXIT_NAME");
    formatex(szBackName, charsmax(szBackName), "%l", "MENU_BACK_NAME");

    menu_setprop(iMenu, MPROP_EXITNAME, szExitName);
    menu_setprop(iMenu, MPROP_BACKNAME, szBackName);
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);

    if(is_user_connected(id))
        menu_display(id, iMenu, 0, -1)

    

    return PLUGIN_CONTINUE;
}

public team_info(id)
{
    new id = read_data(1);
    new szTeam[2]
    read_data(2, szTeam, charsmax(szTeam))

    if(!is_user_bot(id) &&
    !is_user_hltv(id) &&
    is_user_connected(id) &&
    szTeam[0] != 'U' &&
    !pp_is_user_logged(id) &&
    g_eUserData[id][bAccountExists] &&
    g_eUserData[id][bAutoLogin])
    {
        g_eUserData[id][bLogged] = true;
        
        new ret;
        ExecuteForward(g_eForwards[LOGGED_IN_POST], ret, id)

        client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "AUTO_LOGGED_SUCCESFULLY");
    }
}

register_user(id)
{
    new szQuery[700], szData[2]; 
    szData[0] = id;
    szData[1] = USER_REGISTERED;
    formatex(szQuery, charsmax(szQuery), "INSERT INTO `%s` (`uname`,`authid`,`last_authid`,`ip`,`last_ip`,`email`,`upassword`) VALUES ('%s','%s','%s','%s','%s','%s','%s')", g_szTables[0],
    g_eUserData[id][szName], g_eUserData[id][szAuthID], g_eUserData[id][szAuthID], g_eUserData[id][szInternetAddress], g_eUserData[id][szInternetAddress], g_eUserData[id][szEmail], g_eUserData[id][szPassword])

    SQL_ThreadQuery(g_SqlTuple, "FreeHandle", szQuery, szData, sizeof(szData));
}

public check_account(id)
{
    new szQuery[512];
    new szData[1]; szData[0] = id;

    formatex(szQuery, charsmax(szQuery), "SELECT * FROM `%s` WHERE `last_ip` = '%s' OR `last_authid` = '%s' OR `ip` = '%s' OR `authid` = '%s'", g_szTables[0],
    g_eUserData[id][szInternetAddress], g_eUserData[id][szAuthID], g_eUserData[id][szInternetAddress], g_eUserData[id][szAuthID]);

    SQL_ThreadQuery(g_SqlTuple, "CheckIfAccountExists", szQuery, szData, sizeof(szData));
}

public CheckIfAccountExists(FailState, Handle:Query, szError[], ErrorCode, szData[], iSize)
{
    if(FailState || ErrorCode)
        log_to_file(LOG_FILE, "SQL ERROR: %s", szError);

    new id = szData[0];

    if(SQL_NumResults(Query) == 1)
    {
        get_user_data(Query, id);
    }

    SQL_FreeHandle(Query);
}
public log_in(id)
{
    new szQuery[512];
    new szData[1];
    szData[0] = id;
    formatex(szQuery, charsmax(szQuery), "SELECT * FROM `%s` WHERE `email` = '%s'", g_szTables[0], g_eUserData[id][szEmail]);

    SQL_ThreadQuery(g_SqlTuple, "LogIn", szQuery, szData, sizeof(szData));
}

public LogIn(FailState, Handle:Query, szError[], ErrorCode, szData[], iSize)
{
    if(FailState || ErrorCode)
        log_to_file(LOG_FILE, "SQL ERROR: %s", szError);

    new id = szData[0];

    if(!is_user_connected(id))
    {
        SQL_FreeHandle(Query);
        return PLUGIN_HANDLED;
    }

    if(SQL_NumResults(Query) == 1)
    {
        new szDBPassword[MAX_PASSWORD_LENGTH];
        SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "upassword"), szDBPassword, charsmax(szDBPassword));

        if(!equal(szDBPassword, g_eUserData[id][szPassword]))
        {
            client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "INVALID_CREDENTIALS", g_eUserData[id][iLoginAttempts]);

            if(g_eUserData[id][iLoginAttempts] == MAX_LOGIN_ATTEMPS)
            {
                new szReason[20];
                formatex(szReason, charsmax(szReason), "%l", "TOO_MANY_LOGIN_ATTEMPTS", MAX_LOGIN_ATTEMPS);
                client_print(id, print_console, "%l", "CONSOLE_MSG_KICK")
                server_cmd("kick #%i ^"%s^"", get_user_userid(id), szReason);
            }
            else 
            {
                g_eUserData[id][iLoginAttempts]++
            }
        }
        else 
        {
            get_user_data(Query, id);
            g_eUserData[id][bLogged] = true;

            client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "LOGGED_IN_SUCCESFULLY");
            vip_menu(id);
        }
    }

    SQL_FreeHandle(Query);

    new ret;
    ExecuteForward(g_eForwards[LOGGED_IN_POST], ret, id);   
        
    return PLUGIN_CONTINUE;
}

get_user_data(const Handle:Query, const id)
{
    g_eUserData[id][bAccountExists] = true;
    g_eUserData[id][iVIPLevel] = SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "vip_level"));
    g_eUserData[id][bAutoLogin] = bool:SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "auto_login"));
    g_eUserData[id][bAutoMenu] = bool:SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "auto_menu"));
    
    server_print("test %i", SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "auto_login")))

    if(!g_eUserData[id][szEmail][0])
    {
        SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "email"), g_eUserData[id][szEmail], charsmax(g_eUserData[][szEmail]))
    }

    if(!g_eUserData[id][szPassword][0])
    {
        SQL_ReadResult(Query, SQL_FieldNameToNum(Query, "upassword"), g_eUserData[id][szPassword], charsmax(g_eUserData[][szPassword]))
    }
}

public weapon_menu(id)
{
    if(!IsValid(id))
       id -= AUTO_MENU_TASK; 

    new szTitle[64], szItem[64], szPistol[64], szExitName[20], szBackName[20];
    formatex(szTitle, charsmax(szTitle), "%s %l", MENU_TITLE_PREFIX, "WEAPON_MENU_MAIN_TITLE")

    new iMenu = menu_create(szTitle, "weapon_menu_handler", 0);

    new szWeaponNum[40], iWeaponNum, iWeaponsNR;

    switch(g_eUserData[id][iVIPLevel])
    {
        case VIP_DIAMOND:
        {
            if(g_eCvar[DIAMOND_PISTOL] != 0)
            {
                formatex(szPistol, charsmax(szPistol), "\w %l\r %s", "WEAPON_MENU_AND_WORD", g_Pistols[g_eCvar[DIAMOND_PISTOL]][WeapName])
            }

            if(g_ePluginData[iCurrRound] >= g_eCvar[PISTOL_ROUNDS])
            {
                for(new i = 0; i < strlen(g_eCvar[DIAMOND_WEAPONS]); i++)
                {
                    if(g_eCvar[DIAMOND_WEAPONS][i] == 'z' || !g_eCvar[DIAMOND_WEAPONS][i])
                        continue;

                    szWeaponNum[i] = g_eCvar[DIAMOND_WEAPONS][i];
                    iWeaponNum = containi(ALPHABET, szWeaponNum[i]);

                    if(iWeaponNum != -1)
                    {
                        num_to_str(iWeaponNum, szWeaponNum, charsmax(szWeaponNum));
                        formatex(szItem, charsmax(szItem), "\r%s%s", g_Weapons[iWeaponNum][WeapName], g_eCvar[DIAMOND_PISTOL] != 0 ? szPistol : "");
                        menu_additem(iMenu, szItem, szWeaponNum);

                        iWeaponsNR++;    
                    }
                }

                if(iWeaponsNR == 0 && g_eCvar[DIAMOND_PISTOL] == 0)
                {
                    formatex(szItem, charsmax(szItem), "%l", "NO_WEAPONS");
                    menu_additem(iMenu, szItem);
                }
                else if(iWeaponsNR == 0 && g_eCvar[DIAMOND_PISTOL] != 0)
                {
                    formatex(szItem, charsmax(szItem), "\r%s", g_Pistols[g_eCvar[DIAMOND_PISTOL]][WeapName])
                    menu_additem(iMenu, szItem);
                }
            }
            else 
            {
                if(iWeaponsNR == 0 && g_eCvar[DIAMOND_PISTOL] == 0)
                {
                    formatex(szItem, charsmax(szItem), "%l", "NO_WEAPONS");
                    menu_additem(iMenu, szItem);
                }
                else if(iWeaponsNR == 0 && g_eCvar[DIAMOND_PISTOL] != 0)
                {
                    formatex(szItem, charsmax(szItem), "\r%s", g_Pistols[g_eCvar[DIAMOND_PISTOL]][WeapName])
                    menu_additem(iMenu, szItem);
                }
            }
        }

        case VIP_GOLD:
        {
            if(g_eCvar[GOLD_PISTOL] != 0)
            {
                formatex(szPistol, charsmax(szPistol), "\w %l\r %s", "WEAPON_MENU_AND_WORD", g_Pistols[g_eCvar[GOLD_PISTOL]][WeapName])
            }

            if(g_ePluginData[iCurrRound] >= g_eCvar[PISTOL_ROUNDS])
            {
                for(new i = 0; i < strlen(g_eCvar[GOLD_WEAPONS]); i++)
                {
                    if(g_eCvar[GOLD_WEAPONS][i] == 'z' || !g_eCvar[GOLD_WEAPONS][i])
                        continue;

                    szWeaponNum[i] = g_eCvar[GOLD_WEAPONS][i];
                    iWeaponNum = containi(ALPHABET, szWeaponNum);

                    if(iWeaponNum != -1)
                    {
                        num_to_str(iWeaponNum, szWeaponNum, charsmax(szWeaponNum));
                        formatex(szItem, charsmax(szItem), "\r%s%s", g_Weapons[iWeaponNum][WeapName], g_eCvar[GOLD_PISTOL] != 0 ? szPistol : "");
                        menu_additem(iMenu, szItem, szWeaponNum);

                        iWeaponsNR++;    
                    }
                }

                if(iWeaponsNR == 0 && g_eCvar[GOLD_PISTOL] == 0)
                {
                    formatex(szItem, charsmax(szItem), "%l", "NO_WEAPONS");
                    menu_additem(iMenu, szItem);
                }
                else
                {
                    formatex(szItem, charsmax(szItem), "\r%s", g_Pistols[g_eCvar[GOLD_PISTOL]][WeapName])
                    menu_additem(iMenu, szItem);
                }
            }
            else 
            {
                if(iWeaponsNR == 0 && g_eCvar[SILVER_PISTOL] == 0)
                {
                    formatex(szItem, charsmax(szItem), "%l", "NO_WEAPONS");
                    menu_additem(iMenu, szItem);
                }
                else if(iWeaponsNR == 0 && g_eCvar[SILVER_PISTOL] != 0)
                {
                    formatex(szItem, charsmax(szItem), "\r%s", g_Pistols[g_eCvar[SILVER_PISTOL]][WeapName])
                    menu_additem(iMenu, szItem);
                }
            }
        }

        case VIP_SILVER:
        {
            if(g_eCvar[SILVER_PISTOL] != 0)
            {
                formatex(szPistol, charsmax(szPistol), "\w %l\r %s", "WEAPON_MENU_AND_WORD", g_Pistols[g_eCvar[SILVER_PISTOL]][WeapName])
            }

            if(g_ePluginData[iCurrRound] >= g_eCvar[PISTOL_ROUNDS])
            {
                for(new i = 0; i < strlen(g_eCvar[SILVER_WEAPONS]); i++) 
                {
                    if(g_eCvar[SILVER_WEAPONS][i] == 'z' || !g_eCvar[SILVER_WEAPONS][i])
                        continue;
                
                    szWeaponNum[0] = g_eCvar[SILVER_WEAPONS][i];
                    iWeaponNum = containi(ALPHABET, szWeaponNum);

                    if(iWeaponNum != -1)
                    {
                        num_to_str(iWeaponNum, szWeaponNum, charsmax(szWeaponNum));
                        formatex(szItem, charsmax(szItem), "\r%s%s", g_Weapons[iWeaponNum][WeapName], g_eCvar[SILVER_PISTOL] != 0 ? szPistol : "");
                        menu_additem(iMenu, szItem, szWeaponNum);

                        iWeaponsNR++;    
                    }
                }

                if(iWeaponsNR == 0 && g_eCvar[SILVER_PISTOL] == 0)
                {
                    formatex(szItem, charsmax(szItem), "%l", "NO_WEAPONS");
                    menu_additem(iMenu, szItem);
                }
                else
                {
                    formatex(szItem, charsmax(szItem), "\r%s", g_Pistols[g_eCvar[SILVER_PISTOL]][WeapName])
                    menu_additem(iMenu, szItem);
                }
            }
            else 
            {
                if(iWeaponsNR == 0 && g_eCvar[SILVER_PISTOL] == 0)
                {
                    formatex(szItem, charsmax(szItem), "%l", "NO_WEAPONS");
                    menu_additem(iMenu, szItem);
                }
                else if(iWeaponsNR == 0 && g_eCvar[SILVER_PISTOL] != 0)
                {
                    formatex(szItem, charsmax(szItem), "\r%s", g_Pistols[g_eCvar[SILVER_PISTOL]][WeapName])
                    menu_additem(iMenu, szItem);
                }
            }
        }
    }

    formatex(szExitName, charsmax(szExitName), "%l", "MENU_GO_PREVIOUS_MENU");
    formatex(szBackName, charsmax(szBackName), "%l", "MENU_BACK_NAME");

    menu_setprop(iMenu, MPROP_EXITNAME, szExitName);
    menu_setprop(iMenu, MPROP_BACKNAME, szBackName);
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);

    if(is_user_connected(id))
        menu_display(id, iMenu, 0, -1)
}

public weapon_menu_handler(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        menu_destroy(menu);
        vip_menu(id);
        return PLUGIN_HANDLED;
    }

    new bool:bHasC4 = bool:user_has_weapon(id, CSW_C4);

    strip_user_weapons(id);
    give_item(id, "weapon_knife");

    if(bHasC4)
    {
        give_item(id, "weapon_c4");
    }
    
    new szData[5];
    menu_item_getinfo(menu, item, _, szData, charsmax(szData), _, _);
    menu_destroy(menu);
    new iWeaponNum = str_to_num(szData);

    switch(g_eUserData[id][iVIPLevel])
    {
        case VIP_DIAMOND: 
        {
            give_item(id, g_Weapons[iWeaponNum][WeaponID])
            cs_set_user_bpammo(id, get_weaponid(g_Weapons[iWeaponNum][WeaponID]), g_Weapons[iWeaponNum][BpAmmo]);

            if(g_eCvar[DIAMOND_PISTOL] != 0)
            {
                give_item(id, g_Pistols[g_eCvar[DIAMOND_PISTOL]][WeaponID]);
                cs_set_user_bpammo(id, get_weaponid(g_Pistols[g_eCvar[DIAMOND_PISTOL]][WeaponID]), g_Pistols[g_eCvar[DIAMOND_PISTOL]][BpAmmo]);
            }

            if(g_eCvar[DIAMOND_HEGRENADE] != 0)
            {
                give_item(id, "weapon_hegrenade");
                cs_set_user_bpammo(id, CSW_HEGRENADE, g_eCvar[DIAMOND_HEGRENADE])
            }

            if(g_eCvar[DIAMOND_SMOKEGRENADE] != 0)
            {
                give_item(id, "weapon_smokegrenade");
                cs_set_user_bpammo(id, CSW_SMOKEGRENADE, g_eCvar[DIAMOND_SMOKEGRENADE])
            }

            if(g_eCvar[DIAMOND_FLASHBANG] != 0)
            {
                give_item(id, "weapon_flashbang");
                cs_set_user_bpammo(id, CSW_FLASHBANG, g_eCvar[DIAMOND_FLASHBANG])
            }
        }

        case VIP_GOLD: 
        {
            give_item(id, g_Weapons[iWeaponNum][WeaponID])
            cs_set_user_bpammo(id, get_weaponid(g_Weapons[iWeaponNum][WeaponID]), g_Weapons[iWeaponNum][BpAmmo]);

            if(g_eCvar[GOLD_PISTOL] != 0)
            {
                give_item(id, g_Pistols[g_eCvar[GOLD_PISTOL]][WeaponID]);
                cs_set_user_bpammo(id, get_weaponid(g_Pistols[g_eCvar[GOLD_PISTOL]][WeaponID]), g_Pistols[g_eCvar[GOLD_PISTOL]][BpAmmo]);
            }

            if(g_eCvar[GOLD_HEGRENADE] != 0)
            {
                give_item(id, "weapon_hegrenade");
                cs_set_user_bpammo(id, CSW_HEGRENADE, g_eCvar[GOLD_HEGRENADE])
            }

            if(g_eCvar[GOLD_SMOKEGRENADE] != 0)
            {
                give_item(id, "weapon_smokegrenade");
                cs_set_user_bpammo(id, CSW_SMOKEGRENADE, g_eCvar[GOLD_SMOKEGRENADE])
            }

            if(g_eCvar[GOLD_FLASHBANG] != 0)
            {
                give_item(id, "weapon_flashbang");
                cs_set_user_bpammo(id, CSW_FLASHBANG, g_eCvar[GOLD_FLASHBANG])
            }
        }

        case VIP_SILVER: 
        {
            give_item(id, g_Weapons[iWeaponNum][WeaponID])
            cs_set_user_bpammo(id, get_weaponid(g_Weapons[iWeaponNum][WeaponID]), g_Weapons[iWeaponNum][BpAmmo]);

            if(g_eCvar[SILVER_PISTOL] != 0)
            {
                give_item(id, g_Pistols[g_eCvar[SILVER_PISTOL]][WeaponID]);
                cs_set_user_bpammo(id, get_weaponid(g_Pistols[g_eCvar[SILVER_PISTOL]][WeaponID]), g_Pistols[g_eCvar[SILVER_PISTOL]][BpAmmo]);
            }

            if(g_eCvar[SILVER_HEGRENADE] > 0)
            {
                give_item(id, "weapon_hegrenade");
                cs_set_user_bpammo(id, CSW_HEGRENADE, g_eCvar[SILVER_HEGRENADE])
            }

            if(g_eCvar[SILVER_SMOKEGRENADE] > 0)
            {
                give_item(id, "weapon_smokegrenade");
                cs_set_user_bpammo(id, CSW_SMOKEGRENADE, g_eCvar[SILVER_SMOKEGRENADE])
            }

            if(g_eCvar[SILVER_FLASHBANG] > 0)
            {
                give_item(id, "weapon_flashbang");
                cs_set_user_bpammo(id, CSW_FLASHBANG, g_eCvar[SILVER_FLASHBANG])
            }
        }
    }

    return PLUGIN_CONTINUE;
}

public fwHamPlayerSpawnPost(id)
{
    if(is_user_alive(id) && pp_is_user_logged(id))
    {
        new CsTeams:iTeam = cs_get_user_team(id);

        if(g_eUserData[id][bAutoMenu])
            set_task(0.1, "weapon_menu", id + AUTO_MENU_TASK);

        switch(g_eUserData[id][iVIPLevel])
        {
            case VIP_DIAMOND:
            {
                if(g_eCvar[DIAMOND_THIGHPACK] != 0 && iTeam == CS_TEAM_CT)
                {
                   give_item(id, "item_thighpack");
                }

                set_user_health(id, g_eCvar[DIAMOND_HEALTH]);
                set_user_armor(id, g_eCvar[DIAMOND_ARMOR]);
            }

            case VIP_GOLD:
            {
                if(g_eCvar[GOLD_THIGHPACK] != 0 && iTeam == CS_TEAM_CT)
                {
                    give_item(id, "item_thighpack");
                }

                set_user_health(id, g_eCvar[GOLD_HEALTH]);
                set_user_armor(id, g_eCvar[GOLD_ARMOR]);
            }

            case VIP_SILVER:
            {
                if(g_eCvar[SILVER_THIGHPACK] != 0 && iTeam == CS_TEAM_CT)
                {
                    give_item(id, "item_thighpack");
                }

                set_user_health(id, g_eCvar[SILVER_HEALTH]);
                set_user_armor(id, g_eCvar[SILVER_ARMOR]);
            }
        }
    }
}

public concmd_email(id)
{
    server_print("test")
    new szArg[64];
    read_args(szArg, charsmax(szArg));
    remove_quotes(szArg);
    trim(szArg);

    new iLen = strlen(szArg);

    if((containi(szArg, "@") == -1) || equal(szArg[iLen - 1], "@") || (containi(szArg, " ") != -1) || (containi(szArg, "\") != -1))
    {
        client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "INVALID_EMAIL");
        vip_menu(id);
        return PLUGIN_HANDLED;
    }

    copy(g_eUserData[id][szEmail], charsmax(g_eUserData[][szEmail]), szArg);

    switch(g_eUserData[id][iCurrentMenu])
    {
        case LOGIN:
        {
            login_menu(id);
        }

        case REGISTER:
        {
            reg_menu(id);
        }   
    }

    return PLUGIN_HANDLED;
}

public concmd_password(id)
{
    new szArg[64];
    read_args(szArg, charsmax(szArg));
    remove_quotes(szArg);
    trim(szArg);

    if(containi(szArg, " ") != -1 || !szArg[0])
    {
        client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "INVALID_PASSWORD");
        vip_menu(id);
        return PLUGIN_HANDLED;
    }

    copy(g_eUserData[id][szPassword], charsmax(g_eUserData[][szPassword]), szArg);

    switch(g_eUserData[id][iCurrentMenu])
    {
        case LOGIN:
        {
            login_menu(id);
        }

        case REGISTER:
        {
            reg_menu(id);
        }   
    }

    return PLUGIN_HANDLED;
}

public plugin_cfg()
{
    new szConfig[64], szFile[256], iFile;
    get_configsdir(szConfig, charsmax(szConfig));

    format(szConfig, charsmax(szConfig), "%s/%s", szConfig, FOLDER_NAME)

    if(!dir_exists(szConfig))
    {
        if(mkdir(szConfig, FPERM_DIR_DEFAULT) == 0)
        {
            log_to_file(LOG_FILE, "Folderul ^"%s^" a fost creat cu succes", FOLDER_NAME)
        }
        else 
        {
            set_fail_state("Folderul ^"%s^" nu a putut fi creat!", FOLDER_NAME)
        }
    }

    formatex(szFile, charsmax(szFile), "%s/%s", szConfig, CONFIG_FILE);

    if(file_exists(szFile))
    {
        server_cmd("exec %s", szFile);
        server_exec();

        server_print("%s Configul a fost executat cu succes", PLUGIN_PREFIX)
        check_map(szConfig);
        check_cvars();
    }
    else 
    {
        iFile = fopen(szFile, "w");

        if(!iFile)
        {
            set_fail_state ("Configul nu a putut fi creat (^"%s^")", CONFIG_FILE);
        }

        for(new i; i < sizeof(g_szFileData); i++)
        {
            fputs(iFile, g_szFileData[i]);
        }

        log_to_file(LOG_FILE, "Configul a fost creat cu succes (^"%s^")", CONFIG_FILE);

        fclose(iFile);
        plugin_cfg();
    }
}

set_settings()
{
    new data;
    //////////////////////////////////////////////
    /////////////////SQL SETTINGS/////////////////
    //////////////////////////////////////////////

    data = register_cvar("paypal_sql_host", "host", FCVAR_SPONLY);
    get_pcvar_string(data, g_eSQL[MYSQL_HOST], charsmax(g_eSQL[MYSQL_HOST]));

    data = register_cvar("paypal_sql_user", "username", FCVAR_SPONLY);
    get_pcvar_string(data, g_eSQL[MYSQL_USER], charsmax(g_eSQL[MYSQL_USER]));

    data = register_cvar("paypal_sql_pass", "password", FCVAR_SPONLY);
    get_pcvar_string(data, g_eSQL[MYSQL_PASS], charsmax(g_eSQL[MYSQL_PASS]));

    data = register_cvar("paypal_sql_db", "database", FCVAR_SPONLY);
    get_pcvar_string(data, g_eSQL[MYSQL_DB], charsmax(g_eSQL[MYSQL_DB]));


    data = register_cvar("enable_register", "1", FCVAR_SPONLY);
    g_eCvar[REGISTER_STATE] = bool:get_pcvar_num(data);

    data = register_cvar("pistol_rounds", "2");
    g_eCvar[PISTOL_ROUNDS] = get_pcvar_num(data);


    //////////////////////////////////////////////
    /////////////////WEAPON MENU//////////////////
    //////////////////////////////////////////////

    ///////////
    //DIAMOND//
    ///////////

    data = register_cvar("diamond_weapon", "abc");
    get_pcvar_string(data, g_eCvar[DIAMOND_WEAPONS], charsmax(g_eCvar[DIAMOND_WEAPONS]));

    data = register_cvar("diamond_pistol", "1");
    g_eCvar[DIAMOND_PISTOL] = get_pcvar_num(data);

    data = register_cvar("diamond_hegrenade", "1");
    g_eCvar[DIAMOND_HEGRENADE] = get_pcvar_num(data);

    data = register_cvar("diamond_smokegrenade", "1");
    g_eCvar[DIAMOND_SMOKEGRENADE] = get_pcvar_num(data);

    data = register_cvar("diamond_flash", "2");
    g_eCvar[DIAMOND_FLASHBANG] = get_pcvar_num(data);

    data = register_cvar("diamond_defusekit", "1");
    g_eCvar[DIAMOND_THIGHPACK] = get_pcvar_num(data);

    data = register_cvar("diamond_health", "100");
    g_eCvar[DIAMOND_HEALTH] = get_pcvar_num(data);

    data = register_cvar("diamond_armor", "100");
    g_eCvar[DIAMOND_ARMOR] = get_pcvar_num(data);

    ////////
    //GOLD//
    ////////

    data = register_cvar("gold_weapon", "abc");
    get_pcvar_string(data, g_eCvar[GOLD_WEAPONS], charsmax(g_eCvar[GOLD_WEAPONS]));

    data = register_cvar("gold_pistol", "1");
    g_eCvar[GOLD_PISTOL] = get_pcvar_num(data);

    data = register_cvar("gold_hegrenade", "1");
    g_eCvar[GOLD_HEGRENADE] = get_pcvar_num(data);

    data = register_cvar("gold_smokegrenade", "1");
    g_eCvar[GOLD_SMOKEGRENADE] = get_pcvar_num(data);

    data = register_cvar("gold_flash", "2");
    g_eCvar[GOLD_FLASHBANG] = get_pcvar_num(data);

    data = register_cvar("gold_defusekit", "0");
    g_eCvar[GOLD_THIGHPACK] = get_pcvar_num(data);

    data = register_cvar("gold_health", "100");
    g_eCvar[GOLD_HEALTH] = get_pcvar_num(data);

    data = register_cvar("gold_armor", "100");
    g_eCvar[GOLD_ARMOR] = get_pcvar_num(data);
    
    //////////
    //SILVER//
    //////////
    
    data = register_cvar("silver_weapon", "abc");
    get_pcvar_string(data, g_eCvar[SILVER_WEAPONS], charsmax(g_eCvar[SILVER_WEAPONS]));

    data = register_cvar("silver_pistol", "1");
    g_eCvar[SILVER_PISTOL] = get_pcvar_num(data);

    data = register_cvar("silver_hegrenade", "1");
    g_eCvar[SILVER_HEGRENADE] = get_pcvar_num(data);

    data = register_cvar("silver_smokegrenade", "1");
    g_eCvar[SILVER_SMOKEGRENADE] = get_pcvar_num(data);

    data = register_cvar("silver_flash", "2");
    g_eCvar[SILVER_FLASHBANG] = get_pcvar_num(data);

    data = register_cvar("silver_defusekit", "0");
    g_eCvar[SILVER_THIGHPACK] = get_pcvar_num(data);

    data = register_cvar("silver_health", "100");
    g_eCvar[SILVER_HEALTH] = get_pcvar_num(data);

    data = register_cvar("silver_armor", "100");
    g_eCvar[SILVER_ARMOR] = get_pcvar_num(data);
}

check_cvars()
{
    if(equal(g_eSQL[MYSQL_HOST], "host") || equal(g_eSQL[MYSQL_USER], "username") || equal(g_eSQL[MYSQL_PASS], "password") || equal(g_eSQL[MYSQL_DB], "database"))
    {
        set_fail_state("You must complete SQL Database informations from config file (^"%s^")", CONFIG_FILE)
    }

    MySql_Init();

    new szWeaponFlag[40];

    for(new i = 0; i < strlen(g_eCvar[DIAMOND_WEAPONS]); i++)
    {
        szWeaponFlag[i] = g_eCvar[DIAMOND_WEAPONS][i]

        if(containi(ALPHABET, szWeaponFlag[i]) == -1)
        {
            log_to_file(LOG_FILE, "Error! Invalid flag for diamond weapons ^"%s^" at position %i", szWeaponFlag[i], i);
        }
    }

    arrayset(szWeaponFlag, 0, charsmax(szWeaponFlag));

    for(new i = 0; i < strlen(g_eCvar[GOLD_WEAPONS]); i++)
    {
        szWeaponFlag[i] = g_eCvar[GOLD_WEAPONS][i]; 

        if(containi(ALPHABET, szWeaponFlag[i]) == -1)
        {
            log_to_file(LOG_FILE, "Error! Invalid flag for gold weapons ^"%s^" at position %i", szWeaponFlag[i], i);
        }
    }

    arrayset(szWeaponFlag, 0, charsmax(szWeaponFlag));

    for(new i = 0; i < strlen(g_eCvar[SILVER_WEAPONS]); i++)
    {    
        szWeaponFlag[i] = g_eCvar[SILVER_WEAPONS][i]; 

        if(containi(ALPHABET, szWeaponFlag[i]) == -1)
        {
            log_to_file(LOG_FILE, "Error! Invalid flag for silver weapons ^"%s^" at position %i", szWeaponFlag[i], i);
        }
    }

    if(g_eCvar[DIAMOND_PISTOL] < 0 || g_eCvar[DIAMOND_PISTOL] > 6)
    {
        g_eCvar[DIAMOND_PISTOL] = 0;
        log_to_file(LOG_FILE, "Error! Cvar diamond_pistol can't be lower than 0 and higher than 6! It has been reseted to 0");
    }

    if(g_eCvar[GOLD_PISTOL] < 0 || g_eCvar[GOLD_PISTOL] > 6)
    {
        g_eCvar[GOLD_PISTOL] = 0;
        log_to_file(LOG_FILE, "Error! Cvar gold_pistol can't be lower than 0 and higher than 6! It has been reseted to 0");
    }

    if(g_eCvar[SILVER_PISTOL] < 0 || g_eCvar[SILVER_PISTOL] > 6)
    {
        g_eCvar[SILVER_PISTOL] = 0;
        log_to_file(LOG_FILE, "Error! Cvar silver_pistol can't be lower than 0 and higher than 6! It has been reseted to 0");
    }
}

check_map(const cfgdir[])
{
    new szFile[128], iFile;
    formatex(szFile, charsmax(szFile), "%s/%s", cfgdir, RESTRICTED_MAPS_FILE);

    if(!file_exists(szFile))
    {
        iFile = fopen(szFile, "w");

        if(!iFile)
        {
            set_fail_state("Fisierul cu hartile blocate nu a putut fi creat (^"%s^")", RESTRICTED_MAPS_FILE)
        }

        for(new i; i < sizeof(g_szBlockedMapsData); i++)
        {
            fputs(iFile, g_szBlockedMapsData[i]);
        }

        log_to_file(LOG_FILE, "Fisierul cu mape restrictionate ^"%s^" a fost creat cu succes", RESTRICTED_MAPS_FILE);

        fclose(iFile);	
    }
    else 
    {
        iFile = fopen(szFile, "r");

        new szData[64], szMapName[64];
        get_mapname(szMapName, charsmax(szMapName));
        
        while(fgets(iFile, szData, charsmax(szData)))
        {
            trim(szData);

            if(szData[0] == '#' || szData[0] == ';' || szData[0] == EOS)
                continue;

            if(equal(szData, szMapName))
            {
                g_bRestrictedMap = true;
                break;
            }
        }

        fclose(iFile);
    }
}

public MySql_Init()
{
    g_SqlTuple = SQL_MakeDbTuple(g_eSQL[MYSQL_HOST], g_eSQL[MYSQL_USER], g_eSQL[MYSQL_PASS], g_eSQL[MYSQL_DB]);
    
    new ErrorCode, Handle:SqlConnection = SQL_Connect(g_SqlTuple,ErrorCode,g_Error,charsmax(g_Error));
    
    if(SqlConnection == Empty_Handle)
    {
        set_fail_state("O eroare a fost intampinata la conectarea la baza de date^n------^n%s^n------", g_Error);
    }
    
    new Handle:Queries;
    new szCache[1500];
    
    for(new i; i < sizeof(g_szTables); i++)
    {
        formatex(szCache, charsmax(szCache), "CREATE TABLE IF NOT EXISTS %s %s", g_szTables[i], g_szTablesInfo[i]);	

        Queries = SQL_PrepareQuery(SqlConnection, szCache);

        if(!SQL_Execute(Queries))
        {
            SQL_QueryError(Queries,g_Error,charsmax(g_Error));
            set_fail_state(g_Error);
        }		
    }
    
    SQL_FreeHandle(Queries);
    SQL_FreeHandle(SqlConnection);
}

public FreeHandle(FailState, Handle:Query, szError[], ErrorCode, szData[], iSize)
{
    if(FailState || ErrorCode)
    {
        log_to_file(LOG_FILE, "SQL ERROR: %s", szError);
    }
    
    if(iSize == 2)
    {
        new id = szData[0];
     
        if(FailState || ErrorCode)
        {
            client_print_color(id, print_team_default, "%s An error has been^3 encountered^1! Contact administration.", CHAT_PREFIX)
            SQL_FreeHandle(Query);
            return PLUGIN_HANDLED;
        }

        new iInfo = szData[1]
        server_print("freehandle %i", iInfo);
        switch(iInfo)
        {
            case USER_REGISTERED:
            {
                client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "REGISTERED_SUCCESFULLY");
                g_eUserData[id][bAccountExists] = true;
            }

            case USER_LOGGED_IN:
            {
                client_print_color(id, print_team_default, "%s %l", CHAT_PREFIX, "LOGGED_IN_SUCCESFULLY");
                g_eUserData[id][bLogged] = true;

                new ret;
                ExecuteForward(g_eForwards[LOGGED_IN_POST], ret, id);
            }

        }
    }

    SQL_FreeHandle(Query);

    return PLUGIN_CONTINUE;
}

public _paypal_main_menu(iPluginID, iParams)
{
    new id = get_param(1);

    vip_menu(id);

    return 1;
}

public _get_user_vip_level(iPluginID, iParams)
{
    new id = get_param(1);

    if(!IsValid(id))
    {
        log_to_file(LOG_FILE, "%s Invalid player id %i", PLUGIN_PREFIX, id);
        return -1;
    }

    if(!is_user_connected(id))
    {
        log_to_file(LOG_FILE, "%s Player %i is not connected", PLUGIN_PREFIX, id);
        return -1;
    }

    return g_eUserData[id][iVIPLevel];
}

public _set_user_vip_level(iPluginID, iParams)
{
    new id = get_param(1);
    new iNVIPLevel = get_param(2);

    if(!IsValid(id))
    {
        log_to_file(LOG_FILE, "%s Invalid player id %i", PLUGIN_PREFIX, id);
        return -1;
    }

    if(!is_user_connected(id))
    {
        log_to_file(LOG_FILE, "%s Player %i is not connected", PLUGIN_PREFIX, id);
        return -1;
    }

    if(iNVIPLevel <= -1 || iNVIPLevel >= 4)
    {
        log_to_file(LOG_FILE, "%s Invalid level VIP (MIN: 0; MAX: 3)", PLUGIN_PREFIX);
        log_to_file(LOG_FILE, "%s Invalid level VIP (0 - NO VIP; 1 - SILVER; 2 - GOLD; 3 - DIAMOND)", PLUGIN_PREFIX);
        return -1;
    }

    g_eUserData[id][iVIPLevel] = iNVIPLevel

    return 1;
}

public _is_user_logged_in(iPluginID, iParams)
{
    new id = get_param(1);

    if(!IsValid(id))
    {
        log_to_file(LOG_FILE, "%s Invalid player id %i", PLUGIN_PREFIX, id);
        return -1;
    }

    if(!is_user_connected(id))
    {
        log_to_file(LOG_FILE, "%s Player %i is not connected", PLUGIN_PREFIX, id);
        return -1;
    }

    return g_eUserData[id][bLogged] == true ? 1 : 0;
}

public _paypal_register_menu(iPluginID, iParams)
{
    new eMenuData[MENUAPI];

    get_string(1, eMenuData[TITLE], charsmax(eMenuData[TITLE]));

    ArrayPushArray(g_aMainMenu, eMenuData);

    g_iMenuItems++;

    return g_iMenuItems-1;
}

stock bool:pp_is_user_logged(id)
{
    return g_eUserData[id][bLogged];
}

stock reset_strings(id)
{
    arrayset(g_eUserData[id][szEmail], 0, charsmax(g_eUserData[][szEmail]));
    arrayset(g_eUserData[id][szPassword], 0, charsmax(g_eUserData[][szPassword]));
}