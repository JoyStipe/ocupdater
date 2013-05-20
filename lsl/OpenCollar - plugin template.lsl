// Template for creating a OpenCollar Plugin
// API Version: 3.8

// Licensed under the GPLv2, with the additional requirement that these scripts
// remain "full perms" in Second Life.  See "OpenCollar License" for details.

// Please agressively remove any unneeded code sections to save memory and sim time


string  SUBMENU_BUTTON              = "Plugin"; // Name of the submenu
string  COLLAR_PARENT_MENU          = "AddOns"; // name of the menu, where the menu plugs in, should be usually Addons. Please do not use the mainmenu anymore
string  PLUGIN_CHAT_COMMAND         = "plugin"; // every menu should have a chat command, so the user can easily access it by type for instance *plugin
integer IN_DEBUG_MODE               = FALSE;    // set to TRUE to enable Debug messages

key     g_kMenuID;                              // menu handler
key     g_kWearer;                              // key of the current wearer to reset only on owner changes

 // any local, not changing buttons which will be used in this plugin, leave empty or add buttons as you like:
list    PLUGIN_BUTTONS              = ["Command 1", "Command 2", "AuthCommand"];

list    g_lButtons;

// OpenCollar MESSAGE MAP

// messages for authenticating users
// integer COMMAND_NOAUTH = 0; // for reference, but should usually not be in use inside plugins
integer COMMAND_OWNER              = 500;
integer COMMAND_SECOWNER           = 501;
integer COMMAND_GROUP              = 502;
integer COMMAND_WEARER             = 503;
integer COMMAND_EVERYONE           = 504;
integer COMMAND_RLV_RELAY          = 507;
integer COMMAND_SAFEWORD           = 510;
integer COMMAND_RELAY_SAFEWORD     = 511;
integer COMMAND_BLACKLIST          = 520;
// added for timer so when the sub is locked out they can use postions
integer COMMAND_WEARERLOCKEDOUT    = 521;

integer ATTACHMENT_REQUEST         = 600;
integer ATTACHMENT_RESPONSE        = 601;
integer ATTACHMENT_FORWARD         = 610;

integer WEARERLOCKOUT              = 620; // turns on and off wearer lockout

// integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.
// This is to reduce even the tiny bit of lag caused by having IM slave scripts
integer POPUP_HELP                 = 1001;

// messages for storing and retrieving values from settings store
integer LM_SETTING_SAVE            = 2000; // scripts send messages on this channel to have settings saved to settings store
//                                            str must be in form of "token=value"
integer LM_SETTING_REQUEST         = 2001; // when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE        = 2002; // the settings script will send responses on this channel
integer LM_SETTING_DELETE          = 2003; // delete token from settings store
integer LM_SETTING_EMPTY           = 2004; // sent by settings script when a token has no value in the settings store
integer LM_SETTING_REQUEST_NOCACHE = 2005;

// messages for creating OC menu structure
integer MENUNAME_REQUEST           = 3000;
integer MENUNAME_RESPONSE          = 3001;
integer MENUNAME_REMOVE            = 3003;

// messages for RLV commands
integer RLV_CMD                    = 6000;
integer RLV_REFRESH                = 6001; // RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR                  = 6002; // RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION                = 6003; // RLV Plugins can recieve the used rl viewer version upon receiving this message..
integer RLV_OFF                    = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON                     = 6101; // send to inform plugins that RLV is enabled now, no message or key needed

// messages for poses and couple anims
integer ANIM_START                 = 7000; // send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP                  = 7001; // send this with the name of an anim in the string part of the message to stop the anim
integer CPLANIM_PERMREQUEST        = 7002; // id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE       = 7003; // str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START              = 7004; // str should be valid anim name.  id should be av
integer CPLANIM_STOP               = 7005; // str should be valid anim name.  id should be av

// messages to the dialog helper
integer DIALOG                     = -9000;
integer DIALOG_RESPONSE            = -9001;
integer DIALOG_TIMEOUT             = -9002;

integer TIMER_EVENT                = -10000; // str = "start" or "end". For start, either "online" or "realtime".

integer UPDATE                     = 10001;  // for child prim scripts (currently none in 3.8, thanks to LSL new functions)

// For other things that want to manage showing/hiding keys.
integer KEY_VISIBLE                = -10100;
integer KEY_INVISIBLE              = -10100;

integer COMMAND_PARTICLE           = 20000;
integer COMMAND_LEASH_SENSOR       = 20001;

//chain systems
integer LOCKMEISTER                = -8888;
integer LOCKGUARD                  = -9119;

//rlv relay chan
integer RLV_RELAY_CHANNEL          = -1812221819;

// menu option to go one step back in menustructure
string  UPMENU                     = "^"; // when your menu hears this, give the parent menu



//===============================================================================
//= parameters   :    string    sMsg    message string received
//=
//= return        :    none
//=
//= description  :    output debug messages
//=
//===============================================================================


Debug(string sMsg) {
    if (!IN_DEBUG_MODE) {
        return;
    }
    llOwnerSay(llGetScriptName() + " [DEBUG]: " + sMsg);
}

//===============================================================================
//= parameters   :    key       kID                key of the avatar/remote object that receives the message
//=                   string    sMsg               message to send
//=                   integer   iAlsoNotifyWearer  if TRUE, a copy of the message is sent to the wearer
//=
//= return        :    none
//=
//= description  :    notify targeted id and maybe the wearer
//=
//===============================================================================

integer GetOwnerChannel(key kOwner, integer iOffset)
{
    integer iChan = (integer)("0x"+llGetSubString((string)kOwner,2,7)) + iOffset;
    if (iChan>0)
    {
        iChan=iChan*(-1);
    }
    if (iChan > -10000)
    {
        iChan -= 30000;
    }
    return iChan;
}
Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    if (kID == g_kWearer)
    {
        llOwnerSay(sMsg);
    }
    else if (llGetAgentSize(kID) != ZERO_VECTOR)
    {
        llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer)
        {
            llOwnerSay(sMsg);
        }
    }
    else // remote request
    {
        llRegionSayTo(kID, GetOwnerChannel(g_kWearer, 1111), sMsg);
    }
}

//===============================================================================
//= parameters   :    key   kRCPT  recipient of the dialog
//=                   string  sPrompt    dialog prompt
//=                   list  lChoices    true dialog buttons
//=                   list  lUtilityButtons  utility buttons (kept on every iPage)
//=                   integer   iPage    Page to be display
//=
//= return        :    key  handler of the dialog
//=
//= description  :    displays a dialog to the given recipient
//=
//===============================================================================

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|"
    + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kID);
    return kID;
}

//===============================================================================
//= parameters   :    string    keyID   key of person requesting the menu
//=
//= return        :    none
//=
//= description  :    build menu and display to user
//=
//===============================================================================

DoMenu(key keyID, integer iAuth) {
    string sPrompt = "Pick an option.\n";
    list lMyButtons = PLUGIN_BUTTONS + g_lButtons;

    //fill in your button list and additional prompt here
    lMyButtons = llListSort(lMyButtons, 1, TRUE); // resort menu buttons alphabetical

    // and dispay the menu
    g_kMenuID = Dialog(keyID, sPrompt, lMyButtons, [UPMENU], 0, iAuth);
}


//===============================================================================
//= parameters   :    none
//=
//= return        :   string prefix to be used for this script's settings
//=
//= description  :   portion of the name of the script following "OpenCollar - "
//=
//===============================================================================

string GetScriptID()
{
    // strip away "OpenCollar - " leaving the script's individual name
    list parts = llParseString2List(llGetScriptName(), ["-"], []);
    return llStringTrim(llList2String(parts, 1), STRING_TRIM) + "_";
}
//===============================================================================
//= parameters   :    in: 2-part string separated by an undescore (_)
//=					slot: position of string to return, 0=left; 1=right
//=
//= return        :   requested sub-string
//=
//= description  :   Settings tokens are in form: ScriptID_Token
//=
//===============================================================================
string PeelToken(string in, integer slot)
{
    integer i = llSubStringIndex(in, "_");
    if (!slot) return llGetSubString(in, 0, i);
    return llGetSubString(in, i + 1, -1);
}

//===============================================================================
//= parameters   :    iNum: integer parameter of link message (avatar auth level)
//=                   sStr: string parameter of link message (command name)
//=                   kID: key parameter of link message (user key, usually)
//=
//= return        :   TRUE if the command was handled, FALSE otherwise
//=
//= description  :    handles user chat commands (also used as backend for menus)
//=
//===============================================================================

integer UserCommand(integer iNum, string sStr, key kID) {
    if (!(iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)) {
        return FALSE;
    }
    // a validated command from a owner, secowner, groupmember or the wearer has been received
    // can also be used to listen to chat commands
    list lParams = llParseString2List(sStr, [" "], []);
    string sCommand = llToLower(llList2String(lParams, 0));
    string sValue = llToLower(llList2String(lParams, 1));
        // So commands can accept a value
    if (sStr == "reset") {
        // it is a request for a reset
        if (iNum == COMMAND_WEARER || iNum == COMMAND_OWNER) {
            //only owner and wearer may reset
            llResetScript();
        }
    }
    else if (sStr == PLUGIN_CHAT_COMMAND || sStr == "menu " + SUBMENU_BUTTON) {
        // an authorized user requested the plugin menu by typing the menus chat command
        DoMenu(kID, iNum);
    }
    else if (sStr == "yourcommandhere") {
        // example for a command which can be invoked by chat and/or menu, replace yourcommandhere by what you need
        Debug("Do some fancy stuff to impress the user");

        // maybe save a value to the setting store:
        llMessageLinked(LINK_THIS, LM_SETTING_SAVE, GetScriptID() + "token=value", NULL_KEY);

        // or delete a toke from the setting store:
        llMessageLinked(LINK_THIS, LM_SETTING_DELETE, GetScriptID() + "token", NULL_KEY);
    }
    return TRUE;
}



default {

    state_entry() {
        // store key of wearer
        g_kWearer = llGetOwner();
        // sleep a second to allow all scripts to be initialized
        llSleep(1);
        // send request to main menu and ask other menus if they want to register with us
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, SUBMENU_BUTTON, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, COLLAR_PARENT_MENU + "|" + SUBMENU_BUTTON, NULL_KEY);
    }

    // Reset the script if wearer changes. By only reseting on owner change we can keep most of our
    // configuration in the script itself as global variables, so that we don't loose anything in case
    // the settings store isn't available, and also keep settings that were not sent to that store
    // in the first place.
    // Cleo: As per Nan this should be a reset on every rez, this has to be handled as needed, but be prepared that the user can reset your script anytime using the OC menus
    on_rez(integer iParam) {
        if (llGetOwner()!=g_kWearer) {
            // Reset if wearer changed
            llResetScript();
        }
    }

    // listen for linked messages from OC scripts
    link_message(integer iSender, integer iNum, string sStr, key kID) {
        if (iNum == MENUNAME_REQUEST && sStr == COLLAR_PARENT_MENU) {
            // our parent menu requested to receive buttons, so send ours
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, COLLAR_PARENT_MENU + "|" + SUBMENU_BUTTON, NULL_KEY);
        }
        else if (iNum == MENUNAME_RESPONSE) {
            // a button is send to be added to a menu
            list lParts = llParseString2List(sStr, ["|"], []);
            if (llList2String(lParts, 0) == SUBMENU_BUTTON) {
                // someone wants to stick something in our menu
                string button = llList2String(lParts, 1);
                if (llListFindList(g_lButtons, [button]) == -1) {
                    // if the button isnt in our menu yet, than we add it
                    g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
                }
            }
        }
        else if (iNum == LM_SETTING_RESPONSE)
        {
            // response from setting store have been received
            // pares the answer
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            // and check if any values for use are received
            // replace "value1" by your own token
            if (PeelToken(sToken, 0) == GetScriptID()) // this setting is meant for this script
            {
            	sToken = PeelToken(sToken, 1); // discard the scriptID from the string
            	if (sToken == "value1" )
            	{
    	            // work with the received values
        	    }
            	// replace "value2" by your own token, but if possible try to store everything in one token
            	// to reduce the load on the setting store (especially if it is implemented as a webservice... )
	            else if (sToken == "value2")
	            {
    	            // work with the received values
        	    }
			}
            // or check for specific values from the collar like "auth_owner" (for owners) "auth_secowner" (for secondary owners) etc
 	        else if (sToken == "auth_owner")
 	        {
    	        // work with the received values, in this case pare the vlaue into a strided list with the owners
        	    list lOwners = llParseString2List(sValue, [","], []);
            }
        }
        else if (UserCommand(iNum, sStr, kID)) {
            // do nothing more if TRUE
        }
        else if (iNum == COMMAND_EVERYONE) {
            // you might want to react on unauthorized users or such, see message map on the top of the script, please remove if not needed
            Debug("Go away and get your own sub, you have no right on this collar");
        }
        else if (iNum == COMMAND_SAFEWORD) {
            // Safeword has been received, release any restricitions that should be released
            Debug("Safeword received, releasing the subs restricions as needed");
        }
        else if (iNum == DIALOG_RESPONSE) {
            // answer from menu system
            // careful, don't use the variable kID to identify the user, it is the UUID we generated when calling the dialog
            // you have to parse the answer from the dialog system and use the parsed variable kAv
            if (kID == g_kMenuID) {
                //got a menu response meant for us, extract the values
                list lMenuParams = llParseStringKeepNulls(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0); // avatar using the menu
                string sMessage = llList2String(lMenuParams, 1); // button label
                integer iPage = (integer)llList2String(lMenuParams, 2); // menu page
                integer iAuth = (integer)llList2String(lMenuParams, 3); // auth level of avatar
                // request to switch to parent menu
                if (sMessage == UPMENU) {
                    //give av the parent menu
                    llMessageLinked(LINK_THIS, iAuth, "menu "+COLLAR_PARENT_MENU, kAv);
                }
                else if (~llListFindList(PLUGIN_BUTTONS, [sMessage])) {
                    //we got a response for something we handle locally
                    if (sMessage == "Command 1") {
                        // do What has to be Done
                        Debug("Command 1");
                        // and restart the menu if wanted/needed
                        DoMenu(kAv, iAuth);
                    }
                    else if (sMessage == "Command 2") {
                        // do What has to be Done
                        Debug("Command 2");
                        // and restart the menu if wanted/needed
                        DoMenu(kAv, iAuth);
                    }
                    else if (sMessage == "AuthCommand") {
                        // we assume the action assoctiated to the button also
                        // has a chat command trigger, which we call here,
                        // thus finally handling menu and chat the same way
                        UserCommand(iAuth, "yourcommandhere", kAv);
                        // then we show the menu again
                        DoMenu(kAv, iAuth);
                    }
                }
                else if (~llListFindList(g_lButtons, [sMessage])) {
                    //we got a button which another plugin put into into our menu
                    llMessageLinked(LINK_THIS, iAuth, "menu "+ sMessage, kAv);
                }
            }
        }
        else if (iNum == DIALOG_TIMEOUT) {
            // timeout from menu system, you do not have to react on this, but you can
            if (kID == g_kMenuID) {
                // if you react, make sure the timeout is from your menu by checking the g_kMenuID variable
                Debug("The user was to slow or lazy, we got a timeout!");
            }
        }
    }

}