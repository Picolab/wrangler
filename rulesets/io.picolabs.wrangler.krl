// operators are camel case, variables are snake case.

ruleset io.picolabs.wrangler {
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

    logging on
    provides skyQuery ,
    rulesets, rulesetsInfo, installRulesets, uninstallRulesets, //ruleset
    channel, channelAttributes, channelPolicy, channelType, //channel
    children, parent_eci, attributes, prototypes, name, profile, pico, uniquePicoName, randomPicoName, createChild, deleteChild, pico, myself,
    eciFromName, subscriptionAttributes,checkSubscriptionName, //subscription
    standardError, decodeDefaults
    shares skyQuery ,
    rulesets, rulesetsInfo, installRulesets, uninstallRulesets, //ruleset
    channel, channelAttributes, channelPolicy, channelType, //channel
    children, parent_eci, attributes, prototypes, name, profile, pico, uniquePicoName, randomPicoName, createChild, deleteChild, pico,
    eciFromName, subscriptionAttributes,checkSubscriptionName, //subscription
    standardError, decodeDefaults, __testing
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "wrangler", "type": "child_creation",
                                "attrs": [ "name", "prototype" ] },
                              { "domain": "wrangler", "type": "child_deletion",
                                "attrs": [ "pico_name" ] },
                              { "domain": "wrangler", "type": "channel_creation_requested",
                                "attrs": [ "channel_name", "channel_type" ] },
                              { "domain": "wrangler", "type": "channel_deletion_requested",
                                "attrs": [ "eci" ] },
                              { "domain": "wrangler", "type": "install_rulesets_requested",
                                "attrs": [ "rids" ] },
                              { "domain": "wrangler", "type": "deletion_requested",
                                "attrs": [ ] } ] }
// ********************************************************************************************
// ***                                                                                      ***
// ***                                      FUNCTIONS                                       ***
// ***                                                                                      ***
// ********************************************************************************************

  config= {"os_rids": ["io.picolabs.pds","io.picolabs.wrangler","io.picolabs.visual_params"]}
  /*
       skyQuery is used to programmatically call function inside of other picos from inside a rule.
       parameters;
          eci - The eci of the pico which contains the function to be called
          mod - The ruleset ID or alias of the module
          func - The name of the function in the module
          params - The parameters to be passed to function being called
          optional parameters
          _host - The host of the pico engine being queried.
                  Note this must include protocol (http:// or https://) being used and port number if not 80.
                  For example "http://localhost:8080", which also is the default.
          _path - The sub path of the url which does not include mod or func.
                  For example "/sky/cloud/", which also is the default.
          _root_url - The entire url except eci, mod , func.
                  For example, dependent on _host and _path is
                  "http://localhost:8080/sky/cloud/", which also is the default.
       skyQuery on success (if status code of request is 200) returns results of the called function.
       skyQuery on failure (if status code of request is not 200) returns a Map of error information which contains;
               error - general error message.
               httpStatus - status code returned from http get command.
               skyQueryError - The value of the "error key", if it exist, of the function results.
               skyQueryErrorMsg - The value of the "error_str", if it exist, of the function results.
               skyQueryReturnValue - The function call results.
     */
     skyQuery = function(eci, mod, func, params,_host,_path,_root_url) { // path must start with "/"", _host must include protocol(http:// or https://)
       //.../sky/cloud/<eci>/<rid>/<name>?name0=value0&...&namen=valuen
       createRootUrl = function (_host,_path){
         host = _host || meta:host;
         path = _path || "/sky/cloud/";
         root_url = host+path;
         root_url
       };
       root_url = _root_url || createRootUrl(_host,_path);
       web_hook = root_url + eci + "/"+mod+"/" + func;

       response = http:get(web_hook.klog("URL"), {}.put(params)).klog("response ");
       status = response{"status_code"};// pass along the status
       error_info = {
         "error": "sky query request was unsuccesful.",
         "httpStatus": {
             "code": status,
             "message": response{"status_line"}
         }
       };
       // clean up http return
       response_content = response{"content"}.decode();
       response_error = (response_content.typeof() == "Map" && (not response_content{"error"}.isnull())) => response_content{"error"} | 0;
       response_error_str = (response_content.typeof() == "Map" && (not response_content{"error_str"}.isnull())) => response_content{"error_str"} | 0;
       error = error_info.put({"skyQueryError": response_error,
                               "skyQueryErrorMsg": response_error_str,
                               "skyQueryReturnValue": response_content});
       is_bad_response = (response_content.isnull() || (response_content == "null") || response_error || response_error_str);
       // if HTTP status was OK & the response was not null and there were no errors...
       (status == 200 && not is_bad_response ) => response_content | error
     }

    //returns a list of children that are contained in a given subtree at the starting child. No ordering is guaranteed in the result
    gatherSubtree = function(child){
      pico_array = [child.klog("child at start: ")];
      moreChildren = common:skyQuery(child{"eci"}, "wrangler", "children").children.klog("Sky query result: ");
      final_pico_array = pico_array.append(moreChildren).klog("appendedResult");

      gatherChildrensChildren = function(final_pico_array,moreChildren){
        arrayOfChildrenArrays = moreChildren.map(function(x){ gatherSubtree(x.klog("moreChildren child: ")) });
        toAppend = arrayOfChildrenArrays.reduce(function(a,b){ a.union(b) });
        return = final_pico_array.union(toAppend);
        return
      };

      result = (moreChildren.length() == 0) => final_pico_array | gatherChildrensChildren(final_pico_array, moreChildren);
      result
    }

    picoFromName = function(pico_name){
      return = ent:children.defaultsTo([]).collect(function(child){
                                              (child{"name"} ==  pico_name) => "target" | "non_targets"
                                            });
      return{"target"}.head().defaultsTo("Error")//no pico exists for given name
    }

    deleteChild = defaction(pico_name){
      ent_children = children(){"children"}
      filtered_children = ent_children.collect(function(child){
                                              (child{"name"} ==  pico_name) => "to_delete" | "dont_delete"
                                            })
      child_to_delete = filtered_children{"to_delete"}.head()

      every {
        engine:removePico(child_to_delete{"id"})
        send_directive("Deleting child", {"message": "Deleting pico with the given name: "+pico_name})
      }
      returns
      {

        "updated_children": filtered_children{"dont_delete"},
        "child": child_to_delete{"id"}
      }
    }
    hasChild = function(pico_name){
      ent_children = children(){"children"};
      target_child = ent_children.filter(function(child){
                                            child{"name"} ==  pico_name
                                          }).head().defaultsTo({});
      target_child{"name"} == pico_name
    }
// ********************************************************************************************
// ***                                      Rulesets                                        ***
// ********************************************************************************************
    rulesets = function() {
      eci = meta:eci;
      rids = engine:listAllEnabledRIDs();
      {

        "rids"     : rids
      }.klog("rulesets :")
    }
    rulesetsInfo = function(_rids) {//takes an array of rids as parameter // can we write this better???????
      //check if its an array vs string, to make this more robust.
      rids = ( _rids.typeof() == "Array" ) => _rids | ( _rids.typeof() == "String" ) => _rids.split(";") | "" ;
      results = rids.map(function(rid) {engine:describeRuleset(rid);});
      {

       "description"     : results
      }.klog("rulesetsInfo :")
    }

    installRulesets = defaction(rids){
      every{
        engine:installRuleset(meta:picoId, rids) setting(new_ruleset)
        send_directive("installed #{rids}")
      }
      returns {}
    }

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

        "channels" : results
      }.klog("channels: ")
    }
    channelAttributes = function(eci,name) {
      Eci = eci.defaultsTo(alwaysEci(name).defaultsTo("","no name or eci provided"),"no eci going with name") ;
      results = pci:get_eci_attributes(Eci
        ).defaultsTo("error",standardError("get_eci_attributes")); // list of ECIs assigned to userid
      {
        "attributes" : results
      }.klog("attributes")
    }
    channelPolicy = function(eci,name) {
      Eci = eci.defaultsTo(alwaysEci(name).defaultsTo("","no name or eci provided"),"no eci going with name") ;
      results = {}; //pci:get_eci_policy(Eci).defaultsTo("error",standardError("undefined")); // list of ECIs assigned to userid
      {
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
      every {
        engine:removeChannel(eci)
        send_directive("deleted channel #{eci}")
      }
    }

    /*options = {
        "name" : channel_name,
        "eci_type" : type,
        "attributes" : {"channel_attributes" : attrs},
        "policy" : decoded_policy//{"policy" : policy}
      }

    createChannel = defaction(id , name, type){
      engine:newChannel(id , name, type) setting(channel)
      send_directive("created channel #{new_eci}")
    }*/
// ********************************************************************************************
// ***                                      Picos                                           ***
// ********************************************************************************************
  myself = function(){
      { "id": ent:id, "eci": ent:eci, "name": ent:name }
  }

  children = function(name) {

    _children = ent:children.defaultsTo([]);
    _return = name => _children.filter(function(child){child{"name"} == name}) | _children;
    {
      "children" : _return
    }.klog("children :")
  }

  parent_eci = function() {
    _parent = ent:parent_eci.defaultsTo("");
    {
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
      "picoName" : return
    }.klog("name :")
  }
  picoECIFromName = function (name) {
    pico = ent:children.filter(function(rec){rec{"name"} ==  name})
                          .head();
    pico{"eci"}
  }

    createPico = defaction(name, rids){
      every{
        engine:newChannel(meta:picoId, name, "children") setting(parent_channel);// new eci for parent to child
        engine:newPico() setting(child);// newpico
        engine:newChannel(child{"id"}, "main", "secret") setting(channel);// new child root eci
        engine:installRuleset(child{"id"},rids.append(config{"os_rids"}));// install child OS
        event:send( // intoroduce child to itself and parent
          { "eci": channel{"id"},
            "domain": "wrangler", "type": "child_created",
            "attrs": ({
              "parent_eci": parent_channel{"id"},
             "name": name,
             "id" : child{"id"},
             "eci": channel{"id"},
             "rids": rids,
             "rs_attrs":event:attrs()
            })
            });
        event:send( // tell child that a ruleset was added
          { "eci": channel{"id"},
            "domain": "wrangler", "type": "ruleset_added",
            "attrs": ({
             "rids": rids,
             "rs_attrs":event:attrs()
            })
          });
      }
      returns {
        "parent_eci": parent_channel{"id"},
       "name": name,
       "id" : child{"id"},
       "eci": channel{"id"},
       "rids": rids
      }
    }

    updateChildCompletion = function(name){
      children_map = ent:children.collect(function(child){
                                            (child.name == name) => "childToUpdate" | "otherChildren"
                                          });//separate the children, returns two arrays
      updated_child = children_map.childToUpdate.head();
      updated_children = children_map.otherChildren.append(updated_child);//reunite with the other children
      updated_children
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
          (uniquePicoName( name )) => "unique" | "taken"
        });
        name = names{"unique"} || [];

        unique_name =  name.head().defaultsTo("",standardError("unique name failed"));
        (unique_name).klog("randomPicoName : ")
    }

    //returns true if given name is unique
    uniquePicoName = function(name){
          picos = children(){"children"};
          names = picos.none(function(child){
            pico_name = child{"name"};
            (pico_name ==  name)
            });
          (names).klog("uniquePicoName : ")

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
      rid_list = (rids.typeof() ==  "Array") => rids | rids.split(re#;#)
      b = rid_list.klog("attr Rids")
    }
    if(rids !=  "") then  // should we be valid checking?
      installRulesets(rid_list)
    fired {
      raise wrangler event "ruleset_added"
        attributes event:attrs().put({"rids": rid_list});
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
      //channel_results = check_name => createChannel(options) | {}
    }
          // do we need to check the format of name? is it wrangler"s job?
    if(check_name) then  //channel_name.match(re#\w[\w-]*#)) then

      engine:newChannel(meta:picoId, options{"name"}, options{"eci_type"}) setting(channel);

    fired {
     ent:channels := ent:channels.defaultsTo([]).append({"name": channel{"name"},
                                          "eci": channel{"id"},
                                          "type": channel{"type"},
                                          "attributes": options{"attributes"}
                                         }.klog("new channel"));
     ent:lastCreatedEci := channel;
     channel_name.klog(standardOut("success created channels "));
     null.klog(">> successfully  >>");
      raise wrangler event "channel_created" // event to nothing
            attributes event:attrs().put(["eci"],lastCreatedEci().klog("lastCreatedEci: ")) // function to access a magic varible set during creation
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
    select when wrangler child_creation or wrangler new_child_request
    pre {
      name = event:attr("name");//.defaultsTo(randomPicoName(),standardError("missing event attr name, random word used instead."));
      uniqueName = uniquePicoName(name).klog("uniqueName ");
      rids = event:attr("rids").defaultsTo([]);
      _rids = (rids.typeof() == "Array" => rids | rids.split(re#;#))
    }
    if(uniqueName) then every {
      createPico(name,_rids) setting(child)
    }
    fired {
      ent:children := ent:children.defaultsTo([]).append(child); // this is bypassed when module is used
    }
    else{
      name.klog(" duplicate Pico name, failed to create pico named ");
    }
  }

  rule child_created {
    select when wrangler child_created
    pre {
      parent_eci    = event:attr("parent_eci")
      name          = event:attr("name")
      id            = event:attr("id")
      eci           = event:attr("eci")
      rs_attrs      = event:attr("rs_attrs")
    }
    if true
    then
      event:send(
        { "eci": parent_eci,
          "domain": "wrangler", "type": "child_initialized",
          "attrs": event:attrs() })
    fired {
      ent:parent_eci := parent_eci;
      ent:name := name;
      ent:id := id;
      ent:eci := eci;
      raise visual event "update"
        attributes rs_attrs.put("dname",name)
    }
  }

//Child deletion-----------------------------

  rule delete_child_name_check {
    select when wrangler child_deletion
    pre {
      pico_name = event:attr("pico_name").defaultsTo("", standardError("missing pico name for deletion"));
    }
    if not hasChild(pico_name) then
      send_directive("Invalid deletion", {"err": "No child of this pico has the given name: "+pico_name})
    fired{
     last;
    }
  }
  rule deletion_prep {
    select when wrangler child_deletion
    pre {
      pico_name = event:attr("pico_name");
      filtered_children = ent:children.collect(function(child){
                                              (child{"name"} ==  pico_name) => "to_delete" | "dont_delete"
                                            }).klog("filtered_children result: ");
      target_child = filtered_children{"to_delete"}.head();
      subtreeArray = gatherSubtree(target_child).klog("Subtree result: ");
      updated_children = filtered_children{"dont_delete"}.defaultsTo([]);//defaultsTo for the case where there are no children left after the first child's deletion
    }
    noop()
    fired{
      raise wrangler event "children_deletion"
        attributes event:attrs().put(["subtreeArray"], subtreeArray)
                                .put(["updated_children"], updated_children)
    }
  }
  rule delete_all_children {
    select when wrangler children_deletion
    foreach event:attr("subtreeArray") setting(child)
    pre {
      updated_children = event:attr("updated_children");
    }
    if true then
      engine:removePico(child{"id"})
    fired{
      ent:children := updated_children.klog("updated_children: ") on final;
      raise information event "child_deleted"
        attributes event:attrs().put(["results"],results) on final;
    }
  }
  rule delete_child_testing {
    select when wrangler child_delete
    pre {
      child_id = event:attr("id");
    }
    if true then
      engine:removePico(child_id)
    fired{
    }
  }
//Child deletion (child requesting parent for deletion)------------------
  rule begin_deletion_request{//in child
    select when wrangler deletion_requested
    pre {
    }
    if false then
      noop()//perform any sort of checks in this ruleset to prevent firing, such as the authorization of the source to delete this pico
    fired{
      last;
    }
  }

  rule process_deletion_request{//in child
    select when wrangler deletion_requested
    pre {
      parent_eci = ent:parent{"eci"};
      attributes = event:attrs().put([],myself())//the parent will need to know that the child is the one really requesting the deletion
    }
    every{
      event:send({"eci": parent_eci, "eid": "DeletionRequest",
                "domain": "wrangler", "type": "child_requests_deletion",
                "attrs": attributes})
      send_directive("Requesting deletion from parent.")
    }
    fired{
    }
  }

  rule check_child_existence{//in parent
    select when wrangler child_requests_deletion
    pre {
      name = event:attr("name");
      id = event:attr("id");
      eci = event:attr("eci");
      target_child = picoFromName(name);
      hasChild = (target_child != "Error"
                  && target_child{"eci"} == eci
                  && target_child{"id"} == id) => true | false;
    }
    if not hasChild then
      send_directive("Invalid request", {"err": "Given pico is not a child of this pico or does not exist."})
    fired{
      last;
    }
  }

  rule process_child_deletion_request{//in parent
    select when wrangler child_requests_deletion
    pre {//consider adding more checks here if needed, or select on a different rule so developers can perform their own checks
      name = event:attr("name");
      id = event:attr("id");
      eci = event:attr("eci");
    }
    if true then
    noop()
    fired{
      raise wrangler event "child_deletion"
        attributes {"pico_name": name}
    }
  }

}//end ruleset
