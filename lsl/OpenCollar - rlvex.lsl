//OpenCollar - rlvex
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

//********************
//stores owner info worng
//chekc default stornage
//fix names for people





///****************
/*
going to do a binary with exceptions default will be all on for owners
ability to change it for each owner
able to add other people.

will need a default settings for owners
list of people with settings
secowner settings

in the order of how they were added to the viewer
1.0:
tplure
1.01:
most chat

1.15:
accepttp

1,19:
recvemote

*/

key g_kLMID;//store the request id here when we look up a LM

key g_kMenuID;
key g_kSensorMenuID;
key g_kPersonMenuID;
list g_lPersonMenu;
list g_lExMenus;
key lmkMenuID;
key g_kDialoger;
integer g_iDialogerAuth;
list g_lScan;

list g_lOwners;
list g_lSecOwners;

string g_sParentMenu = "RLV";
string g_sSubMenu = "Exceptions";
string g_sDBToken = "rlvex";
string g_sDBToken2 = "rlvexlist";

//statics to compare
integer OWNER_DEFUALT = 63;//1+2+4+8+16+32;//all on
integer SECOWNER_DEFUALT = 0;//all off


integer g_iOwnerDefault = 63;//1+2+4+8+16+32;//all on
integer g_iSecOwnerDefault = 0;//all off

string g_sLatestRLVersionSupport = "1.15.1"; //the version which brings the latest used feature to check against
string g_sDetectedRLVersion;
list g_lSettings;//2-strided list in form of [key, value]
list g_lNames;


list g_lRLVcmds = [
    "sendim",
    "recvim",
    "recvchat",
    "recvemote",
    "tplure",
    "accepttp"
        ];
        
list g_lBinCmds = [ //binary values for each item in g_lRLVcmds
    8,
    4,
    2,
    32,
    1,
    16
        ];

list g_lPrettyCmds = [ //showing menu-friendly command names for each item in g_lRLVcmds
    "IM",
    "RcvIM",
    "RcvChat",
    "RcvEmote",
    "Lure",
    "refuseTP"
        ];

list g_lDescriptions = [ //showing descriptions for commands
    "Restriction on Send IM",
    "Restriction on Receive IM",
    "Restriction on Receive Chat",
    "Restriction on Receive Emote",
    "Restriction on Teleport by Friend",
    "Sub able to refuse a tp offer"
        ];

string TURNON = "Exempt";
string TURNOFF = "Enforce";
string DESTINATIONS = "Destinations";

integer g_iRLVOn=FALSE;
integer g_iAuth = 0;

key g_kWearer;
key g_kHTTPID = NULL_KEY;
key g_kTmpKey = NULL_KEY;
key g_kTestKey = NULL_KEY;
string g_sTmpName = "";
string g_sUserCommand = "";

//MESSAGE MAP
//integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer COMMAND_RLV_RELAY = 507;

//integer SEND_IM = 1000; deprecated. each script should send its own IMs now. This is to reduce even the tiny bt of lag caused by having IM slave descripts
integer POPUP_HELP = 1001;

integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//sStr must be in form of "token=value"
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from DB
integer LM_SETTING_EMPTY = 2004;//sent by httpdb script when a token has no value in the db


integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message.

integer RLV_OFF = 6100; // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON = 6101; // send to inform plugins that RLV is enabled now, no message or key needed

integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

//string UPMENU = "?";
//string MORE = "?";
string UPMENU = "^";
//string MORE = ">";

Debug(string sMsg)
{
//   llOwnerSay(llGetScriptName() + ": " + sMsg);
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) {
        llOwnerSay(sMsg);
    } else {
            llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer) {
            llOwnerSay(sMsg);
        }
    }
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|"
    + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kID);
    return kID;
}

Menu(key kID, string sWho, integer iAuth)
{
    if (!g_iRLVOn)
    {
        Notify(kID, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
        llMessageLinked(LINK_SET, iAuth, "menu RLV", kID);
        return;
    }
    
    list lButtons = ["Owner", "Secowner", "Other", "Add"];
    string sPrompt = "Set exceptions for the restrictions for RLV commands. Exceptions can be changed for owners, secowners and specific ones for other people. Add others with the \"Add\" button, use \"Other\" to set the specific restrictions for them later.";
    g_kMenuID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth);
}

PersonMenu(key kID, list lPeople, string sType, integer iAuth)
{
    if (iAuth != COMMAND_OWNER && kID != g_kWearer)
    {
        Menu(kID, "", iAuth);
        Notify(kID, "You are not allowed to see who is exempted.", FALSE);
        return;
    }
    //g_sRequestType = sType;
    string sPrompt = "Choose the person to change settings on.";
    list lButtons;
    //build a button list with the dances, and "More"
    //get number of secowners
    integer iNum= llGetListLength(lPeople);
    integer n;
    for (n=1; n <= iNum/2; n = n + 1)
    {
        string sName = llList2String(lPeople, 2*n-1);
        if (sName != "")
        {
            sPrompt += "\n" + (string)(n) + " - " + sName;
            lButtons += [(string)(n)];
        }
    }
    g_lPersonMenu = lPeople;
    g_kPersonMenuID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0, iAuth);
}

ExMenu(key kID, string sWho, integer iAuth)
{
    Debug("ExMenu for :"+sWho);
    if (!g_iRLVOn)
    {
        Notify(kID, "RLV features are now disabled in this collar. You can enable those in RLV submenu. Opening it now.", FALSE);
        llMessageLinked(LINK_SET, iAuth, "menu RLV", kID);
        return;
    }
    integer iExSettings = 0;
    integer iInd;
    if (sWho == "owner" || ~llListFindList(g_lOwners, [sWho]))
    {
        iExSettings = g_iOwnerDefault;
    }
    else if (sWho == "secowners" || ~llListFindList(g_lSecOwners, [sWho]))
    {
        iExSettings = g_iSecOwnerDefault;
    }
    if (~iInd = llListFindList(g_lSettings, [sWho])) // replace deefault with custom
    {
        iExSettings = llList2Integer(g_lSettings, iInd + 1);
    }
    string sPrompt = "\nCurrent Settings: ";
    if (sWho != "owner" && sWho != "secowner") sPrompt = "[Defaults] will remove this person from the \"Others\" list." + sPrompt;
    list lButtons;
    integer n;
    integer iStop = llGetListLength(g_lRLVcmds);
    for (n = 0; n < iStop; n++)
    {
        //see if there's a setting for this in the settings list
        string sCmd = llList2String(g_lRLVcmds, n);
        string sPretty = llList2String(g_lPrettyCmds, n);
        string sDesc = llList2String(g_lDescriptions, n);
        if (iExSettings & llList2Integer(g_lBinCmds, n))
        {
            lButtons += [TURNOFF + " " + sPretty];
            sPrompt += "\n" + sPretty + " = Exempted (" + sDesc + ")";
        }
        else
        {
            lButtons += [TURNON + " " + sPretty];
            sPrompt += "\n" + sPretty + " = Enforced (" + sDesc + ")";
        }
    }
    //give an Allow All button
    lButtons += [TURNON + " All"];
    lButtons += [TURNOFF + " All"];
    //add list button
    if (sWho == "owner")
    {
        lButtons += ["List"];
    }
    else if (sWho == "secowner")
    {
        lButtons += ["List"];
    }
    Debug(sPrompt);
    Debug((string)llStringLength(sPrompt));
    key kTmp = Dialog(kID, sPrompt, lButtons, ["Defaults", UPMENU], 0, iAuth);
    g_lExMenus = [kTmp, sWho] + g_lExMenus;
}

UpdateSettings()
{
    //for now just redirect
    SetAllExs("");
}

SaveDefaults()
{
    //save to DB
    if (OWNER_DEFUALT == g_iOwnerDefault && SECOWNER_DEFUALT == g_iSecOwnerDefault)
    {
        llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sDBToken, NULL_KEY);
        return;
    }
    llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sDBToken + "=" + llDumpList2String([g_iOwnerDefault, g_iSecOwnerDefault], ","), NULL_KEY);
}
SaveSettings()
{
    //save to local settings
    if (llGetListLength(g_lSettings))
    {
        llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sDBToken2 + "=" + llDumpList2String(g_lSettings, ","), NULL_KEY);
    }
    else
    {
        llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sDBToken2, NULL_KEY);
    }
}

ClearSettings()
{
    //clear settings list
    g_lSettings = [];
    //remove tpsettings from DB... now done by httpdb itself
    llMessageLinked(LINK_SET, LM_SETTING_DELETE, g_sDBToken, NULL_KEY);
    //main RLV script will take care of sending @clear to viewer
    //avoid race conditions
    llSleep(1.0);
}

MakeNamesList()
{
    g_lNames = [];
    integer iNum = llGetListLength(g_lSettings);
    integer n;
    for (n=0; n < iNum; n = n + 2)
    {
        string sKey = llList2String(g_lSettings, n);
        AddName(sKey);
    }
}
Name2Key(string sName)
{
    // Variant of N2K, uses SL's internal search engine instead of external databases
    string url = "http://www.w3.org/services/html2txt?url=";
    string escape = "http://vwrsearch.secondlife.com/client_search.php?session=00000000-0000-0000-0000-000000000000&q=";
    g_kHTTPID = llHTTPRequest(url + llEscapeURL(escape) + llEscapeURL(sName), [], "");
}

AddName(string sKey)
{
    if (~llListFindList(g_lNames, [sKey])) jump AddDone; // prevent dupes
    integer iInd = llListFindList(g_lOwners, [sKey]);
    if (g_kHTTPID) // Name2Key
    {
        g_kHTTPID = NULL_KEY;
        g_lNames += [sKey, g_sTmpName];
        if (g_kTmpKey != NULL_KEY) Notify(g_kTmpKey, g_sTmpName + " has been successfully added to Exceptions User List.", FALSE);
    }
    else if (~iInd)
    {
        g_lNames += [sKey, llList2String(g_lOwners, iInd + 1)];
    }
    else if (~iInd = llListFindList(g_lSecOwners, [sKey]))
    {
        g_lNames += [sKey, llList2String(g_lSecOwners, iInd + 1)];
    }
    else if((key)sKey)
    {
        //lookup and put the uuid for the request in for now
        g_lNames += [sKey, g_kTestKey = llRequestAgentData(sKey, DATA_NAME)];
        // llSleep(1);  --- unnecessary, as llRequestAgentData will induce a 0.1 second sleep
        llSetTimerEvent(0.5); // if not a valid avi uuid, we'll revert the names list
        return; // timer event will need (& reset) the Tmp values, & resend usercommands for this person
    }
    @AddDone;
    if (g_sUserCommand != "") UserCommand(g_iAuth, sKey + ":" + g_sUserCommand, g_kTmpKey); // continue processing commands
    g_iAuth = 0;
    g_kTmpKey = g_kTestKey = NULL_KEY;
    g_sTmpName = g_sUserCommand = "";
}

SetOwnersExs(string sVal)
{
    if (!g_iRLVOn)
    {
        return;
    }
    integer iLength = llGetListLength(g_lOwners);
    if (iLength)
    {
        integer iStop = llGetListLength(g_lRLVcmds);
        integer n;
        integer i;
        list sCmd;
        for (n = 0; n < iLength; n += 2)
        {
            sCmd = [];
            string sTmpOwner = llList2String(g_lOwners, n);
            if (llListFindList(g_lSettings, [sTmpOwner]) != -1)
            {
                for (i = 0; i<iStop; i++)
                {
                    if (g_iOwnerDefault & llList2Integer(g_lBinCmds, i) )
                    {
                        sCmd += [llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=n"];// +sVal];
                    }
                    else
                    {
                        sCmd += [llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=y"];// +sVal];
                    }
                }
                string sStr = llDumpList2String(sCmd, ",");
                //llOwnerSay("sending " + sStr);
                //llMessageLinked(LINK_SET, RLV_CMD, sStr, NULL_KEY);
                llOwnerSay("@" + sStr);
            }
        }
    }
}

SetAllExs(string sVal)
{//llOwnerSay("allvars");
    if (!g_iRLVOn)
    {
        return;
    }
    integer iStop = llGetListLength(g_lRLVcmds);
    integer iLength = llGetListLength(g_lOwners);
    if (iLength)
    {
        integer n;
        integer i;
        list sCmd;
        for (n = 0; n < iLength; n += 2)
        {
            sCmd = [];
            string sTmpOwner = llList2String(g_lOwners, n);
            if (llListFindList(g_lSettings, [sTmpOwner]) == -1)
            {
                for (i = 0; i<iStop; i++)
                {
                    if (g_iOwnerDefault & llList2Integer(g_lBinCmds, i) )
                    {
                        sCmd += [llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=n"];// +sVal];
                    }
                    else
                    {
                        sCmd += [llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=y"];// +sVal];
                    }
                }
                string sStr = llDumpList2String(sCmd, ",");
                //llOwnerSay("sending " + sStr);
                //llMessageLinked(LINK_SET, RLV_CMD, sStr, NULL_KEY);
                llOwnerSay("@" + sStr);
            }
        }
    }
    iLength = llGetListLength(g_lSecOwners);
    if (iLength)
    {
        integer n;
        integer i;
        list sCmd;
        for (n = 0; n < iLength; n += 2)
        {
            sCmd = [];
            string sTmpOwner = llList2String(g_lSecOwners, n);
            if (llListFindList(g_lSettings, [sTmpOwner]) == -1)
            {
                for (i = 0; i<iStop; i++)
                {
                    if (g_iSecOwnerDefault & llList2Integer(g_lBinCmds, i) )
                    {
                        sCmd += [llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=n"];// +sVal];
                    }
                    else
                    {
                        sCmd += [llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=y"];// +sVal];
                    }
                }
                string sStr = llDumpList2String(sCmd, ",");
                //llOwnerSay("sending " + sStr);
                //llMessageLinked(LINK_SET, RLV_CMD, sStr, NULL_KEY);
                llOwnerSay("@" + sStr);
            }
        }
    }
    iLength = llGetListLength(g_lSettings);
    if (iLength)
    {
        integer n;
        integer i;
        list sCmd;
        for (n = 0; n < iLength; n += 2)
        {
            sCmd = [];
            string sTmpOwner = llList2String(g_lSettings, n);
            integer iTmpOwner = llList2Integer(g_lSettings, n+1);
            for (i = 0; i<iStop; i++)
            {
                if (iTmpOwner & llList2Integer(g_lBinCmds, i) )
                {
                    sCmd += [llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=n"];// +sVal];
                }
                else
                {
                    sCmd += [llList2String(g_lRLVcmds, i) + ":" + sTmpOwner + "=y"];// +sVal];
                }
            }
            string sStr = llDumpList2String(sCmd, ",");
            //llOwnerSay("sending " + sStr);
            //llMessageLinked(LINK_SET, RLV_CMD, sStr, NULL_KEY);
            llOwnerSay("@" + sStr);
        }
    }
}
ClearEx()
{
    llOwnerSay("@clear=sendim:,clear=recvim:,clear=recvchat:,clear=recvemote:,clear=tplure:,clear=accepttp:");
}

integer UserCommand(integer iNum, string sStr, key kID)
{
    if ((sStr == "reset" || sStr == "runaway") && (iNum == COMMAND_OWNER || iNum == COMMAND_WEARER)) llResetScript();
    string sLower = llToLower(sStr);
    if (sLower == "menu " + llToLower(g_sSubMenu)) sLower = "ex"; // so that we can run elimination round right away
    list lParts = llParseString2List(sStr, [" "], []); // ex,add,first,last at most
    integer iInd = llGetListLength(lParts);
    // Primary owners only beyond this point! check for valid ex-command
    if (iNum != COMMAND_OWNER || iInd < 1 || iInd > 4 || sLower != "ex") return FALSE;
    if (sLower == "ex")
    {
        Menu(kID, "", iNum);
        jump UCDone;
    }
    string sCom = llToLower(llList2String(lParts = llDeleteSubList(lParts, 0, 0), 0));
    if (iInd == 1) // handle requests 4 menus first
    {
        if (sCom == "owner") ExMenu(kID, "owner", iNum);
        else if (sCom == "secowner") ExMenu(kID, "secowner", iNum);
        else if (sCom == "other") PersonMenu(kID, g_lNames, "", iNum);
        else if (sCom == "add")
        {
            g_kDialoger = kID;
            g_iDialogerAuth = iNum;
            llSensor("", "", AGENT, 10.0, PI);
        }
        if (!llSubStringIndex(sCom, ":")) jump UCDone;// not done if we received a 1-who 1-exception case
    }
    string sVal = llList2String(lParts, 1);
    if (sCom == "add") // request to add specified user to names list - must be "add First Last" or "add uuid"
    {
        g_iAuth = iNum;
        g_kTmpKey = kID;
        if ((key)sVal) AddName(sVal);
        else if (iInd == 3) Name2Key(g_sTmpName = llDumpList2String(llDeleteSubList(lParts, 0, 0), " "));
        else
        {
            g_iAuth = 0;
            g_kTmpKey = NULL_KEY;
            Notify(kID, "<prefix>ex add <value> -- value must be an avi key or legacy name", FALSE);
        }
        jump UCDone;
    }
    // anything else should be <prefix>ex user:command=value & may be strided with commas
    // if user is unknown to us, we'll re-run undone commands after they are sucessfully added, to prevent errors
    lParts = llParseString2List(llGetSubString(sStr, 3, -1), [":"], []); // separate entries by user
    iInd = llGetListLength(lParts) - 1;
    list lCom;
    string sWho;
    integer bChange;
    integer iRLV;
    integer iBin;
    integer iSet;
    integer iN2K;
    integer iL = 0;
    integer iC = 0;
    for (; iL < iInd; iL += 2) // cycle through users
    {
        // Let's get a uuid to work with, if who is an avatar. This enables users to type in names OR keys for chat commands.
        sWho = llList2String(lParts, 0); // we'll shave the lParts list as we go
        sLower = llToLower(sWho);
        iInd = llListFindList(g_lNames, [sWho]);
        // let's make certain that we carry unprocessed requests thru AddNames
        g_sUserCommand = "ex " + llDumpList2String(lParts, ":");
        if (sLower == "clear" || sLower == "owner" || sLower == "secowner") {}
        else if ((key)sWho)
        {
            if (iInd == -1)
            {
                g_iAuth = iNum;
                g_kTmpKey = kID;
                AddName(sWho);
                jump UCDone;
            }
            // else it is a uuid & is in list already, so we don't want to alter it
        }
        else if (~iInd) sWho = llList2String(g_lNames, iInd - 1); // name used & in list
        else // This who is (hopefully) a username & doesn't exist in our others list, yet.
        {
            g_iAuth = iNum;
            g_kTmpKey = kID;
            Name2Key(g_sTmpName = sWho);
            string note = "It will take a moment to retrieve the key for " + sWho;
            note += ". Remaining requests will be processed shortly.";
            Notify(kID, note, FALSE);
            jump UCDone; // AddName/N2K will re-push the remaining requests when they finish
        }
        // okay, now we have a key for sWho (if avatar) & they are in g_lNames - this will deliver all settings to the right places
        g_sUserCommand = "";
        lCom = llParseString2List(llToLower(llList2String(lParts, 1)), [","], []);
        lParts = llDeleteSubList(lParts, 0, 1); // I did say that we'd be removing items as we process them, didn't I?
        sCom = llList2String(lCom, 0);
        if (llGetSubString(sCom, 0, 3) == "all=") // should be the only entry for this Who if so
        {
            lCom = []; // convert all rlvcmds to a strided list of "cmd1=x,cmd2=x" etc
            sVal = llGetSubString(sCom, 3, -1);
            for (iC = 0; iC < llGetListLength(g_lRLVcmds); iC++)
            {
                lCom += [llList2String(g_lRLVcmds, iC) + sVal];
            }
        }
        for (iC = 0; iC < llGetListLength(lCom); iC++) // cycle through strided entries
        {
            sCom = llList2String(lCom, iC);
            if (sCom == "clear")
            {
                //ClearSettings();
                // do we want anything here this is for excpetions
                jump nextcom;
            }
            if (~iInd = llSubStringIndex(sCom, "="))
            {
                sVal = llGetSubString(sCom, iInd + 1, -1);
                sCom = llGetSubString(sCom, 0, iInd -1);
            }
            else sVal = "";
            if (sVal == "exempt" || sVal == "add") sVal = "n"; // conversions
            else if (sVal == "enforce" || sVal == "rem") sVal = "y";
            iRLV = llListFindList(g_lRLVcmds, [sCom]);
            if (iRLV == -1 && sCom != "defaults") jump nextcom; // invalid request
            iBin = llList2Integer(g_lBinCmds, iRLV);
            if (sWho == "owner")
            {
                if (sCom == "defaults") g_iOwnerDefault = OWNER_DEFUALT;
                else if (sVal == "n") g_iOwnerDefault = g_iOwnerDefault | iBin;
                else if (sVal == "y") g_iOwnerDefault = g_iOwnerDefault & ~iBin;
                bChange = bChange | 1;
                jump nextcom;
            }
            if (sWho == "secowner")
            {
                if (sCom == "defaults") g_iSecOwnerDefault = SECOWNER_DEFUALT;
                else if (sVal == "n") g_iSecOwnerDefault = g_iSecOwnerDefault | iBin;
                else if (sVal == "y") g_iSecOwnerDefault = g_iSecOwnerDefault & ~iBin;
                bChange = bChange | 1;
                jump nextcom;
            }
            iInd = llListFindList(g_lSettings, [sWho]);
            if (sCom == "defaults")
            {
                if (~iInd) g_lSettings = llDeleteSubList(g_lSettings, iInd, iInd + 1);
                if (~iInd = llListFindList(g_lNames, [sWho])) g_lNames = llDeleteSubList(g_lNames, iInd, iInd + 1);
                bChange = bChange | 2;
                jump nextcom;
            }
            if (~iInd) iSet = llList2Integer(g_lSettings, iInd + 1);
            else if (~llListFindList(g_lOwners, [sWho])) iSet = g_iOwnerDefault;
            else if (~llListFindList(g_lSecOwners, [sWho])) iSet = g_iSecOwnerDefault;
            else iSet = 0;
            if (sVal == "n") iSet = iSet | iBin;
            else if (sVal == "y") iSet = iSet & ~iBin;
            else jump nextcom; // invalid setting param
            if (~iInd) g_lSettings = llListReplaceList(g_lSettings, [iSet], iInd + 1, iInd + 1);
            else g_lSettings += [sWho, iSet];
            bChange = bChange | 2;
            @nextcom;
            Debug("processed " + sWho + ":" + sCom + "=" + sVal);
        }
        @nextwho;
    }
    @UCDone;
    if (bChange)
    {
        UpdateSettings();
        if(bChange & 1) SaveDefaults();
        if(bChange & 2) SaveSettings();
    }
    return TRUE;
}

default
{
    on_rez(integer iParam)
    {
        llResetScript();
    }

    state_entry()
    {
        g_kWearer = llGetOwner();
        g_kTmpKey = NULL_KEY;
        g_sTmpName = "";
        //llSleep(1.0);
        //llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
        //llMessageLinked(LINK_SET, LM_SETTING_REQUEST, g_sDBToken, NULL_KEY);
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (UserCommand(iNum, sStr, kID)) return;
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
        }
        else if (iNum == LM_SETTING_RESPONSE)
        {
            //this is tricky since our stored value contains equals signs
            //split string on both comma and equals sign
            //first see if this is the token we care about
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == g_sDBToken)
            {
                list lTmp = llParseString2List(sValue, [","], []);
                g_iOwnerDefault = llList2Integer(lTmp, 0);
                g_iSecOwnerDefault = llList2Integer(lTmp, 1);
            }
            else if (sToken == g_sDBToken2)
            {
                //throw away first element
                //everything else is real settings (should be even number)
                g_lSettings = llParseString2List(sValue, [","], []);
                MakeNamesList();
                //UpdateSettings();
                //do it when all the settings are done
            }
            else if (sToken == "owner")
            {
                //SetOwnersExs("rem");
                g_lOwners = llParseString2List(sValue, [","], []);
                //send accepttp command
                //SetOwnersExs("add");
            }
            else if (sToken == "secowner")
            {
                //SetOwnersExs("rem");
                g_lSecOwners = llParseString2List(sValue, [","], []);
                //send accepttp command
                //SetOwnersExs("add");
            }
            else if (sToken == "settings")
            {
                if (sValue == "sent")
                {
                    SetAllExs("");//sendcommands
                }
            }
        }
        else if (iNum == LM_SETTING_SAVE)
        {
            //handle saving new owner here
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            //does soemthing here need to change?
            if (sToken == "owner")
            {
                g_lOwners = llParseString2List(sValue, [","], []);
                ClearEx();
                UpdateSettings();
            }
            else if (sToken == "secowner")
            {
                g_lSecOwners = llParseString2List(sValue, [","], []);
                //send accepttp command
                ClearEx();
                UpdateSettings();
            }
        }
        else if (iNum == RLV_REFRESH)
        {
            //rlvmain just started up. Tell it about our current restrictions
            g_iRLVOn = TRUE;
            UpdateSettings();
        }
        else if (iNum == RLV_CLEAR)
        {
            //clear db and local settings list
            //ClearSettings();
            //do we not want to reset it?
            llSleep(2.0);
            UpdateSettings();
        }
        else if (iNum == RLV_VERSION)
        {
            g_sDetectedRLVersion = sStr;
        }
        else if (iNum == RLV_OFF) // rlvoff -> we have to turn the menu off too
        {
            g_iRLVOn=FALSE;
        }
        else if (iNum == RLV_ON)
        {
            g_iRLVOn=TRUE;
            UpdateSettings();//send the settings as we did notbefore
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            if (kID == g_kMenuID)
            {
                Debug("dialog response: " + sStr);
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                //if we got *Back*, then request submenu RLV
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET, iAuth, "menu " + g_sParentMenu, kAv);
                }
                else if (sMessage == "Owner")
                {
                    //give menu for owners defaults
                    ExMenu(kAv, "owner", iAuth);
                }
                else if (sMessage == "Secowner")
                {
                    //give menu for secowners defaults
                    ExMenu(kAv, "secowner", iAuth);
                }
                else if (sMessage == "Add")
                {
                    g_kDialoger = kAv;
                    g_iDialogerAuth = iAuth;
                    llSensor("", "", AGENT, 10.0, PI);
                }
                else if (sMessage == "Other") PersonMenu(kAv, g_lNames, "", iAuth);
            }
            else if (llListFindList(g_lExMenus, [kID]) != -1 )
            {
                Debug("dialog response: " + sStr);
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                integer iMenuIndex = llListFindList(g_lExMenus, [kID]);
                if (sMessage == UPMENU) Menu(kAv,"", iAuth);
                else
                {
                    // clear out Tmp settings
                    g_kTmpKey = NULL_KEY;
                    g_sTmpName = g_sUserCommand = "";
                    string sMenu = llList2String(g_lExMenus, iMenuIndex + 1);
                    //we got a command to enable or disable something, like "Enable LM"
                    //get the actual command same by looking up the pretty name from the message
                    list lParams = llParseString2List(sMessage, [" "], []);
                    string sSwitch = llList2String(lParams, 0);
                    string sCmd = llList2String(lParams, 1);
                    string sOut = "ex " + sMenu + ":";
                    integer iIndex = llListFindList(g_lPrettyCmds, [sCmd]);
                    if (sCmd == "All")
                    {
                        //handle the "Allow All" and "Forbid All" commands
                        sOut += "all";
                        //decide whether we need to switch to "y" or "n"
                        if (sSwitch == TURNOFF) sOut += "=y"; // exempt
                        else if (sSwitch == TURNON) sOut += "=n"; // enforce
                        UserCommand(iAuth, sOut, kAv);
                        ExMenu(kAv, sMenu, iAuth);
                    }
                    else if (~iIndex)
                    {
                        sOut += llList2String(g_lRLVcmds, iIndex);
                        if (sSwitch == TURNOFF) sOut += "=y"; // exempt
                        else if (sSwitch == TURNON) sOut += "=n"; // enforce
                        //send rlv command out through auth system as though it were a chat command, just to make sure person who said it has proper authority
                        Debug("ExMenu sending UC: " + sOut);
                        UserCommand(iAuth, sOut, kAv);
                        ExMenu(kAv, sMenu, iAuth);
                    }
                    else if (sMessage == "Defaults")
                    {
                        UserCommand(iAuth, sOut + "defaults", kAv);
                        ExMenu(kAv, sMenu, iAuth);
                    }
                    else if (sMessage == "List")
                    {
                        if (sMenu == "owner")
                        {
                            PersonMenu(kAv, g_lOwners, "", iAuth);
                        }
                        else if (sMenu == "secowner")
                        {
                            PersonMenu(kAv, g_lSecOwners, "", iAuth);
                        }
                    }
                    else
                    {
                        //something went horribly wrong. We got a command that we can't find in the list
                    }
                    llDeleteSubList(g_lExMenus, iMenuIndex, iMenuIndex + 1);
                }
            }
            else if(kID == g_kPersonMenuID)
            {
                Debug("dialog response: " + sStr);
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                if (sMessage == UPMENU) Menu(kAv, "", iAuth);
                else
                {
                    string sTmp = llList2String(g_lPersonMenu, (integer)sMessage*2-2); //g_lOwners + g_lSecOwners + g_lScan + g_lNames, llListFindList(g_lOwners + g_lSecOwners + g_lScan + g_lNames, [sMessage])-1);
                    ExMenu(kAv, sTmp, iAuth);
                    //g_lScan = [];
                }
            }
            else if(kID == g_kSensorMenuID)
            {
                Debug("dialog response: " + sStr);
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                if (sMessage == UPMENU) Menu(kAv, "", iAuth);
                else
                {
                    string sTmp = llList2String(g_lOwners + g_lSecOwners + g_lScan + g_lNames, llListFindList(g_lOwners + g_lSecOwners + g_lScan + g_lNames, [sMessage])-1);
                    ExMenu(kAv, sTmp, iAuth);
                    g_lScan = [];
                }
            }
        }
    }
    http_response(key kID, integer iStatus, list lMeta, string sBody)
    {
        if (kID == g_kHTTPID && iStatus == 200)
        {
            key kAvi = (key)llList2String(llParseString2List(sBody, ["secondlife:///app/agent/", "/about"], []),1);
            if (kAvi)
            {
                AddName((string)kAvi);
                return;
            }
        }
        if (g_kTmpKey != NULL_KEY) Notify(g_kTmpKey, "Unable to retrieve key for " + g_sTmpName, FALSE);
        // shave the first entry out of usercommand, since the name/key is not valid
        list lTemp = llDeleteSubList(llParseString2List(g_sUserCommand, [":"], []), 0, 1);
        g_sUserCommand = llDumpList2String(lTemp, ":");
        if (g_sUserCommand != "") UserCommand(g_iAuth, "ex " +  g_sUserCommand, g_kTmpKey); // continue processing commands
        g_iAuth = 0;
        g_kTmpKey = g_kHTTPID = NULL_KEY;
        g_sTmpName = g_sUserCommand = "";
    }
    dataserver(key kID, string sData)
    {
        integer iIndex = llListFindList(g_lNames, [(string)kID]);
        if (~iIndex)
        {
            llSetTimerEvent(0);
            g_lNames = llListReplaceList(g_lNames, [sData], iIndex, iIndex);
            if (g_sUserCommand != "") UserCommand(g_iAuth, g_sUserCommand, g_kTmpKey);
            if (g_kTmpKey != NULL_KEY) Notify(g_kTmpKey, "Successfully added " + sData + " to exemptions user list.", FALSE);
            g_iAuth = 0;
            g_kTmpKey = g_kTestKey = NULL_KEY;
            g_sTmpName = g_sUserCommand = "";
        }
    }
    sensor(integer iNum_detected)
    {
        list lButtons;
        string sName;
        integer i;
        for(i = 0; i < iNum_detected; i++)
        {
            sName = llDetectedName(i);
            lButtons += [sName];
            g_lScan += [(string)llDetectedKey(i) ,sName];
        }
        // add wearer if not already in button list
        // g_lScan += [(string)g_kWearer, llKey2Name(g_kWearer)];
        if (llGetListLength(lButtons) > 0)
        {
            string sText = "Select who you would like to add.\nIf the one you want to add does not show, move closer and repeat or use the chat command.";
            g_kSensorMenuID = Dialog(g_kDialoger, sText, lButtons, [UPMENU], 0, g_iDialogerAuth);
        }
        //llOwnerSay((string)llGetFreeMemory());
    }

    no_sensor()
    {
        Notify(g_kDialoger, "Nobody is in 10m range to be shown, either move closer or use the chat command to add someone who is not with you at this moment or offline.",FALSE);
  
    }
    timer() // RequestAgentData fail
    {
        llSetTimerEvent(0);
        integer i = llListFindList(g_lNames, [g_kTestKey]);
        string badkey = llList2String(g_lNames, i - 1);
        g_lNames = llDeleteSubList(g_lNames, i - 1, i);
        list temp = llDeleteSubList(llParseString2List(g_sUserCommand, [":"], []), 0, 1);
        g_sUserCommand = llDumpList2String(temp, ":");
        if (g_sUserCommand != "") UserCommand(g_iAuth, "ex " + g_sUserCommand, g_kTmpKey);
        if (g_kTmpKey != NULL_KEY) Notify(g_kTmpKey, badkey + " is not a valid avatar uuid.", FALSE);
        g_iAuth = 0;
        g_kTmpKey = g_kTestKey = NULL_KEY;
        g_sTmpName = g_sUserCommand = "";
    }
}
