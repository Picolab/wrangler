ruleset prototypes {
  meta {
    use module wrangler
    provide prototypes
    shares __testing, prototypes
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
    basePrototype = {
      "meta" : {
                "discription": "Wrangler base prototype"
                },
                //array of maps for meta data of rids .. [{rid : id},..}  
      "rids": [ 
                "wrangler", "Subscriptions", "io.picolabs.visual_params"
              ],
      "channels" : [{
                      "name"       : "wellknown",
                      "type"       : "wrangler",
                      "attributes" : "wrangler test attrs",
                      "policy"     : "not implemented"
                    }
                    ], // we could instead use tuples  [["","","",""]], // array of arrrays [[name,type,attributes,policy]]
      "prototypes" : [/*{// belongs in relationManager 
                      "url" : "https://raw.githubusercontent.com/burdettadam/Practice-with-KRL/master/prototype.json",
                      "prototype_name": "base_add_test"
                      }*/],// add prototype by url
      "children" : [
                    /*{
                      "name" : "testChild",
                      "prototype" : "base_add_test"
                      }*/
                      ],// add prototype by url
      "subscriptions_request": [/*{
                                  "name"          : "parent-child",
                                  "name_space"    : "wrangler",
                                  "my_role"       : "child",
                                  "subscriber_role"     : "parent",
                                  "subscriber_eci"    : ["owner"],
                                  "channel_type"  : "wrangler",
                                  "attrs"         : "nogiven"
                                }*/],
      "Prototype_events" : [
                            /*{
                              "domain": "wrangler",
                              "type"  : "base_prototype_event1",
                              "attrs" : {"attr1":"1",
                                          "attr2":"2"
                                        }
                            }*/
                            ], // array of maps
      "PDS" : {
                "profile" : {
                            "name":"base",
                            "description":"discription of the general pds created",
                            "location":"40.252683,-111.657486",
                            "model":"unknown",
                            "model_description":"no model at this time",
                            "photo":"https://geo1.ggpht.com/cbk?panoid=gsb1YUyceEtoOLMIVk2TQA&output=thumbnail&cb_client=search.TACTILE.gps&thumb=2&w=408&h=256&yaw=87.31411&pitch=0"
                            },
                "general" : {"test":{"subtest":"just a test"}},
                "settings": {"b507901x1.prod":{
                                              "name":"wrangler",
                                              "keyed_rid" :"b507901x1.prod",
                                              "schema":["im","a","schema"],
                                              "data_key":"first_key",
                                              "value":"first_value"
                                              }
                            }
              }
  }

// intialize ent;prototype, check if it has a prototype and default to hard coded prototype
// we will store base prototypes as hard coded varibles with, 

    prototypes = function() {
      init_prototypes = ent:prototypes || {}; // if no prototypes set to map so we can use put()
      prototypes = init_prototypes.put(["base"],basePrototype);
      {
        "status" : true,
        "prototypes" : prototypes
      }.klog("prototypes :")
    }
  }

// ********************************************************************************************
// ***                                      Base Dependancies                               ***
// ********************************************************************************************

// ---------------------- base channels creation ----------------------
  rule initializeBaseChannels {
    select when wrangler init_events 
      foreach basePrototype{"channels"}.klog("Prototype base channels : ") setting (PT_channel)
    pre {
      attrs = {
                  "channel_name" : PT_channel{"name"},
                  "channel_type" : PT_channel{"type"},
                  "attributes"   : PT_channel{"attributes"},
                  "policy"       : PT_channel{"policy"}
              };
    }
    
      noop()
    
    always {
     null.klog("init channels");
      raise wrangler event "channel_creation_requested" 
            attributes attrs.klog("attributes : ")
    }
  }

// ---------------------- base Prototypes adding ----------------------
  rule initializebasePrototypes {
    select when wrangler init_events 
      foreach basePrototype{"prototypes"}.klog("Prototype base add prototypes: ") setting (prototype)
    pre {
      attrs = prototype;
    }
    
      noop()
    
    always {
     null.klog("init add prototypes");
      raise wrangler event "add_prototype" 
            attributes attrs.klog("attributes : ")
    }
  }
// ---------------------- base Prototypes children creation ----------------------
  rule initializebasechildren {
    select when wrangler init_events 
      foreach basePrototype{"children"}.klog("Prototype base create children: ") setting (child)
    pre {
      attrs = child;
    }
    
      noop()
    
    always {
     null.klog("init add prototypes");
      raise wrangler event "child_creation" 
            attributes attrs.klog("attributes : ")
    }
  }

// ---------------------- base subscription creation ----------------------
  rule initializebaseSubscriptions {
    select when wrangler init_events 
      foreach basePrototype{"subscriptions_request"}.klog("Prototype base subscriptions_request: ") setting (subscription)
    pre {
      getRootEci = function (eci){
        results = pci:list_parent(eci);
        myRooteci = (results.typeof() ==  "array") => getRootEci(results[0]) | eci ;
        myRooteci;
      };

      /*
        \___  \_,
         ___\_  |   __,
       .'.--. ```-./   
       `....--'.'''.-p./
      -{{{   }<=-= (  <
       .''''--.`...'-b`\   
  jgs   `._____...-'\__
         ___/  _|     ` BUG: getOedipus will traverse to the root pico, which is not necessarily
        /     / `            the pico that is being created. Can be solved by adding a variable
                             with a special identifier for root prototype
      */
      getOedipus = function (eci,child_eci){
        myParent = pci:list_parent(eci);
        a = child_eci;
        myRooteci = (myParent.typeof() ==  "array") => getOedipus(myParent[0],eci) | skyQuery(child_eci,"b507901x1.prod","name",{},null,null,null);
        myRooteci
      };

      Oedipus_results = getOedipus(meta:eci).klog("Oedipus: ");
      Oedipus = Oedipus_results{"picoName"};
      root_eci = getRootEci(meta:eci).klog("root_eci: ");


      getTargetEci = function (path, eci) {
        return = wrangler:skyQuery(eci,"b507901x1.prod","children",{},null,null,null);
        children = return{"children"};
        child_name = path.head();
        child_name_look_up = (child_name ==  "__Oedipus_") => Oedipus | child_name;
        child_name = child_name_look_up;
        child_objects  = children.filter( function(child) {child{"name"} ==  child_name});
        child_object = child_objects[0];
        child_eci  = (child_object{"name"} !=  child_name) => "error" | child_object{"eci"};
        new_path = path.klog("path :").tail().klog("child_eci: #{child_eci},eci: #{eci},new_path: ");
        target_eci = (path.length() ==  0 ) => eci | (child_eci ==  "error") => child_eci | getTargetEci(new_path,child_eci) ;
        target_eci;
      };

      attrs = subscription;
      target = attrs{"subscriber_eci"};
      target_eci = ( target.typeof() ==  "array" ) => getTargetEci(target.tail(),root_eci) | target ;
      attr = attrs.put({"subscriber_eci" : target_eci.klog("target_eci: ")}); 
    }
    
      noop()
    
    always {
     null.klog("init subscription");
      raise wrangler event "subscription" 
            attributes attr.klog("attributes : ")
    }
  }

// ********************************************************************************************
// ***                                      Prototype Depandancies                          ***
// ********************************************************************************************
// ---------------------- prototype channels creation -----------------------
  rule initializePrototypeChannels {
    select when wrangler init_events 
      foreach ent:prototypes{["at_creation","channels"]}.klog("Prototype_channels : ") setting (PT_channel)
    pre {
      attrs = {
                  "channel_name" : PT_channel{"name"},
                  "channel_type" : PT_channel{"type"},
                  "attributes"   : PT_channel{"attributes"},
                  "policy"       : PT_channel{"policy"}
              };
    }
    
      noop()
    
    always {
     null.klog("init pds");
      raise wrangler event "channel_creation_requested" 
            attributes attrs.klog("attributes : ")
    }
  }

// ---------------------- Prototype adding ----------------------
  rule initializePrototypePrototypes {
    select when wrangler init_events 
      foreach ent:prototypes{["at_creation","prototypes"]}.klog("Prototype add prototypes: ") setting (prototype)
    pre {
      attrs = prototype;
    }
    
      noop()
    
    always {
     null.klog("init add prototypes");
      raise wrangler event "add_prototype" 
            attributes attrs.klog("attributes : ");
    }
  }
  // ---------------------- Prototype children creation ----------------------
  rule initializePrototypeChildren {
    select when wrangler init_events 
      foreach ent:prototypes{["at_creation","children"]}.klog("Prototype base create children: ") setting (child)
    pre {
      attrs = child;
    }
    
      noop()
    
    always {
     null.klog("init add prototypes");
      raise wrangler event "child_creation" 
            attributes attrs.klog("attributes : ")
    }
  }

// ---------------------- prototype subscription creation ----------------------
  rule initializePrototypeSubscriptions {
    select when wrangler init_events 
      foreach ent:prototypes{["at_creation","subscriptions_request"]}.klog("Prototype subscriptions_request: ") setting (subscription)
    pre {
      getRootEci = function (eci){
        results = pci:list_parent(eci);
        myRooteci = (results.typeof() ==  "array") => getRootEci(results[0]) | eci ;
        myRooteci;
      };

      getOedipus = function (eci,child_eci){
        myParent = pci:list_parent(eci);
        a = child_eci;
        myRooteci = (myParent.typeof() ==  "array") => getOedipus(myParent[0],eci) | skyQuery(child_eci,"b507901x1.prod","name",{},null,null,null);
        myRooteci
      };

      Oedipus_results = getOedipus(meta:eci).klog("Oedipus: ");
      Oedipus = Oedipus_results{"picoName"};
      root_eci = getRootEci(meta:eci).klog("root_eci: ");


      getTargetEci = function (path, eci) {
        return = skyQuery(eci,"b507901x1.prod","children",{},null,null,null);
        children = return{"children"};
        child_name = path.head();
        child_name_look_up = (child_name ==  "__Oedipus_") => Oedipus | child_name;
        child_name = child_name_look_up;
        child_objects  = children.filter( function(child) {child{"name"} ==  child_name});
        child_object = child_objects[0];
        child_eci  = (child_object{"name"} !=  child_name) => "error" | child_object{"eci"};
        new_path = path.klog("path :").tail().klog("child_eci: #{child_eci},eci: #{eci},new_path: ");
        target_eci = (path.length() ==  0 ) => eci | (child_eci ==  "error") => child_eci | getTargetEci(new_path,child_eci) ;
        target_eci;
      };

      attrs = subscription;
      target = attrs{"subscriber_eci"};
      target_eci = ( target.typeof() ==  "array" ) => getTargetEci(target.tail(),root_eci) | target ;
      attr = attrs.put({"subscriber_eci" : target_eci.klog("target_eci: ")}); 
    }
    
      noop()
    
    always {
     null.klog("init subscription");
      raise wrangler event "subscription" 
            attributes attr.klog("attributes : ")
    }
  }

// ********************************************************************************************
// ***                                      PDS  Base Initializing                          ***
// ********************************************************************************************
/*      
---------------structure-example---------------
"PDS" : {
      "profile" : {
                  "name":"base",
                  "description":"discription of the general pds created",
                  "location":"40.252683,-111.657486",
                  "model":"unknown",
                  "model_description":"no model at this time",
                  "photo":"https://geo1.ggpht.com/cbk?panoid=gsb1YUyceEtoOLMIVk2TQA&output=thumbnail&cb_client=search.TACTILE.gps&thumb=2&w=408&h=256&yaw=87.31411&pitch=0"
                  },
      "general" : {"test":{"subtest":"just a test"}},
      "settings": {"b507901x1.prod":{
                                    "name":"wrangler",
                                    "keyed_rid" :"b507901x1.prod",
                                    "data":{"first_key":"first_value"},
                                    "schema":["im","a","schema"],
                                    }
                  }
    }
*/
  rule initializeProfile {// this rule should build pds data structure
    select when wrangler init_events
    pre {
      attrs = basePrototype{["PDS","profile"]};
    }
    
      noop()
    
    always {
    raise pds event "updated_profile" 
            attributes attrs
    }
  }

  rule initializeGeneral {
    select when wrangler init_events
      foreach basePrototype{["PDS","general"]}.klog("PDS General: ") setting (key_of_map) // for each "key"
    pre {
      general_map = basePrototype{["PDS","general"]};
      namespace = key_of_map;
      mapedvalues = general_map{key_of_map};
      attrs = {
        "namespace": namespace,
        "mapvalues": mapedvalues.encode()
      };
    }
    
      noop()
    
    always {
     mapedvalues.klog(">> mapped values >>");
      raise pds event "map_item" // init general  
            attributes attrs
    }
  }

  rule initializePdsSettings { // limits to how many data varibles in a settings at creation exist....
    select when wrangler init_events
      foreach basePrototype{["PDS","settings"]}.klog("PDS settings: ") setting (key_of_map) // for each "key" (rid)
    pre {
      settings_map = basePrototype{["PDS","settings"]};
      //rid = key_of_map;
      settings = settings_map{key_of_map}.klog("settings attrs: "); // settings are all the attributes add_settings requires 
    }
    
      noop()
    
    always {
     key_of_map.klog(">> attrs >>");
    raise pds event "add_settings" 
            attributes settings
    }
  }

// ********************************************************************************************
// ***                                      Event Barrier                                   ***
// ********************************************************************************************
 
  // since we use for each to initialize the pds, we can not use a the single raised events from pds for our barrier. this barrier will have to be re-constructed.
  //this will fire every so offten during a picos life
  rule initializedBarrierA{// after base pds is initialize update prototype pds and raise prototype events
    //select when count ent:general_operations (pds new_map_added) // general inited// does not work
    select when count 0 (pds new_map_added) // count will need to be updated as base prototype is changed
    pre {
    }
    
      noop()
    
    always {
    raise wrangler event "new_map_added"  
            attributes {}
    }
  }
  //this will fire every so offten during a picos life
  rule initializedBarrierB{// after base pds is initialize update prototype pds and raise prototype events
    //select when count ent:settings_operations (pds settings_added) // settings inited// does not work
    select when count 0 (pds settings_added)  // count will need to be updated as base prototype is changed
    pre {
    }
    
      noop()
    
    always {
    raise wrangler event "settings_added"  
            attributes {}
    }
  }
  
  // count will need to be updated with base prototype.
    rule initializedBarrierC{// after base pds is initialize update prototype pds and raise prototype events
    select when wrangler new_map_added // general inited
            and pds profile_updated // profile inited
            and wrangler settings_added // settings inited
            and wrangler init_events // only fire when the pico is created
    pre {
    }
    
      noop()
    
    always {
    raise wrangler event "pds_inited"  
            attributes {};
    raise wrangler event "child_completed"
            attributes event:attrs()
    }
  }

// ********************************************************************************************
// ***                                    Prototype Custom Events                           ***
// ********************************************************************************************

  rule raisePrototypeEvents {
    select when wrangler pds_inited
    foreach ent:prototypes{["at_creation","Prototype_events"]} setting (Prototype_event)
    pre {
      a= Prototype_event.klog("prototype event: ");
      Prototype_domain = Prototype_event{"domain"};
      Prototype_type = Prototype_event{"type"};
      Prototype_attrs = Prototype_event{"attrs"}.decode();
    }
    
      event:send({"cid":meta:eci}, Prototype_domain, Prototype_type)
        with attrs = Prototype_attrs
    
    always {
     null.klog ("raise a prototype event with event send.");
    }
  }

// ********************************************************************************************
// ***                                    Prototypes Management                             ***
// ********************************************************************************************
  rule initializePrototype { 
    select when wrangler create_prototype //raised from parent in new child
    pre {
      prototype_at_creation = event:attr("prototype").decode(); // no defaultto????
    }
    noop()
    always {
      ent:prototypes{["at_creation"]} := prototype_at_creation;
    }
  }

  rule addPrototype {
    select when wrangler add_prototype
            or  wrangler update_prototype
    pre {
      proto_from_url = function(){
        prototype_url = event:attr("url");
        response = http:get(prototype_url, {});
        response_content = response{"content"}.decode();
        response_content
      };

      prototype = event:attr("url").isnull() => event:attr("prototype")| proto_from_url();
      proto_obj = prototype.decode(); // this decode is redundant, but the rule works so Im not messing with it.
      prototype_name = event:attr("prototype_name");
    }
    // should we always add something?
    
      noop()
    
    always {
      ent:prototypes{[prototype_name]} := proto_obj;
    raise wrangler event "Prototype_type_added" 
            attributes event:attrs();
    }
  }

  rule removePrototype {
    select when wrangler remove_prototype
    pre {
      prototype_name = event:attr("prototype_name");
    }
    
      noop()
    
    always {
      //clear ent:prototypes{prototype_name} ; making an issue to support "clear"
    raise wrangler event "Prototype_type_removed" 
            attributes event:attrs();
    }
  }

// ********************************************************************************************
// ***                                      PDS  Prototype Updates                          ***
// ********************************************************************************************
// NEED TO UPDATE RULES TO NOT FIRE IF NO Prototype UPDATES ARE NEEDED.

  rule updatePrototypeProfile {
    select when wrangler pds_inited
    pre {
      attrs = ent:prototypes{["at_creation","PDS","profile"]};
    }
    
      noop()
    
    always {
    raise pds event "updated_profile" // init prototype  // rule in pds needs to be created.
            attributes attrs
    }
  }
  rule updatePrototypeGeneral {
    select when wrangler pds_inited 
      foreach ent:prototypes{["at_creation","PDS","general"]}.klog("Prototype PDS general: ")  setting (key_of_map) // for each "key"
    pre {
      general_map = ent:prototypes{["at_creation","PDS","general"]};
      namespace = key_of_map;
      mapedvalues = general_map{key_of_map};
      attrs = {
        "namespace": namespace,
        "mapvalues": mapedvalues.encode()
      };
    }
    
      noop()
    
    always {
      raise pds event "map_item"  
            attributes attrs
    }
  }

  rule updatePrototypePdsSettings {
    select when wrangler pds_inited
   foreach basePrototype{["at_creation","PDS","settings"]}.klog("PDS settings: ") setting (key_of_map) // for each "key" (rid)
    pre {
      settings_map = basePrototype{["at_creation","PDS","settings"]};
      //rid = key_of_map;
      settings = settings_map{key_of_map}.klog("settings attrs: "); // settings are all the attributes add_settings requires 
    }
    
      noop()
    
    always {
     null.klog(">> attrs #{key_of_map} >>");
    raise pds event "add_settings" 
            attributes settings
    }
  }

}


