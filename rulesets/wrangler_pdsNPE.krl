ruleset io.picolabs.wrangler.PDS {
  meta {
    name "PDS"
    description <<
      Pico Data Services (PDS), a common data base structure for all rulesets to use.
    >>
    author "PICOLABS"

    logging on

    provides items, get_keys, // general
     profile, // profile
     settings, get_config_value, get_setting_data_value , config_value, settings_names// settings

    
    shares items, get_keys, // general
     profile, // profile
     settings, get_config_value, get_setting_data_value , config_value, settings_names, __testing// settings

  }


    // --------------------------------------------
    // ent:profile
    //       {
    //        "name": "",
    //        "description": "",
    //        "photo": "https://s3.amazonaws.com/k-mycloud/a169x672/unknown.png"
    //      }
    // ent:general
    //      namespace : {
    //           key : <value>
    //     }
    // 
    // ent:settings 
    //     "<rulesetID>" : {
    //       "name"   : "",
    //       "rID"    : <rulesetID>,
    //       "data"   : {},
    //       "schema" : []
    //     }
    //
    // --------------------------------------------


  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "pds", "type": "updated_profile",
                                "attrs": [ "name", "description", "photo" ] } ] }

    items = function (namespace, key){
      item = function(namespace, keyvalue) {
        ent:general{[namespace, keyvalue]}
      };

      multipleItems = function(namespace) {
        ent:general{namespace}
      };
      return = (key.isnull()) => (namespace.isnull() => ent:general | multipleItems( namespace) ) | item(namespace, key) ;
      status = namespace.isnull() => "failed" | "success";
      {
       "status"   : ( status ),
        "general"     : return
      };
    }

    profile = function(key){
        get_profile = function(k) {
          ent:profile{k};
        };
        get_all_profile = function() {
          ent:profile;
        };
        return = (key.isnull()) => get_all_profile() | get_profile(key);
        // status update 
        {
       "status"   : ("success"),
        "profile"     : return
        };
    };


    // --------------------------------------------dead
    settings_names = function() {
      foo = ent:settings.keys().map(function(setRID) {
        setName = ent:settings{[setRID,"Name"]};
        {
          "setRID": setRID,
          "setName": setName
        }
      });
      foo
    };

    settings = function(Rid,Key,detail){ // do we need to have  a default for detail?
      //detail only will work with "Data" varible
      get_setting_all = function() { //dead, rid should never be null
        ent:settings
      };
      get_setting = function(rid) {
        ent:settings{rid}
      };
      get_setting_value = function(rid, varible) {
        ent:settings{[rid, varible]}
      };
      get_setting_value_default = function(rid, varible, value) {
        ent:settings{[rid, "Data",value]}
      };
      return =  Rid.isnull() => get_setting_all() | (Key.isnull()) => (get_setting(Rid) ) | (
                             
                              ( (key eq "Data") => get_setting_value_default(Rid,Key,detail) | get_setting_value(Rid,Key)));
      {
       "status"   : "success",// update   
        "settings" : return
      };
    }

    // keep ,--------------------------------------------
    setting_data = function(setRID) {
     ent:settings{[setRID, "Data"]}
    };

    // --------------------------------------------
    setting_schema = function(setRID) {
     ent:settings{[setRID, "Schema"]}
    };

    // -------------------------------------------- I think sorting and filtering should be done by client 
    setting_data_value = function(setRID, setKey) {
      ent:settings{[setRID, "Data", setKey]}
    };

    config_value = function(setKey) {
      setRID = meta:callingRID();
      ent:settings{[setRID, "Data", setKey]}
    };

    defaultProfile = {
      "name": "",
      "description": "",
      "photo": "https://s3.amazonaws.com/k-mycloud/a169x672/unknown.png"
    };

  }//End Global
// Rules

//------------------------------- ent: general

  rule add_item {
    select when pds new_data_available
    pre {
      namespace = event:attr("namespace").defaultsTo("", "no namespace");
      keyvalue = event:attr("key").defaultsTo("", "no key");
      hash_path = [namespace, keyvalue]; //array of keys
      value =  event:attr("value").defaultsTo("", "no value");
    }
    noop()
    always {
      //set ent:general{hash_path} value;
      ent:general := ent:general.put([hash_path], value);
      raise pds event "data_added"
        attributes {"namespace": namespace, "keyvalue": keyvalue}
    }
  }

  rule update_item { 
    select when pds updated_data_available
      //foreach(event:attr("value") || {}) setting(akey, avalue)
        foreach(event:attr("value") || {}) setting(avalue, akey)//NPE binds value first, then key
    pre {
      namespace = event:attr("namespace").defaultsTo("", "no namespace");
      keyvalue = event:attr("key").defaultsTo("", "no key");
      hash_path = [namespace, keyvalue, akey];
    }
    noop()
    always {
      //set ent:general{ hash_path } avalue;
      ent:general := ent:general.put([hash_path], avalue);
      raise pds event "data_updated"
        attributes {"namespace": namespace, "keyvalue": keyvalue} if last;
    }
  }

  rule remove_item {
    select when pds remove_old_data
    pre{
      namespace = event:attr("namespace").defaultsTo("", "no namespace");
      keyvalue = event:attr("key").defaultsTo("", "no key");
      hash_path = [namespace, keyvalue];
    }
    noop()
    always {
      //clear ent:general{hash_path};
      ent:general := ent:general.delete(hash_path);
      raise pds event "data_deleted"
        attributes {"namespace": namespace, "keyvalue": keyvalue}
    }
  }

  rule remove_namespace {
    select when pds remove_namespace
    pre{
      namespace = event:attr("namespace").defaultsTo("", "no namespace");
    }
    noop()
    always {
      //clear ent:general{namespace};
      ent:general := ent:general.delete(namespace);
      raise pds event "namespace_deleted"
        attributes {"namespace": namespace}
    }
  }

  rule itemed_mapped {// should use decode??
    select when pds map_item
    pre{
      namespace = event:attr("namespace").defaultsTo("", "no namespace");
      mapvalues = event:attr("mapvalues").defaultsTo("", "no mapvalues").decode();
    }
    noop()
    always {
      //set ent:general{namespace} mapvalues;
      ent:general := ent:general.put([namespace], mapvalues);
      raise pds event "new_map_added"
        attributes {"namespace": namespace, "mapvalues": mapvalues};
    }
  }

  // ent: profile
  rule update_profile {//should we check if atleast name, description and photo are ALL contained before saving the info?
    select when pds updated_profile
    pre {
      newProfile = event:attrs().defaultsTo({}, "no attrs").klog("newProfile: ");
      created = function(){
        //time:strftime(time:now(), "%Y%m%dT%H%M%S%z", {"tz":"UTC"});
        time:now()
      };

      buildProfile = function(newProfile){
        profile = ent:profile || defaultProfile;
        ConstructedProfile = newProfile
                  .put(["name"], (newProfile{"name"} || profile{"name"})) 
                  .put(["description"], (newProfile{"description"} || profile{"description"}))  
                  .put(["photo"], (newProfile{"photo"} || profile{"photo"})) 
                  .put(["_created"], (profile{"_created"}||created()))
                  //.put(["_modified"], time:strftime(time:now(), "%Y%m%dT%H%M%S%z", {"tz":"UTC"}))
                  .put(["_modified"], time:now())
                  ;
        ConstructedProfile
      };
      newly_constructed_profile = ((newProfile.keys()).length().klog("Checking length: ") > 0).klog("Result: ") => // as long as we have something to update
                                    buildProfile(newProfile) | 
                                      "nothing to update";
      
    }
    if (newly_constructed_profile.klog("newly_constructed_profile: ") != "nothing to update") then  
      noop()
    fired {
      ent:profile := newly_constructed_profile.klog("Got here... newly_constructed_profile: ");
      raise pds event "profile_updated" attributes newProfile.put(["_status"],"success");
    }
    else{
      raise pds event "profile_updated" attributes newProfile.put(["_status"],"failure");
    }
  }

//----------------------------settings
    // ent:settings 
    //     "a169x222" : {
    //       "name"   : "",
    //       "rid"    : "a169x222",
    //       "data"   : {data_key:set_value},
    //       "schema" : []
    //     }
  rule settings_added{ // will this fire with out kre stopping the failed passed varibles
    select when pds add_settings
    pre {
      b= event:attrs().klog("all attrs: ");
      set_name   = event:attr("name").defaultsTo(0,"no Name");
      set_rid    = event:attr("keyed_rid").defaultsTo(0,"no keyed_rid");// rid is remove when passed in by prototype. changing rid to unique att.
      set_schema = event:attr("schema").defaultsTo(0,"no Schema");
      //set_data   = event:attr("data").defaultsTo(0,"no Data");
      set_attr   = event:attr("data_key").defaultsTo(0,"no setAttr");
      set_value  = event:attr("value").defaultsTo(0,"no Value");

    }
    noop()
    always {
      ent:settings := ent:settings.put([set_rid, "name"], set_name);
      ent:settings := ent:settings.put([set_rid, "rid"], set_rid);
      ent:settings := ent:settings.put([set_rid, "schema"], set_schima) if set_schema;
      ent:settings := ent:settings.put([set_rid, "data"], set_attr) if set_attr;
      raise pds event "settings_added" attributes event:attrs();
    }
  }

 rule clearPDS {
    select when pds clear_all_data
    pre{
    }
    noop()
    always {
      clear ent:general;
      clear ent:profile;
      clear ent:settings;
    }
  }
  // ------------------------------------------------------------------------
  // Beyond here there be dragons :)
  // ------------------------------------------------------------------------
}
