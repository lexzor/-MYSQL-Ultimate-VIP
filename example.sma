#include <amxmodx>
#include <paypal_vip>

new g_iMenuID;

public plugin_init()
{
    g_iMenuID = paypal_register_menu("\rPrimul\y Meniu")
}

public paypal_menu_selected(id, itemid)
{
    if(g_iMenuID == itemid)
    {
        open_menu(id);
    }
}

open_menu(id)
{
    new iMenu = menu_create("\r[PAYPAL VIP]\y Titlul meniului", "menu_handler");

    for(new i; i < 15; i++)
    {
        menu_additem(iMenu, fmt("Menu item %i", i));
    }

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_display(id, iMenu, 0, -1);
}

public menu_handler(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        return PLUGIN_HANDLED;    
    }

    client_print(id, print_chat, "Ai selectat itemul %i", item);
    open_menu(id);
    return PLUGIN_CONTINUE;
}
