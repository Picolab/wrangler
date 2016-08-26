ruleset b506607x16 {
  meta {
    name "PDS"
    description <<
      Pico Data Services (PDS), a common data base structure for all rulesets to use.
    >>
    author "Phil Windley & Ed Orcutt & PICOLABS"

    logging on

    provides items, get_keys, // general
     profile, // profile
     settings, get_config_value, get_setting_data_value , config_value, settings_names// settings

    
    sharing on

  }


    // --------------------------------------------
    // ent:profile
    //       {
    //        "name": "",
    //        "description": "",
    //        "location": "",
    //        "model": "",
    //        "model_description": "",
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

   /* // -for debugging???-------------------------------------------
    get_all_items = function() {
      ent:general;
    };
  */
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
       'status'   : ( status ),
        'general'     : return
      };
    }
    // set up pagination. look at fuse_fuel.krl allfillup -DEAD?
    sorted_values = function(namespace, sort_opt, num_to_return) {
        the_keys = this2that:transform(ent:general{[namespace]}, sort_opt); // get all the keys sorted by the key value provided in sort_opt
        the_keys.isnull()          => [] |
        not num_to_return.isnull() => the_keys.slice(0,num_to_return-1) // only return how much we want
                                    | the_keys
    };
    /*
   trips = function(id, limit, offset) {
       // x_id = id.isnull().klog(">>>> id >>>>>");
       // x_limit = limit.klog(">>>> limit >>>>>");
       // x_offset = offset.klog(">>>> offset >>>>>"); 

      id.isnull() || id eq "" => allTrips(limit, offset)
                               | ent:trips_by_id{mkTid(id)};
    };

    allTrips = function(limit, offset) {
      sort_opt = {
        "path" : ["endTime"],
  "reverse": true,
  "compare" : "datetime"
      };

      max_returned = 25;

      hard_offset = offset.isnull() 
                 || offset eq ""        => 0               // default
                  |                        offset;

      hard_limit = limit.isnull() 
                || limit eq ""          => 10              // default
                 | limit > max_returned => max_returned
     |                         limit; 

      global_opt = {
        "index" : hard_offset,
  "limit" : hard_limit
      }; 

      sorted_keys = this2that:transform(ent:trip_summaries, sort_opt, global_opt.klog(">>>> transform using global options >>>> "));
      sorted_keys.map(function(id){ ent:trip_summaries{id} })
    };
    */

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
       'status'   : ("success"),
        'profile'     : return
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
      return = (Key.isnull()) => (get_setting(Rid) ) | (
                              Rid.isnull() => get_setting_all() | 
                              ( (key eq "Data") => get_setting_value_default(Rid,Key,detail) | get_setting_value(Rid,Key)));
      {
       'status'   : "success",// update   
        'settings' : return
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
      "notes": "",
      "location": "",
      "model": "",
      "description": "",
      "pohoto": "https://s3.amazonaws.com/k-mycloud/a169x672/unknown.png"
    };

//    defaultCloud = {
//      "mySchemaName" : "Person",
//      "myDoorbell" : "none"
//    };

  }
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
    always {
      set ent:general{hash_path} value;
      raise pds event data_added with 
         namespace = namespace and
         keyvalue = keyvalue;
    }
  }

  rule update_item { 
    select when pds updated_data_available
    	foreach(event:attr("value") || {}) setting(akey, avalue)
    pre {
      namespace = event:attr("namespace").defaultsTo("", "no namespace");
      keyvalue = event:attr("key").defaultsTo("", "no key");
      hash_path = [namespace, keyvalue, akey];
    }
    always {
      set ent:general{ hash_path } avalue;
      raise pds event data_updated with 
        namespace = namespace and
        keyvalue = keyvalue if last;
    }
  }

  rule remove_item {
    select when pds remove_old_data
    pre{
      namespace = event:attr("namespace").defaultsTo("", "no namespace");
      keyvalue = event:attr("key").defaultsTo("", "no key");
      hash_path = [namespace, keyvalue];
    }
    always {
      clear ent:general{hash_path};
      raise pds event data_deleted with 
        namespace = namespace and
        keyvalue = keyvalue;
    }
  }

  rule remove_namespace {
    select when pds remove_namespace
    pre{
      namespace = event:attr("namespace").defaultsTo("", "no namespace");
    }
    always {
      clear ent:general{namespace};
      raise pds event namespace_deleted with 
        namespace = namespace;
    }
  }

  rule itemed_mapped {// should use decode??
    select when pds map_item
    pre{
      namespace = event:attr("namespace").defaultsTo("", "no namespace");
      mapvalues = event:attr("mapvalues").defaultsTo("", "no mapvalues").decode();
    }
    always {
      set ent:general{namespace} mapvalues;
      raise pds event new_map_added  with 
           namespace = namespace and
           mapvalues = mapvalues;
    }
  }

  // I dont think we need myCloud any more.
  /*
  rule SDS_init_mycloud {
    select when web sessionReady
    if (ent:general{"myCloud"} == 0) then { noop(); }
    fired {
      set ent:general{"myCloud"} defaultCloud;
    }
  }

  // ------------------------------------------------------------------------
  rule SDS_legacy_person {
    select when web sessionReady
    pre {
      schema = ent:general{["myCloud", "mySchemaName"]};
    }
    if (schema eq "person") then { noop(); }
    fired {
      set ent:general{["myCloud", "mySchemaName"]} "Person";
    }
  }
*/


  // profile
  /*
  rule init_profile { // should we combine with edit_profile? we only need to add created varible check in edit.
    select when pds init_profile 
    pre {
      profile = ent:profile;
      buildProfile = function(){
        created = time:strftime(time:now(), "%Y%m%dT%H%M%S%z", {"tz":"UTC"});
        newProfile = event:attrs().defaultsTo(0, "no attrs");
        ConstructedProfile = newProfile// does || work?
                  .put(["Name"], (newProfile{"Name"} || defaultProfile{"Name"})) 
                  .put(["Description"], (newProfile{"Description"} || defaultProfile{"Description"})) 
                  .put(["location"], (newProfile{"location"} || defaultProfile{"location"})) 
                  .put(["model"], (newProfile{"model"} || defaultProfile{"model"})) 
                  .put(["model_description"], (newProfile{"model_description"} || defaultProfile{"model_description"})) 
                  .put(["Photo"], (newProfile{"Photo"} || defaultProfile{"Photo"})) 
                  .put(["_created"], created)
                  .put(["_modified"], time:strftime(time:now(), "%Y%m%dT%H%M%S%z", {"tz":"UTC"}))
                  ;
        ConstructedProfile;
      };
      newly_constructed_profile = (profile == 0) => 
                                    buildProfile() | 
                                      "profile exsist";
      
    }
    if (profile == 0) then { 
      noop(); 
    }
    fired {
      set ent:profile newly_constructed_profile;
    }
  }
  */
  rule update_profile {
    select when pds updated_profile
    pre {
      profile = ent:profile || defaultProfile;
      all_attrs = event:attrs().defaultsTo(0, "no attrs");
      newProfile = all_attrs;
      created = function(){time:strftime(time:now(), "%Y%m%dT%H%M%S%z", {"tz":"UTC"});};
      buildProfile = function(newProfile){
        ConstructedProfile = newProfile// does || work?
                  .put(["name"], (newProfile{"name"} || profile{"name"})) 
                  .put(["description"], (newProfile{"description"} || profile{"description"})) 
                  .put(["location"], (newProfile{"location"} || profile{"location"})) 
                  .put(["model"], (newProfile{"model"} || profile{"model"})) 
                  .put(["model_description"], (newProfile{"model_description"} || profile{"model_description"})) 
                  .put(["photo"], (newProfile{"photo"} || profile{"photo"})) 
                  .put(["_created"], (profile{"_created"}||created()))
                  .put(["_modified"], time:strftime(time:now(), "%Y%m%dT%H%M%S%z", {"tz":"UTC"}))
                  ;
        ConstructedProfile;
      };
      newly_constructed_profile = (newProfile neq 0) => // as long as we have something to update
                                    buildProfile(newProfile) | 
                                      "nothing to update";
      
    }
    if (newly_constructed_profile neq "nothing to update") then { 
      noop(); 
    }
    fired {
      set ent:profile newly_constructed_profile;
      raise pds event "profile_updated" attributes all_attrs.put(["_status"],"success");
    }
    else{
      raise pds event "profile_updated" attributes all_attrs.put(["_status"],"failure");
    }
  }
 /* rule SDS_update_profile {  // do we need this rule?
    select when sds new_profile_item_available
    pre {
      // get when sds was created.
      created = profile("_created") || time:strftime(time:now(), "%Y%m%dT%H%M%S%z", {"tz":"UTC"});
      newProfile = event:attrs();
      newProfileWithImage = newProfile
                .put(["myProfilePhoto"], (newProfile{"Photo"} || defaultProfile{"Photo"})) 
                .put(["_created"], created)
                .put(["_modified"], time:strftime(time:now(), "%Y%m%dT%H%M%S%z", {"tz":"UTC"}))
                ;
    }
    always {
      set ent:profile newProfileWithImage;
      raise sds event "profile_updated" attributes newProfileWithImage;
    }
  }

// pass any number of key value pair 
  rule SDS_update_profile_partial {
    select when sds updated_profile_item_available
    foreach event:attrs() setting(profile_key, profile_value)

    {
      noop();
    }

    fired {
      set ent:profile {} if not ent:profile; // creates a profile ent if not aready there
      set ent:profile{profile_key} profile_value;
      raise sds event "profile_updated" on last;
    }

  }
/*
  rule SDS_new_profile_schema {
    select when sds new_profile_schema
    pre{
      hash_path = ["myCloud", "mySchemaName"]; // whats my cloud for ???
      mySchemaName = event:attr("mySchemaName").defaultsTo("", "no mySchemaName");

    }
    always {
      set ent:general{hash_path} mySchemaName; // why is this stored in general and not profile?
    }
  }

  rule SDS_update_doorbell {
    select when sds new_doorbell_available
    pre{
      doorbell = event:attr("doorbell").defaultsTo("", "no doorbell");
      hash_path = ["myCloud", "myDoorbell"];
    }
    always {// why do we put this in both profile and general ??? 
      set ent:profile{"myDoorbell"} doorbell;
      set ent:general{hash_path} doorbell;
    }
  }
  */
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
    always {
      set ent:settings{[set_rid, "name"]}   set_name ;
      set ent:settings{[set_rid, "rid"]}    set_rid ;
      set ent:settings{[set_rid, "schema"]} set_schema if set_schema;
      //set ent:settings{[set_rid, "data"]}   set_data if not set_data;
      set ent:settings{[set_rid, "data", set_attr]} set_value if set_attr;
      raise pds event "settings_added" attributes event:attrs();
    }
  }
  /*
  rule SDS_add_settings_schema {
    select when sds new_settings_schema
    pre {
      setName   = event:attr("Name").defaultsTo("unknown","no Name");
      setRID    = event:attr("RID").defaultsTo("unknown","no RID");
      setSchema = event:attr("Schema").defaultsTo([],"no Schema");
      setData   = event:attr("Data").defaultsTo({},"no Data");

      gotData = ent:settings{[setRID, "setData"]};

    }
    always {
      set ent:settings{[setRID, "Name"]}   setName;
      set ent:settings{[setRID, "RID"]}    setRID;
      set ent:settings{[setRID, "Schema"]} setSchema;
      set ent:settings{[setRID, "Data"]}   setData if not gotData;
    }
  }

  rule SDS_add_settings_data {
    select when sds new_settings_data
    pre {
      setRID    = event:attr("RID").defaultsTo("unknown","no RID");
      setData   = event:attr("Data").defaultsTo({},"no Data");
      hash_path = [setRID, "setData"];
    }
    always {
      set ent:settings{hash_path} setData;
    }
  }

  rule SDS_add_settings {
    select when sds new_settings_available
    pre {
      setRID    = event:attr("RID").defaultsTo("unknown","no RID");
      setData   = event:attr("Data").defaultsTo({},"no Data");
      hash_path     = [setRID, "setData"];
    }
    always {
      set ent:settings{hash_path} setData.delete(["setRID"]); // why not use clear????
    }
  }

  rule SDS_add_settings_attribute {
    select when sds new_settings_attribute
    pre {
      setRID    = event:attr("RID").defaultsTo("unknown","no RID");
      setAttr   = event:attr("setAttr").defaultsTo("unknown","no setAttr");
      setValue  = event:attr("Value").defaultsTo("unknown","no Value");
      hash_path = [setRID, "setData", setAttr];
    }
    always {
      set ent:settings{hash_path} setValue;
    }
  }
 */ 
 rule clearPDS {
    select when pds clear_all_data
    pre{
    }
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
