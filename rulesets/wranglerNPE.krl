// operators are camel case, variables are snake case.
    
ruleset wrangler {
  meta {
    name "Wrangler Core"
    description <<
      Wrangler Core Module,
      use example, use module v1_wrangler alias wrangler .
      This Ruleset/Module provides a developer interface to the PICO (persistent computer object).
      When a PICO is created or authenticated this ruleset will be installed to provide essential
      services.
    >>
    author "BYU Pico Lab"

    //use module b16x42 alias system_credentials
    //use module b507901x3 alias pds
    // errors raised to.... unknown
    use module prototypes
    logging on
    provides skyQuery, rulesets, rulesetsInfo, installRulesets, uninstallRulesets, //ruleset
    channel, channelAttributes, channelPolicy, channelType, //channel
    children, parent, attributes, prototypes, name, profile, pico, checkPicoName, randomPicoName, createChild, deleteChild, pico, 
    eciFromName, subscriptionAttributes,checkSubscriptionName, //subscription
    standardError, decodeDefaults
    shares skyQuery, rulesets, rulesetsInfo, installRulesets, uninstallRulesets, //ruleset
    channel, channelAttributes, channelPolicy, channelType, //channel
    children, parent, attributes, prototypes, name, profile, pico, checkPicoName, randomPicoName, createChild, deleteChild, pico, 
    eciFromName, subscriptionAttributes,checkSubscriptionName, //subscription
    standardError, decodeDefaults
  }
  global {
// ********************************************************************************************
// ***                                                                                      ***
// ***                                      FUNCTIONS                                       ***
// ***                                                                                      ***
// ******************************************************************************************** 
    getPrototypes = function(){
      prototypes:prototypes()
    }
    hasChild = function(child){
      temp = children().union(child);
      temp.length() == children().length()
    }
// ********************************************************************************************
// ***                                      Rulesets                                        ***
// ********************************************************************************************
/*    rulesets = function() { // needss.
      eci = meta:eci;
      results = //http:get(web_hook.klog("URL"), {}.put(params)).klog("response ");
      results = //pci:list_ruleset(eci); 
      rids = results{"rids"}.defaultsTo("error",standardError("no hash key rids"));
      {
       "status"   : (rids !=  "error"),
        "rids"     : rids
      }.klog("rulesets :")
    }
    rulesetsInfo = function(rids) {//takes an array of rids as parameter // can we write this better???????
      //check if its an array vs string, to make this more robust.
      rids_string = ( rids.typeof() == "array" ) => rids.join(";") | ( rids.typeof() == "str" ) => rids | "" ;
      describe_url = "https://#{meta:host}/ruleset/describe/#{$rids_string}";
      resp = http:get(describe_url);
      results = resp{"content"}.decode().defaultsTo("",standardError("content failed to return"));
      {
       "status"   : (resp{"status_code"} ==  "200"),
       "description"     : results
      }.klog("rulesetsInfo :")
    }
*/
    // installRulesets defaction will need a "with eci" for external picos eci 
//    installRulesets = defaction(rids, _eci, name){
//      //configure using eci = meta:eci and name = "none"
//      eci =  "cj2mlhueu0000m8ny9n2qbmpd" //_eci || ent:id ||  //meta:eci
//      name =  name || "none"
//      pico_eci = (name == "none") => eci | picoECIFromName(name) /* this will need to be pico_id and not eci */
//      //new_ruleset = engine:installRuleset( { "pico_id": eci.klog("pico_id: "), "rid": rids.klog("rids: ") } ).klog("new_bananas") 
//      new_ruleset = engine:installRuleset( ent:id ) setting(resp) with base = <base> and url = <url>
//      send_directive("installed #{rids}")
//    }

    installRulesets = defaction(rids){
      new_ruleset = engine:installRuleset(ent:id, rids)
      send_directive("installed #{rids}")
    }

//    uninstallRulesets = defaction(rids, _eci, name){
//      //configure using eci = meta:eci and name="none"
//      eci = _eci || ent:id  //meta:eci
//      name = (name.typeof() == "String") => name | "none"
//      pico_eci = /* this will need to be pico_id and not eci */ (name== "none") => eci | picoECIFromName(name)
//      //deleted = /* not implemented */ engine:uninstallRuleset( { "pico_id": eci, "rid": rids } )
//      deleted = engine:uninstallRuleset( { "pico_id": eci, "rid": rids } )
//      send_directive("uninstalled #{rids} in pico #{pico_eci}")
//    }

    uninstallRulesets = defaction(rids){
      deleted = engine:uninstallRuleset(ent:id, rids)
      send_directive("uninstalled #{rids} in pico #{ent:id}")
    }

// ********************************************************************************************
// ***                                      Channels                                        ***
// ******************************************************************************************** 
    nameFromEci = function(eci){ // internal function call
      results = channel(eci);
      channel_single = results{"channels"};
      channel_single{"name"}
    } 
    eciFromName = function(name){
      results = channel(name);
      channel_single = results{"channels"};
      channel_single{"eci"}
    }
    alwaysEci = function(value){   // always return a eci wether given a eci or name
      eci = (value.match(re#(^(([A-Z]|\d)+-)+([A-Z]|\d)+$)#)) => 
              value |
              eciFromName(value);
      eci       
    }
    lastCreatedEci = function(){
      channel = ent:lastCreatedEci;
      eci = channel{"cid"};
      eci
    }
    // takes name or eci as id returns single channel . needed for backwards compatability 
    channel = function(id,collection,filtered) { 
      eci = meta:eci;
      chans = ent:channels;
      channels = chans;
      /*channels = chans.map(function(channel){ // reconstruct each channel to have eci not eci
                                            {
                                              "last_active":channel{"last_active"},
                                              "policy":channel{"policy"},
                                              "name":channel{"name"},
                                              "type":channel{"type"},
                                              "eci":channel{"eci"},
                                              "attributes":channel{"attributes"}
                                              } });*/
      single_channel = function(value,chans){
         // if value is a number with ((([A-Z]|\d)*-)+([A-Z]|\d)*) attribute is eci.
        attribute = (value.match(re#(^(([A-Z]|\d)+-)+([A-Z]|\d)+$)#)) => 
                "eci" |
                "name";
        channel_list = chans;
        filtered_channels = channel_list.filter(function(channel){(channel{attribute}== value)}); 
        result = filtered_channels.head().defaultsTo({},standardError("no channel found, by .head()"));
        (result)
      };
      type = function(chan){ // takes a chans 
        group = (chan.typeof() ==  "Map")=> // for robustness check type.
        chan{collection} | "error";
        (group)
      };
      return1 = collection.isnull() => channels |  channels.collect(function(chan){(type(chan))}) ;
      return2 = filtered.isnull() => return1 | return1{filtered};
      results = (id.isnull()) => return2 | single_channel(id,channels);
      {
        "status"   : (channels !=  "error"),
        "channels" : results
      }.klog("channels: ")
    }
    channelAttributes = function(eci,name) {
      Eci = eci.defaultsTo(alwaysEci(name).defaultsTo("","no name or eci provided"),"no eci going with name") ;
      results = pci:get_eci_attributes(Eci
        ).defaultsTo("error",standardError("get_eci_attributes")); // list of ECIs assigned to userid
      {
        "status"   : (results !=  "error"),
        "attributes" : results
      }.klog("attributes")
    }
    channelPolicy = function(eci,name) {
      Eci = eci.defaultsTo(alwaysEci(name).defaultsTo("","no name or eci provided"),"no eci going with name") ;
      results = {}; //pci:get_eci_policy(Eci).defaultsTo("error",standardError("undefined")); // list of ECIs assigned to userid
      {
        "status"   : (results !=  "error"),
        "policy" : results
      }.klog("policy")
    }
    channelType = function(eci,name) { // old accounts may have different structure as there types, "type : types"
      Eci = eci.defaultsTo(alwaysEci(name).defaultsTo("","no name or eci provided"),"no eci going with name") ;
      getType = function(eci) { 
        type = pci:get_eci_type(eci).defaultsTo("error",standardError("undefined"));
        // this code below belongs higher up in software layer
        // temp = (type.typeof() ==  "str" ) => type | type.typeof() ==  "array" => type[0] |  type.keys();
        // type2 = (temp.typeof() ==  "array") => temp[0] | temp;   
        // type2;
        type
      };
      type = getType(Eci);
      {
        "status":(type !=  "error"),
        "type" : type
      }.klog("type")
    }
    updateAttributes = defaction(value, attributes){
      eci = alwaysEci(value)
      set_eci = {}//pci:set_eci_attributes(eci, attributes)
      send_directive("updated channel attributes for #{eci}")
    }
    updatePolicy = defaction(value, policy){
      eci = alwaysEci(value)
      set_polcy = {}//pci:set_eci_policy(eci, policy) // policy needs to be a map, do we need to cast types?
      send_directive("updated channel policy for #{eci}")
    }
    updateType = defaction(value, type){
      eci = alwaysEci(value)
      set_type = {}//pci:set_eci_type(eci, type)
      send_directive("updated channel type for #{eci}")
    }
    
//    deleteChannel = defaction(value) {
//      //eci = alwaysEci(value)
//      self = myself()
//      deleteeci = engine:removeChannel({
//        "pico_id": self{"id"},
//        "eci": eci.klog("eci to be removed")
//      })
//      send_directive("deleted channel #{eci}")
//    }
    
    deleteChannel = defaction(eci) {
      deleteeci = engine:removeChannel(eci)
      send_directive("deleted channel #{eci}")
    }

    /*options = {
        "name" : channel_name,
        "eci_type" : type,
        "attributes" : {"channel_attributes" : attrs},
        "policy" : decoded_policy//{"policy" : policy}
      }*/

    createChannel = function(options, _id){
      id = _id || ent:id;
      //channel = engine:newChannel({ "name":options.name, "type": options.eci_type, "pico_id": id });
      channel = engine:newChannel(id, options.name, options.eci_type);
      channel_rec = {"name": channel.name,
                    "eci": channel.id,
                    "type": channel.type,
                    "attributes": options.attributes 
                    }.klog("new channel");
      all_channels = ent:channels => ent:channels | []; // [] if first channel
      updated_channel = all_channels.append(channel_rec).klog("new channel list: ");
      {
       "status": channel.isnull(),
       "channel": channel,
       "updated_channels": updated_channel
      }
      //send_directive("created channel #{new_eci}")
    }
// ********************************************************************************************
// ***                                      Picos                                           ***
// ******************************************************************************************** 
  myself = function(){
      { "id": ent:id, "eci": ent:eci, "name": ent:name }
  }

  children = function() {
    _children = ent:children.defaultsTo([]);
    status = (not(_children.isnull()));
    {
      "status" : status,
      "children" : _children
    }.klog("children :")
  }

  parent = function() {
    _parent = ent:parent.defaultsTo({});
    status = not _parent.isnull();
    {
      "status" : status,
      "parent" :  _parent 
    }.klog("parent :")
  }

  profile = function(key) {
    /*PDS not implemented */ //pds:profile(key)
    {}
  }
  pico = function() {
    profile_return = {};/*PDS not implemented */ //pds:profile();
    settings_return = {};/*PDS not implemented */ //pds:settings();
    general_return = {};/*PDS not implemented */ //pds:items();
    {
      "profile" : profile_return{"profile"},
      "settings" : settings_return{"settings"},
      "general" : general_return{"general"}
    }.klog("pico :")
  }

  name = function() {
    return = ent:name;
    {
      "status" : not return.isnull(),
      "picoName" : return
    }.klog("name :")
  }
  picoECIFromName = function (name) {
    pico = ent:children.filter(function(rec){rec{"name"} ==  name})
                          .head();
    pico{"eci"}
  }
  deleteChild = function(name) {
    results = children();
    ent_children = results{"children"};
    child_rec = ent_children.filter(function(rec){rec{"name"} ==  name})
                               .head().defaultsTo({});
    child_id= child_rec{"id"};
    new_child_list = ent_children
                               .filter(function(rec){rec{"name"} !=  name});
    noret = engine:removePico(child_id);
    //send_directive("deleted pico #{eci_to_delete}")
    {
     "status": not noret.isnull(),
     "child": child_id,
     "updated_children": new_child_list 
    }
  }
  
    newPico = function(name){
      child = engine:newPico();
      child_id = child.id;
      //channel = engine:newChannel({ "name": "main", "type": "secret", "pico_id": child_id });
      channel = engine:newChannel(child_id, "main", "secret");
      child_eci = channel.id;
      newPicoInfo = { "id": child_id, "eci": child_eci };
      // create child object
      child_rec = {"name": name,
                   "id" : newPicoInfo.id,
                   "eci": newPicoInfo.eci,
                   "status": "pending_initialization"
                  };
      children = ent:children => ent:children | []; // [] if first child
      updated_children = children.append(child_rec)
                     .klog("New Child List: ");
      { 
        "status" : child_rec.isnull(),
        "child"  : child_rec,
        "updated_children" : updated_children
      }
    }

    updateChildCompletion = function(name){
      children_map = ent:children.collect(function(child){
                                            (child.name == name) => "childToUpdate" | "otherChildren"
                                          });//separate the children, returns two arrays
      updated_child = children_map.childToUpdate.head().put(["status"], "initialized");//update the status
      updated_children = children_map.otherChildren.append(updated_child);//reunite with the other children
      updated_children
    }

// at creation wrangler will create child and send protype to child and 
// then wrangle in the child will handle the creation of the pico and its prototypes
// create child from protype will take the name with a option of a prototype that defaults to base.

  outfitChild = defaction(parent,child,prototype_name){ 
    //configure using prototype_name = "base" // base must be installed by default for prototypeing to work 
    results = getPrototypes() // get prototype from ent varible and default to base if not found.
    prototypes = results{"prototypes"}
    prototype = prototypes{prototype_name.defaultsTo("base","using base")}.defaultsTo(basePrototype,"prototype not found").klog("prototype: ")
    rids = prototype{"rids"}
    attributes = {
      "child": child,
      "parent": parent,
      "prototype": prototype.encode()
    }
    //install a combination of prototypes ruleset in child 
    joined_rids_to_install = prototype_name ==  "base" =>  basePrototype{"rids"}  |   basePrototype{"rids"}.append(rids)
    //a = engine:installRuleset({"pico_id": child{"id"}.klog("child_id_Potter_Head"), "rid": joined_rids_to_install.klog("rids to be installed in child: ")}) 
    engine:installRuleset(child.id.klog("child_id_Potter_Head"), joined_rids_to_install.klog("rids to be installed in child: ")) setting(a)
    // update child ent:prototype_at_creation with prototype
    event:send({"eci": child.eci.klog("Potter_Head2"), "eid": "ProtoOutfit",
          "domain": "wrangler", "type": "create_prototype",
          "attrs": attributes})
  }
   /* randomName = function(namespace){
        n = 5;
        array = (0).range(n).map(function(n){
          (random:word());
          });
        names= array.collect(function(name){
          (checkName( namespace +":"+ name )) => "unique" | "taken";
        });
        name = names{"unique"} || [];

        unique_name =  name.head().defaultsTo("",standardError("unique name failed"));
        (namespace +":"+ unique_name);
    }*/
    // optimize by taking a list of names, to prevent multiple network calls to channels when checking for unique name
    checkName = function(name){
          chan = channel(name, null, null);
          //channels = channels(); worse bug ever!!!!!!!!!!!!!!!!!!!!!!!!!!!
          /*{
          "last_active": 1426286486,
          "name": "Oauth Developer ECI",
          "type": "OAUTH",
          "eci": "158E6E0C-C9D2-11E4-A556-4DDC87B7806A",
          "attributes": null}
          */
          chs = chan{"channels"}.defaultsTo({},standardOut("no channel found"));
          encoded_chan = chs.encode().klog("encode chs :");
          return = encoded_chan.match(re#{}#);
          (return)
    }

    randomPicoName = function(){
        n = 5;
        array = (0).range(n).map(function(n){
          (random:word())
          });
        names= array.collect(function(name){
          (checkPicoName( name )) => "unique" | "taken"
        });
        name = names{"unique"} || [];

        unique_name =  name.head().defaultsTo("",standardError("unique name failed"));
        (unique_name).klog("randomPicoName : ")
    }

    checkPicoName = function(name){
          return = children();
          picos = return{"children"};
          /*
          {"name":"closet","eci":"2C8457C0-76BF-11E6-B407-9BD5E71C24EA"}
           */
          names = picos.none(function(child){
            pico_name = child{"name"};
            (pico_name ==  name)
            });
          (names).klog("checkPicoName : ")

    }      
 

// ********************************************************************************************
// ***                                      Utilities                                       ***
// ******************************************************************************************** 
  //-------------------- error handling ----------------------
    standardOut = function(message) {
      msg = ">> " + message + " results: >>";
      msg
    }

    standardError = function(message) {
      error = ">> error: " + message + " >>";
      error
    }
    decodeDefaults = function(value) {
      //decoded_value = value.decode().klog("decoded_value: ");
      //error = decoded_value{"error"};
      //return = (error.typeof() ==  "array") =>  error[0].defaultsTo(decoded_value,"decoded: ") | decoded_value;
      //return.klog("return: ")
      value
    }
  }
  // string or array return array 
  // string or array return string

// ********************************************************************************************
// ***                                                                                      ***
// ***                                      Rulesets                                        ***
// ***                                                                                      ***
// ********************************************************************************************
  
  rule installRulesets {
    select when wrangler install_rulesets_requested
    pre { 
      rids = event:attr("rids").defaultsTo("",standardError(" "))
      rid_list = rids.typeof() ==  "array" => rids | rids.split(re#;#)
      b = rid_list.klog("attr Rids") 
    }
    if(rids !=  "") then  // should we be valid checking?
      installRulesets(rid_list)
    fired {
     rids.klog(standardOut("success installed rids "));
     null.klog(">> successfully  >>")
          } 
    else {
     null.klog(">> could not install rids #{rids} >>")
    }
  }
  rule uninstallRulesets { // should this handle multiple uninstalls ??? 
    select when wrangler uninstall_rulesets_requested
    pre {
      rids = event:attr("rids").defaultsTo("", ">>  >> ")
      rid_list = rids.typeof() ==  "array" => rids | rids.split(re#;#)
    }
    
      uninstallRulesets(rid_list)
   
    fired {
      null.klog (standardOut("success uninstalled rids #{rids}"));
      null.klog(">> successfully  >>")
          } 
    else {
      null.klog(">> could not uninstall rids #{rids} >>")
    }
  }
 
// ********************************************************************************************
// ***                                      Channels                                        ***
// ********************************************************************************************
  /*  <eci options>
    name     : <string>        // default is "Generic ECI channel" 
    eci_type : <string>        // default is "PCI"
    attributes: <array>
    policy: <map>  */

  rule createChannel {
    select when wrangler channel_creation_requested
    pre {
      event_attributes = event:attrs()
      // eci = event:attr("eci").defaultsTo(meta:eci.klog("meta eci), standardError("no eci provided")) // should never default 
      channel_name = event:attr("channel_name").defaultsTo("", standardError("missing event attr channels"))
      type = event:attr("channel_type").defaultsTo("Unknown", standardError("missing event attr channel_type"))
      attributes = event:attr("attributes").defaultsTo("", standardError("missing event attr attributes"))

      attrs =  decodeDefaults(attributes)
      // policy = event:attr("policy").defaultsTo("", standardError("missing event attr attributes"))
      // do we need to check if we need to decode ?? what would we check?
      // decoded_policy = policy.decode() || policy //what does .decode() return on failure??
      options = {
        "name" : channel_name,
        "eci_type" : type,
        "attributes" : {"channel_attributes" : attrs}
        //,"policy" : decoded_policy//{"policy" : policy}
      }.klog("options for channel cration");
      check_name = checkName(channel_name);
      channel_results = check_name => createChannel(options) | {}
     }
          // do we need to check the format of name? is it wrangler"s job?
    if(check_name) then  //channel_name.match(re#\w[\w-]*#)) then 
         
      noop()
         
    fired {
     ent:channels := channel_results.updated_channels;
     ent:lastCreatedEci := channel_results.channel;
     channel_name.klog(standardOut("success created channels "));
     null.klog(">> successfully  >>");
      raise wrangler event "channel_created" // event to nothing  
            attributes event_attributes.put(["eci"],lastCreatedEci().klog("lastCreatedEci: ")) // function to access a magic varible set during creation
          } 
    else {
      //error warn "douplicate name, failed to create channel"+channel_name;
     null.klog(">> could not create channels #{channel_name} >>")
          }
    }

 // we should add a append / modifie channel attributes rule set.
 //  takes in new and modified values and puts them in.
  rule updateChannelAttributes {
    select when wrangler update_channel_attributes_requested
    pre {
      value = event:attr("eci").defaultsTo(event:attr("name").defaultsTo("", standardError("missing event attr eci or name")), standardError("looking for name instead of eci."))
      attributes = event:attr("attributes").defaultsTo("error", standardError("undefined"))
      //attrs = attributes.split(re#;/)
      attrs =  decodeDefaults(attributes)
      attrs_two = {"channel_attributes" : attrs}
      //channels = Channel();
    }
    if(value !=  "" && attributes !=  "error") then  // check?? redundant????
      updateAttributes(value.klog("value: "),attrs_two)
    
    fired {
     value.klog (standardOut("success updated channel #{value} attributes : "));
     null.klog(">> successfully >>")
    } 
    else {
     null.klog(">> could not update channel #{value} attributes >>")
    }
  }

  rule updateChannelPolicy {
    select when wrangler update_channel_policy_requested // channel_policy_update_requested
    pre {
      value = event:attr("eci").defaultsTo(event:attr("name").defaultsTo("", standardError("missing event attr eci &| name")), standardError("looking for name instead of eci."))
      policy_string = event:attr("policy").defaultsTo("error", standardError("undefined"))// policy needs to be a map, do we need to cast types?
      policy = decodeDefaults(policy_string)
    }
    if(value !=  "" && policy !=  "error") then  // check?? redundant?? whats better??
      updatePolicy(value.klog("value: "), policy)
    
    fired {
     null.klog (standardOut("success updated channel #{value} policy"));
     null.klog(">> successfully  >>")
    }
    else {
     null.klog(">> could not update channel #{value} policy >>")
    }

  }


  rule updateChannelType {
    select when wrangler update_channel_type_requested 
    pre {
      value = event:attr("eci").defaultsTo(event:attr("name").defaultsTo("", standardError("missing event attr eci or name")), standardError("looking for name instead of eci."))
      type = event:attr("channel_type").defaultsTo("error", standardError("undefined"))// policy needs to be a map, do we need to cast types?
    }
    if(eci !=  "" && type !=  "error") then  // check?? redundant?? whats better??
      updateType(value.klog("value: "), type)
    
    fired {
     null.klog (standardOut("success updated channel #{eci} type"));
     null.klog(">> successfully  >>")
    }
    else {
     null.klog(">> could not update channel #{eci} type >>")
    }

  }

  rule deleteChannel {
    select when wrangler channel_deletion_requested
    pre {
      value = event:attr("eci").defaultsTo(event:attr("name").defaultsTo("", standardError("missing event attr eci or name")), standardError("looking for name instead of eci."))
    }
    
      deleteChannel(value.klog("value: "))
    
    fired {
     value.klog (standardOut("success deleted channel "));
     null.klog(">> successfully  >>");
    } 
   // else { -------------------------------------------// can we reach this point?
    // null.klog(">> could not delete channel #{value} >>");
   //    }
  }
  

  
// ********************************************************************************************
// ***                                      Picos                                           ***
// ********************************************************************************************
  //-------------------- Picos initializing  ----------------------
  rule createChild { 
    select when wrangler child_creation
    pre {
      name = event:attr("name");//.defaultsTo(randomPicoName(),standardError("missing event attr name, random word used instead."));    
      prototype = event:attr("prototype").defaultsTo("base", "using base prototype");
      check = checkPicoName(name).klog("checkName ");   
      children = check => newPico(name)| {} ; // this breaks best practice  

      //send this info back to whatever ruleset raised it
      attrs = event:attrs().put(["updated_info"], children);
      return_rid = event:attr("return_rid") || "";//what ruleset to send the new pico's info back to
    }
    if(check) then 
      outfitChild(myself(),children{"child"}, prototype)
    fired {
      ent:children := children{"updated_children"};
      raise information event "child_created" //for return_rid
          attributes attrs;
      name.klog("Pico created with name: ");
    }
    else{
      name.klog(" duplicate Pico name, failed to create pico named ");
    }
  }

  rule childComplete{
    select when wrangler child_completed
    pre{
      updated_children = updateChildCompletion(event:attrs("name")).klog("Status updated children: ");
    }
    noop()
    fired{
      ent:children := updated_children;
    }
  }
   
  rule initializePrototype { 
    select when wrangler create_prototype //raised from parent in new child
    pre {
      child = event:attr("child");
      parent = event:attr("parent").klog("parent: ");
    }
    
      noop()
    
    
    always {
      null.klog("inited prototype");
      ent:name := child.name;
      ent:id := child.id;
      ent:eci := child.eci;
      ent:parent := parent;
      raise wrangler event "setup_prototypes"
            attributes event:attrs();
      raise wrangler event "init_events"
            attributes {};
    }
  }

// ********************************************************************************************
// ***                                   Base Custom Events                                 ***
// ********************************************************************************************


  rule raiseBaseEvents {
    select when wrangler pds_inited
    foreach basePrototype{["Prototype_events"]} setting (Prototype_event)
    pre {
      Prototype_domain = Prototype_event{"domain"};
      Prototype_type = Prototype_event{"type"};
      Prototype_attrs = Prototype_event{"attrs"};
    }
    
      event:send({"cid":meta:eci}, Prototype_domain, Prototype_type)
        with attrs = Prototype_attrs
    
    always {
     null.klog ("raise a prototype event with event send.");
    }
  }

  rule deleteChild {
    select when wrangler child_deletion
    pre {
      pico_name = event:attr("pico_name").defaultsTo("", standardError("missing pico name for deletion"));
      results = deleteChild(pico_name)
    }
    if(pico_name !=  "") then
    noop()
    fired{
     ent:children := results.updated_children;
     results.child.klog("successfully removed child, ")
    }
    else {
     null.klog ("deletion failed because no child was specified");
    }
  }
}
