ruleset io.picolabs.wrangler.common {
  meta {
    shares __testing, skyQuery, prototypes
    provides skyQuery, prototypes
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
    
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
    
    basePrototype = {
      "meta" : {
                "discription": "Wrangler base prototype"
                },
                //array of maps for meta data of rids .. [{rid : id},..}  
      "rids": [ 
                "wrangler", "Subscriptions", "io.picolabs.visual_params", "prototypes", "io.picolabs.wrangler.PDS", "io.picolabs.wrangler.common"
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
    prototypes = function() {
      init_prototypes = ent:prototypes || {}; // if no prototypes set to map so we can use put()
      prototypes = init_prototypes.put(["base"],basePrototype);
      {
        "status" : true,
        "prototypes" : prototypes
      }.klog("prototypes :")
    }
  }//End Global
  

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
}//End Ruleset
