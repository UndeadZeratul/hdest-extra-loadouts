// ------------------------------------------------------------
// Menu
// ------------------------------------------------------------
Version "4.10.0"
enum HDLoadoutMenuNums{
	HD_MAXLOADOUTS=100,
}
class HDLoadoutMenu2:GenericMenu{
	array<string> refids;
	array<string> nicenames;
	array<string> bprefids;
	string translatedloadout;
	string loadoutname;
	textureid loadoutpic;
	string workingstring;
	string statusstring;
	string loadoutdisplaystring;
	string clipboard;
	string undo;
	string reflist;
	int cursx;
	int cursy;
	int tlcursy;
	bool different;
	bool viewlist;
	bool isnewgamemenu;
	bool showhelp;
	override void Init(menu parent){
		super.Init(parent);
		refids.clear();
		nicenames.clear();
		bprefids.clear();
		cursx=0;cursy=1;
		tlcursy=0;
		isnewgamemenu=false;
		different=false;
		showhelp=false;
		statusstring=Stringtable.Localize("$LOADOUTMENU_EDITING")..cursy;
		statustimer=0;
		loadoutname="";
		loadoutpic=texman.checkfortexture("TNT1A0",texman.type_sprite);
		reflist="";viewlist=false;

		string curclass=cvar.findcvar("playerclass").getstring();
		if(curclass.left(8)~=="Loadout "){
			cursy=clamp(curclass.mid(8).toint(),1,HD_MAXLOADOUTS);
		}

		int jw=0;int jp=0;
		for(int i=0;i<allactorclasses.size();i++){
			class<actor> reff=allactorclasses[i];
			if(reff is "HDPickup"){
				let ref=getdefaultbytype((class<hdpickup>)(reff));
				if(ref.refid!=""){
					string lrefid=ref.refid.makelower();
					refids.push(lrefid);
					nicenames.push(ref.gettag());
					if(!(jp%5))reflist=reflist.."\n";jp++;
					reflist=reflist.."\n\cy"..ref.refid.."\cj   "..ref.gettag();
				}
			}else if(reff is "HDWeapon"){
				let ref=getdefaultbytype((class<hdweapon>)(reff));
				if(
					ref.refid!=""
					&&(
						!ref.bdebugonly
						||hd_debug>0
					)
				){
					string lrefid=ref.refid.makelower();
					refids.push(lrefid);
					nicenames.push(ref.gettag());
					if(reff is "HDBackpack")bprefids.push(lrefid);
					if(!(jw%5))reflist="\n"..reflist;jw++;

					//determine colour
					string refidcol="\n\c"..(ref.bdebugonly?"u":(ref.bwimpy_weapon?"y":"x"));

					//if there are loadout codes, add them
					string rgt=ref.gettag();
					string loc=ref.loadoutcodes;
					if(loc!="")rgt=rgt..loc;

					//treat wimpy weapons as inventory items
					if(ref.bwimpy_weapon)
						reflist=reflist..refidcol..ref.refid.."\cj   "..rgt;
					else
						reflist=refidcol..ref.refid.."\cj   "..rgt..reflist;
				}
			}
		}
		workingstring=cvar.findcvar("hd_loadout"..cursy).getstring();
		translatedloadout=gettranslatedloadout(workingstring);
		undo=workingstring;
		reflist=reflist.mid(1); //get rid of the first "\n"
	}
	override bool MenuEvent(int mkey, bool fromcontroller){
		switch(mkey){
		case MKEY_Left:
			cursx=max(0,cursx-1);
			break;
		case MKEY_Right:
			cursx=min(workingstring.length(),cursx+1);
			break;
		case MKEY_Clear: //backspace
			if(cursx>0){
				workingstring=workingstring.left(cursx-1)..workingstring.mid(cursx);
				cursx--;
				checkdifferent();
			}
			break;
		case MKEY_Back:
			if(checkdifferent()){
				resetws();
				return false;
			}
			break;
		case MKEY_Up:
			if(checkdifferent()){
				statustext(Stringtable.Localize("$"));
			}else{
				cursy--;
				if(cursy<1)cursy=HD_MAXLOADOUTS;
				statustimer=0;
				MenuSound("menu/cursor");
				resetws();
			}
			break;
		case MKEY_Down:
			if(checkdifferent()){
				statustext(Stringtable.Localize("$LOADOUTMENU_SAVE"));
			}else{
				cursy++;
				if(cursy>HD_MAXLOADOUTS)cursy=1;
				statustimer=0;
				MenuSound("menu/cursor");
				resetws();
			}
			break;
		case MKEY_Enter:
			if(different)savechanges();
			else{
				cvar.findcvar("playerclass").setstring("Loadout "..cursy);
				cvar.findcvar("hd_myloadout").setstring("");
				statustext(Stringtable.Localize("$LOADOUTMENU_SETTONUM")..cursy..".");
			}
			break;
		case MKEY_PageUp:
			tlcursy=max(0,tlcursy-12);
			break;
		case MKEY_PageDown:
			tlcursy+=12;
			break;
		}
		translatedloadout=gettranslatedloadout(workingstring);
		return super.menuevent(mkey,fromcontroller);
	}
	override bool OnUIEvent(UIEvent ev){
		if(ev.Type==UIEvent.Type_KeyDown){
			switch(ev.KeyChar){
			case UIEvent.Key_Home:
				if(ev.IsCtrl)tlcursy=0;
				else cursx=0;
				break;
			case UIEvent.Key_End:
				if(ev.IsCtrl)tlcursy=int.MAX;
				else cursx=workingstring.length();
				break;
			case UIEvent.Key_Del:
				workingstring=workingstring.left(cursx)..workingstring.mid(cursx+1);
				checkdifferent();
				break;
			case UIEvent.Key_F1:
				if(viewlist)viewlist=false;else viewlist=true;
				tlcursy=0;
				break;
			case UIEvent.Key_F2:
			case UIEvent.Key_F3:
			case UIEvent.Key_F4:
			case UIEvent.Key_F5:
			case UIEvent.Key_F6:
			case UIEvent.Key_F7:
			case UIEvent.Key_F8:
			case UIEvent.Key_F9:
			case UIEvent.Key_F11:
			case UIEvent.Key_F12:
				break;
			case UIEvent.Key_F10:
				MenuSound("menu/clear");
				resetws();
				close();
				break;
			default:
				string inp="";
				inp.appendformat("%c",ev.KeyChar);
				if(ev.IsCtrl){
					if(inp~=="r"){
						string bak=cvar.findcvar("hd_loadout"..cursy).getstring();
						cvar.findcvar("hd_loadout"..cursy).resettodefault();
						statustext(Stringtable.Localize("$LOADOUTMENU_RESETLOADOUT"));
						resetws();
						undo=bak;
					}else if(inp~=="s"){
						savechanges();
					}else if(inp~=="z"){
						workingstring=undo;
					}else if(inp~=="x"){
						clipboard=workingstring;
						workingstring="";
						statustext(Stringtable.Localize("$LOADOUTMENU_CUTTOBOARD"));
					}else if(inp~=="c"){
						clipboard=workingstring;
						statustext(Stringtable.Localize("$LOADOUTMENU_COPYFROMBOARD"));
					}else if(inp~=="v"){
						workingstring=clipboard;
						statustext(Stringtable.Localize("$LOADOUTMENU_PASTEFROMBOARD"));
					}else if(inp~=="f"){
						if(viewlist)viewlist=false;else viewlist=true;
						tlcursy=0;
						maxtextwidth=0;
					}else if(inp~=="h"){
						showhelp=!showhelp;
					}else if(inp~=="n"){
						if(
							workingstring==cvar.findcvar("hd_loadout"..cursy).getstring()
						){
							MenuSound("menu/choose");
							cvar.findcvar("playerclass").setstring("Loadout "..cursy);
							Menu.SetMenu("PlayerclassMenu");
						}else{
							statustext(Stringtable.Localize("$LOADOUTMENU_SAVEFIRST"));
						}
						return true;
					}
				}
				break;
			}
		}else if(ev.Type==UIEvent.Type_Char){
			workingstring=workingstring.left(cursx)..ev.KeyString..workingstring.mid(cursx);
			cursx++;

		//[2023-03-15 mc] apparently this actually works, just not on my system
        }else if(ev.type == UIEvent.Type_WheelUp){
            tlcursy=max(0,tlcursy-3);
        }else if (ev.type == UIEvent.Type_WheelDown){
            tlcursy+=3;
		}

		checkdifferent();
		translatedloadout=gettranslatedloadout(workingstring);
		return Super.OnUIEvent(ev);
	}
	void StatusText(string input,int timer=70){
		statusstring=input;
		statustimer=timer;
	}
	void savechanges(){
		if(checkdifferent()){
			undo=cvar.findcvar("hd_loadout"..cursy).getstring();
			cvar.findcvar("hd_loadout"..cursy).setstring(workingstring);
			statustext(Stringtable.Localize("$LOADOUTMENU_LOADSAVEDTO")..cursy.." -");
			checkdifferent();
		}
		tlcursy=0;
	}
	void resetws(){
		string def=cvar.findcvar("hd_loadout"..cursy).getstring();
		if(def!=workingstring)workingstring=def;
		different=false;
		translatedloadout=gettranslatedloadout(workingstring);
		cursx=workingstring.length();
		undo=workingstring;
		tlcursy=0;
	}
	bool checkdifferent(){
		string def=cvar.findcvar("hd_loadout"..cursy).getstring();
		different=def!=workingstring;
		return different;
	}
	virtual string GetTranslatedLoadout(string input){
		string ttl="";
		string lon;
		string desc;
		[loadoutdisplaystring,loadoutname,lon,desc]=HDMath.GetLoadoutStrings(input,true);
		if(viewlist)ttl=reflist;
		else{
			array<string>items;items.clear();
			array<string>bpitems;bpitems.clear();

			string finalinput=loadoutdisplaystring;finalinput.replace(" ","");
			loadoutpic=texman.checkfortexture(lon,texman.type_any);
			if(finalinput~=="doomguy"){
				ttl=Stringtable.Localize("$LOADOUTMENU_DOOMGUY");
			}else if(finalinput~=="insurgent"){
				ttl=Stringtable.Localize("$LOADOUTMENU_INSURGENT");
			}else if(finalinput==""){
				ttl=Stringtable.Localize("$LOADOUTMENU_NATURIST");
			}else{
				if(desc!="")ttl=desc.."\n\n"..ttl;
				finalinput.split(items,"-");
				bool inbp=items.size()>1;
				if(inbp)items[1].split(bpitems,",");
				string iitems=items[0];items.clear();
				iitems.split(items,",");
				for(int i=0;i<items.size();i++){
					string refid=items[i].left(3);
					if(refid=="")continue;

					int whichindex=refids.find(refid);
					string thisname;
					if(whichindex>=refids.size())thisname="\ca ? ? ?\cj";
					else thisname=nicenames[whichindex];
					int howmany=max((items[i].mid(3,items[i].length())).toint(10),1);
					ttl=ttl..(i?"\n":"")..howmany.." x    "..thisname;

					bool isbp=false;
					for(int i=0;i<bprefids.size()&&!isbp;i++){
						isbp=(refid~==bprefids[i]);
					}
					if(isbp){
						array<string> bakitems;
						string baklist=items[i].mid(3);
						baklist.split(bakitems,".");

						for(int bi=0;bi<bakitems.size();bi++){
							string brefid=bakitems[bi].left(3);
							if(brefid!=""){
								int whichindex=refids.find(brefid);
								string thisname;
								if(whichindex>=refids.size())thisname="\ca ? ? ?\cj";
								else thisname=nicenames[whichindex];
								int howmany=max((bakitems[bi].mid(3,bakitems[bi].length())).toint(10),1);
								ttl=ttl.."\n  "..howmany.." x    "..thisname;
							}
						}

						continue;
					}
				}
				if(inbp){
					ttl=ttl..Stringtable.Localize("$LOADOUTMENU_INBACKPACK");
					if(!bpitems.size())ttl=ttl..Stringtable.Localize("$LOADOUTMENU_NOBACKPACK");
					else for(int i=0;i<bpitems.size();i++){
						string refid=bpitems[i].left(3);
						if(refid=="")continue;
						int whichindex=refids.find(refid);
						string thisname;
						if(
							whichindex>=refids.size()
							||nicenames[whichindex]==""
						){
							if(bpitems.size()==1){
								ttl=ttl..Stringtable.Localize("$LOADOUTMENU_NOBACKPACK");
								break;
							}else thisname="\ca ? ? ?\cj";
						}else thisname=nicenames[whichindex];
						int howmany=max((bpitems[i].mid(3,bpitems[i].length())).toint(10),1);
						ttl=ttl.."\n  "..howmany.." x    "..thisname;
					}
				}
			}
		}
		int skiplines=tlcursy;
		while(skiplines>0){
			skiplines--;
			int brk=ttl.indexof("\n");
			if(brk<0){
				tlcursy-=skiplines+1;
				break;
			}else ttl=ttl.mid(brk+1);
		}

		if(isnewgamemenu)return ttl;

		ttl=
			Stringtable.Localize("$LOADOUTMENU_CTRLF")
			..(viewlist?Stringtable.Localize("$LOADOUTMENU_PREVIEW"):Stringtable.Localize("$LOADOUTMENU_REFIDLIST"))
			..Stringtable.Localize("$LOADOUTMENU_PAGEUPDOWN")..ttl;

		if(viewlist)ttl=Stringtable.Localize("$LOADOUTMENU_CODEREFERENCELIST")..ttl;
		       else ttl=Stringtable.Localize("$LOADOUTMENU_LOADOUTPREVIEW")..ttl;

		return ttl;
	}
	int blinktimer;
	int statustimer;
	override void Drawer(){
		Super.Drawer();
		playerinfo cplayer=players[consoleplayer];
		if(!cplayer)return;
		int vcurs=9;

		if(loadoutpic.isvalid()){
			screen.drawtexture(
				loadoutpic,false,300-texman.getsize(loadoutpic),
				smallfont.getheight()*14,
				DTA_Clean,false,DTA_320x200,true,DTA_TopOffset,true,DTA_LeftOffset,true
			);
		}

		string hs=Stringtable.Localize("$LOADOUTMENU_CONFIGURELOADOUT");
		screen.DrawText(BigFont,
			OptionMenuSettings.mTitleColor,
			(screen.GetWidth() - BigFont.StringWidth(hs) * CleanXfac_1) / 2,
			vcurs,
			hs,DTA_CleanNoMove_1,true
		);
		vcurs+=BigFont.GetHeight()+(NewSmallFont.GetHeight()>>1);

		hs=Stringtable.Localize("$LOADOUTMENU_CONTROLS")..(showhelp?Stringtable.Localize("$LOADOUTMENU_HIDE"):Stringtable.Localize("$LOADOUTMENU_VIEW"))..Stringtable.Localize("$LOADOUTMENU_SYNTAXHELP");
		screen.DrawText(NewSmallFont,
			OptionMenuSettings.mFontColor,
			(screen.GetWidth() - NewSmallFont.StringWidth(hs) * CleanXfac_1) / 2,
			vcurs*CleanYfac_1,
			hs,DTA_CleanNoMove_1, true
		);
		vcurs+=NewSmallFont.GetHeight()*2;

		if(showhelp){
			hs=Stringtable.Localize("$LOADOUTMENU_SYNTAX");
			screen.DrawText(NewSmallFont,
				OptionMenuSettings.mFontColor,
				(screen.GetWidth() - NewSmallFont.StringWidth(hs) * CleanXfac_1) / 2,
				vcurs*CleanYfac_1,
				hs,DTA_CleanNoMove_1, true
			);
			vcurs+=NewSmallFont.GetHeight()*7;
		}

		string ws=workingstring;
		int tempcursx=cursx;
		uint maxwidth=(screen.GetWidth()*3/5)/(SmallFont.StringWidth("_")*CleanXfac_1);
		int halfmaxwidth=maxwidth/2;
		int addarrows=0;
		int textstart=0;
		int textend=ws.length();
		if(ws.length()>maxwidth){
			int wsl=ws.length();
			if(
				cursx>=halfmaxwidth
				&&wsl-cursx>=halfmaxwidth
			){
				//enough space on both sides of cursor
				tempcursx=halfmaxwidth;
				ws=ws.mid(cursx-halfmaxwidth,maxwidth);
				addarrows|=1|2;
				textstart=cursx-halfmaxwidth;
				textend=cursx+halfmaxwidth;
			}else if(cursx<halfmaxwidth){
				//beginning
				ws=ws.left(maxwidth);
				addarrows|=2;
				textend=maxwidth;
			}else{
				//end
				ws=ws.mid(ws.length()-maxwidth);
				tempcursx-=workingstring.length()-ws.length();
				addarrows|=1;
				textstart=textend-maxwidth;
			}
		}
		int wsline=vcurs*CleanYfac_1;
		int wswidth=NewSmallFont.StringWidth(ws) * CleanXfac_1;
		int wsxpos=(screen.GetWidth() - wswidth) / 2;
		screen.DrawText(NewSmallFont,
			different?OptionMenuSettings.mFontColorHeader:OptionMenuSettings.mFontColorValue,
			wsxpos,wsline,ws,DTA_CleanNoMove_1,true
		);

		blinktimer++;
		if(blinktimer>3){
			if(blinktimer>6)blinktimer=0;
			screen.DrawText(NewSmallFont,OptionMenuSettings.mFontColorHighlight,
				wsxpos+NewSmallFont.StringWidth(ws.left(tempcursx))*CleanXfac_1,
				wsline,
				"_",DTA_CleanNoMove_1,true
			);
		}
		if(addarrows&&blinktimer>2){
			if(addarrows&1)screen.DrawText(NewSmallFont,
				OptionMenuSettings.mFontColor,
				wsxpos-NewSmallFont.StringWidth("<<  ") * CleanXfac_1,
				wsline,"<<  ",DTA_CleanNoMove_1, true
			);
			if(addarrows&2)screen.DrawText(NewSmallFont,
				OptionMenuSettings.mFontColor,
				wsxpos+wswidth,
				wsline,"  >>",DTA_CleanNoMove_1, true
			);
		}
		vcurs+=NewSmallFont.GetHeight();

		string s=Stringtable.Localize("$LOADOUTMENU_NOWEDITING")..cursy;
		if(loadoutname!="")s=s..", \""..loadoutname.."\"";
		if(statustimer>0){
			statustimer--;
			s=statusstring;
		}
		screen.DrawText(SmallFont,OptionMenuSettings.mTitleColor,
			(screen.GetWidth() - SmallFont.StringWidth(s) * CleanXfac_1) / 2,
			vcurs*CleanYfac_1,
			s,DTA_CleanNoMove_1, true
		);
		vcurs+=SmallFont.GetHeight()*2;

		s=translatedloadout;
		maxtextwidth=max(maxtextwidth,NewSmallFont.StringWidth(s));
		screen.DrawText(NewSmallFont,OptionMenuSettings.mFontColorValue,
			(screen.GetWidth() - maxtextwidth * CleanXfac_1) / 2,
			vcurs*CleanYfac_1,
			s,DTA_CleanNoMove_1, true
		);
	}
	int maxtextwidth;
}




class HDNewGameLoadoutMenu2:HDLoadoutMenu2{
	override void Init(menu parent){
		super.Init(parent);
		isnewgamemenu=true;
		translatedloadout=gettranslatedloadout(workingstring);
		cursx=workingstring.length();
	}
	override string GetTranslatedLoadout(string input){
		string lod=super.GetTranslatedLoadout(input);
		string ws=hdmath.getloadoutstrings(input,true);
		if(loadoutname=="")loadoutname=Stringtable.Localize("$LOADOUTMENU_LOADOUT")..cursy;
		if(!loadoutpic.isvalid()){
			ws.replace(" ","");
			ws=ws.left(3);
			for(int i=0;i<allactorclasses.size();i++){
				let ai=(class<hdpickup>)(allactorclasses[i]);
				let aw=(class<hdweapon>)(allactorclasses[i]);
				if(!ai&&!aw)continue;
				bool match=false;
				if(ai){
					let aai=getdefaultbytype(ai);
					if(ws~==aai.refid){
						match=true;
						loadoutpic=aai.icon;
					}
					if(loadoutpic.isvalid())break;
				}else if(aw){
					let aaw=getdefaultbytype(aw);
					if(ws~==aaw.refid){
						match=true;
						loadoutpic=aaw.icon;
					}
					if(loadoutpic.isvalid())break;
				}
				if(match&&!loadoutpic.isvalid()){
					let gdi=getdefaultbytype(allactorclasses[i]);
					let dds=gdi.spawnstate;
					if(dds!=null)loadoutpic=dds.GetSpriteTexture(0);
				}
				if(loadoutpic.isvalid())break;
			}
			if(!loadoutpic.isvalid())loadoutpic=texman.checkfortexture("AMMOA0",texman.type_sprite);
		}
		return lod;
	}
	override bool MenuEvent(int mkey, bool fromcontroller){
		switch(mkey){
		case MKEY_Up:
			cursy--;
			if(cursy<1)cursy=HD_MAXLOADOUTS;
			statustimer=0;
			MenuSound("menu/cursor");
			resetws();
			return true;
		case MKEY_Down:
			cursy++;
			if(cursy>HD_MAXLOADOUTS)cursy=1;
			statustimer=0;
			MenuSound("menu/cursor");
			resetws();
			return true;
		case MKEY_Enter:
			MenuSound("menu/choose");
			cvar.findcvar("playerclass").setstring("Loadout "..cursy);
			Menu.SetMenu("PlayerclassMenu");
			return true;
		case MKEY_PageUp:
			tlcursy=max(0,tlcursy-1);
			break;
		case MKEY_PageDown:
			tlcursy++;
			break;
		case MKEY_Back:
			MenuSound("menu/clear");
			resetws();
			close();
			break;
		}
		translatedloadout=gettranslatedloadout(workingstring);
		return super.menuevent(mkey,fromcontroller);
	}
	override bool OnUIEvent(UIEvent ev){
		if(ev.Type==UIEvent.Type_KeyDown){
			switch(ev.KeyChar){
			case UIEvent.Key_Home:
				cursx=0;
				return true;
			case UIEvent.Key_End:
				cursx=workingstring.length();
				return true;
			case UIEvent.Key_F10:
				MenuSound("menu/clear");
				resetws();
				close();
				return true;
			default:
				string inp="";
				inp.appendformat("%c",ev.KeyChar);
				if(inp~=="r"){
					cursy=random(1,HD_MAXLOADOUTS);
					MenuSound("menu/choose");
					if(ev.IsCtrl){
						if(ev.IsShift)cvar.findcvar("playerclass").setstring("Loadout "..cursy);
						else cvar.findcvar("playerclass").setstring("Random");
						Menu.SetMenu("PlayerclassMenu");
					}else{
						resetws();
					}
					return true;
				}
				int inpt=inp.toint(16);
				if(inp~=="g")inpt=16;
				else if(inp~=="h")inpt=17;
				else if(inp~=="i")inpt=18;
				else if(inp~=="j")inpt=19;
				else if(inp~=="k")inpt=20;
				else if(inp~=="0")inpt=1;
				if(inpt>0&&inpt<=HD_MAXLOADOUTS){
					cursy=inpt;
					resetws();
					return true;
				}
				return true;
			}
			translatedloadout=gettranslatedloadout(workingstring);
		}
		return false;
	}
	override void Drawer(){
		Genericmenu.Drawer();
		playerinfo cplayer=players[consoleplayer];
		if(!cplayer)return;
		int vcurs=0;

		string hs=Stringtable.Localize("$MENU_NEWGAME");
		screen.DrawText(BigFont,OptionMenuSettings.mTitleColor,
			0,
			vcurs,
			hs,
			DTA_Clean,true
		);
		vcurs+=BigFont.GetHeight()+2;

		hs=Stringtable.Localize("$MENU_NEWGAME_CONTROLS");
		screen.DrawText(SmallFont,
			OptionMenuSettings.mFontColor,
			160-SmallFont.StringWidth(hs)/2,
			BigFont.GetHeight()+2,
			hs,
			DTA_Clean,true
		);
		vcurs+=SmallFont.GetHeight()*3+35;

		if(loadoutpic.isvalid()){
			int picsx,picsy;
			[picsx,picsy]=texman.getsize(loadoutpic);
			screen.drawtexture(
				loadoutpic,false,160-(picsx>>1),
				vcurs-picsy,
				DTA_Clean,true,DTA_VirtualWidth,320,DTA_VirtualHeight,200,
				DTA_TopOffset,true,
				DTA_LeftOffset,true
			);
		}

		screen.DrawText(BigFont,OptionMenuSettings.mFontColorHighlight,
			(320-BigFont.StringWidth(loadoutname))/2,
			vcurs,
			loadoutname,DTA_Clean,true
		);
		vcurs+=BigFont.GetHeight();

		string ws=loadoutdisplaystring;
		while(ws.byteat(0)==" ")ws=ws.mid(1);

		if(ws=="")ws=Stringtable.Localize("$MENU_WEAPONSTRING_NOTHING");

		int tempcursx=cursx;
		uint maxwidth=(screen.GetWidth()*3/5)/(SmallFont.StringWidth("_")*CleanXfac_1);
		int halfmaxwidth=(maxwidth>>1);
		int addarrows=0;
		int textstart=0;
		int textend=ws.length();
		if(ws.length()>maxwidth){
			int wsl=ws.length();
			if(cursx<halfmaxwidth)cursx=halfmaxwidth;
			else cursx=min(cursx,wsl-halfmaxwidth);
			if(
				cursx>halfmaxwidth
				&&wsl-cursx>halfmaxwidth
			){
				//enough space on both sides of cursor
				tempcursx=halfmaxwidth;
				ws=ws.mid(cursx-halfmaxwidth,maxwidth);
				addarrows|=1|2;
				textstart=cursx-halfmaxwidth;
				textend=cursx+halfmaxwidth;
			}else if(cursx<=halfmaxwidth){
				//beginning
				ws=ws.left(maxwidth);
				addarrows|=2;
				textend=maxwidth;
			}else{
				//end
				ws=ws.mid(ws.length()-maxwidth);
				tempcursx-=workingstring.length()-ws.length();
				addarrows|=1;
				textstart=textend-maxwidth;
			}
		}
		int wsline=vcurs;
		int wswidth=SmallFont.StringWidth(ws);
		int wsxpos=(320-wswidth)/2;

		screen.DrawText(SmallFont,
			different?OptionMenuSettings.mFontColorHeader:OptionMenuSettings.mFontColorValue,
			wsxpos,vcurs,"\cp"..ws,DTA_Clean,true
		);

		blinktimer++;
		if(addarrows&&blinktimer>2){
			if(addarrows&1)screen.DrawText(SmallFont,
				OptionMenuSettings.mFontColor,
				wsxpos-SmallFont.StringWidth("<<  ") * CleanXfac_1,
				wsline,"<<  ",DTA_Clean,true
			);
			if(addarrows&2)screen.DrawText(SmallFont,
				OptionMenuSettings.mFontColor,
				wsxpos+wswidth,
				wsline,"  >>",DTA_Clean,true
			);
		}
		vcurs+=SmallFont.GetHeight();

		string s=Stringtable.Localize("$LOADOUTMENU_LOADOUTNO")..cursy;
		screen.DrawText(SmallFont,OptionMenuSettings.mTitleColor,
			(screen.GetWidth() - SmallFont.StringWidth(s) * CleanXfac_1) / 2,
			vcurs,
			s,DTA_Clean,true
		);
		vcurs+=SmallFont.GetHeight();

		s=translatedloadout;
		screen.DrawText(SmallFont,OptionMenuSettings.mFontColorValue,
			(320-SmallFont.StringWidth(s))/2,
			vcurs,
			s,DTA_Clean,true
		);
	}
}
