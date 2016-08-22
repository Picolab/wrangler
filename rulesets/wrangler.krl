// operators are camel case, variables are snake case.
    
ruleset v1_wrangler {
  meta {
    name "Wrangler Core"
    description <<
Wrangler Core Module

    use module v1_wrangler alias wrangler

This Ruleset/Module provides a developer interface to the PICO (persistent computer object).
When a PICO is created or authenticated this ruleset will be installed to provide essential
services.
>>
    author "BYU Pico Lab"
    
    logging off

    use module b16x24 alias system_credentials
    use module wrangler_pds alias pds
    // errors raised to.... unknown


    provides skyQuery, rulesets, rulesetsInfo, installRulesets, uninstallRulesets, //ruleset
    channel, channelAttributes, channelPolicy, channelType, //channel
    children, children_FixitFelix , parent, attributes, prototypes, name, profile, pico, checkPicoName, createChild, deleteChild, //pico 
    subscriptions, eciFromName, subscriptionAttributes,checkSubscriptionName, //subscription
    standardError
    sharing on

  }

  //dispatch {
    //domain "ktest.heroku.com"
  //}
  global {
    //functions
   
      //add _host for host make it defaultsTo meta:host(), create function to make cloud_url string from host 
      // path must start with "/""
    skyQuery = function(eci, mod, func, params,_host,_path,_root_url) {
      createRootUrl = function (_host,_path){
        host = _host || meta:host();
        path = _path || "/sky/cloud/";
        root_url = "https://#{host}#{path}";
        root_url
      };
      root_url = _root_url.isnull() => createRootUrl(_host,_path) | _root_url ;
      log = root_url.klog("root_url : ");
      response = http:get("#{root_url}#{mod}/#{func}", (params || {}).put(["_eci"], eci));

      status = response{"status_code"};

      error_info = {
        "error": "sky query request was unsuccesful.",
        "httpStatus": {
            "code": status,
            "message": response{"status_line"}
        }
      };


      response_content = response{"content"}.decode();
      response_error = (response_content.typeof() eq "hash" && response_content{"error"}) => response_content{"error"} | 0;
      response_error_str = (response_content.typeof() eq "hash" && response_content{"error_str"}) => response_content{"error_str"} | 0;
      error = error_info.put({"skyQueryError": response_error, "skyQueryErrorMsg": response_error_str, "skyQueryReturnValue": response_content});
      is_bad_response = (response_content.isnull() || response_content eq "null" || response_error || response_error_str);


      // if HTTP status was OK & the response was not null and there were no errors...
      (status eq "200" && not is_bad_response) => response_content | error
    };

// ********************************************************************************************
// ***                                      Rulesets                                        ***
// ********************************************************************************************
  //-------------------- Rulesets --------------------
    rulesets = function() {
      eci = meta:eci()
      //.klog("eci: ")
      ;
      results = pci:list_ruleset(eci).klog("results of pci list_ruleset");//defaultsTo("error",standardError("pci list_ruleset failed"));  
      rids = results{'rids'}.defaultsTo("error",standardError("no hash key rids"));
      {
       'status'   : (rids neq "error"),
        'rids'     : rids
      };
    }
    // pci method? 
    rulesetsInfo = function(rids) {//takes an array of rids as parameter // can we write this better???????
      //check if its an array vs string, to make this more robust.
      rids_string = ( rids.typeof() eq "array" ) => rids.join(";") | ( rids.typeof() eq "str" ) => rids | "" ;
      describe_url = "https://#{meta:host()}/ruleset/describe/#{$rids_string}";
      resp = http:get(describe_url);
      results = resp{"content"}.decode().defaultsTo("",standardError("content failed to return"));
      {
       'status'   : (resp{"status_code"} eq "200"),
       'description'     : results
      };
    }
    // add defaultsto for eci so it defaultsto meta:eci
    // everywhere installRulesets defaction will need a with eci for any out side 
    installRulesets = defaction(rids){
      configure using eci = meta:eci() and name="none";

      pico_eci = (name eq "none") => eci
                                   | picoECIFromName(name);

      new_ruleset = pci:new_ruleset(pico_eci, rids);
      send_directive("installed #{rids}");
    }
    
    uninstallRulesets = defaction(rids){
      configure using eci = meta:eci() and name="none";
      pico_eci = (name eq "none") => eci
                                   | picoECIFromName(name);

      deleted = pci:delete_ruleset(pico_eci, rids.klog("rids "));
      send_directive("uninstalled #{rids} in pico #{pico_eci}");
    }

// ********************************************************************************************
// ***                                      Channels                                        ***
// ******************************************************************************************** 
  
  //-------------------- Channels --------------------
  /* can be deleted after channel testing.
    internalChannel = function (value){
      eci = meta:eci();
      results = pci:list_eci(eci).defaultsTo({},standardError("undefined")); // list of ECIs assigned to userid
      channels = results{'channels'}.defaultsTo("error",standardError("undefined")); // list of channels if list_eci request was valid
      
      // if value is a number with ((([A-Z]|\d)*-)+([A-Z]|\d)*) attribute is eci.
      attribute = (value.match(re/(^(([A-Z]|\d)+-)+([A-Z]|\d)+$)/)) => 
              'eci' |
              'name';
      channel_list = channels.defaultsTo("no Channel",standardOut("no channel found, by channels"));
      filtered_channels = channel_list.filter(function(channel){
        (channel{attribute} eq value);}); 
      result = filtered_channels.head().defaultsTo("",standardError("no channel found, by .head()"));
      (result);
    }
  */
    nameFromEci = function(eci){ 
      //eci = meta:eci();
      results = channel(eci);
      channel_single = results{'channels'};
      channel_single{'name'};
    } 

    eciFromName = function(name){
      results = channel(name);
      channel_single = results{'channels'};
      channel_single{'eci'};
    }
    // always return a eci weather given a eci or name
    alwaysEci = function(value){
      eci = (value.match(re/(^(([A-Z]|\d)+-)+([A-Z]|\d)+$)/)) => 
              value |
              eciFromName(value);
      eci;       
    }
    // last created eci.
    lastCreatedEci = function(){
      channel = ent:lastCreatedEci;
      eci = channel{'cid'};
      eci
    }
    // takes name or eci as id returns single channle . needed for backwards combatablity 
    //
    channel = function(id,collection,filtered) { 
      eci = meta:eci();
      results = pci:list_eci(eci).defaultsTo({},standardError("undefined")); // list of ECIs assigned to userid
      chans = results{'channels'}.defaultsTo("error",standardError("undefined")); // list of channels if list_eci request was valid
      channels = chans.map(function(channel){ // reconstruct each channel to have eci not eci
                                          //  chan = channel.put(["eci"],channel{"eci"}); 
                                          //  chann = chan.delete(["eci"]);
                                          //  chann // return reconstructed channel 
                                            {
                                              "last_active":channel{"last_active"},
                                              "policy":channel{"policy"},
                                              "name":channel{"name"},
                                              "type":channel{"type"},
                                              "eci":channel{"cid"},
                                              "attributes":channel{"attributes"}
                                              } });
      single_channel = function(value,chans){
         // if value is a number with ((([A-Z]|\d)*-)+([A-Z]|\d)*) attribute is eci.
        attribute = (value.match(re/(^(([A-Z]|\d)+-)+([A-Z]|\d)+$)/)) => 
                'eci' |
                'name';
        channel_list = chans;
        filtered_channels = channel_list.filter(function(channel){
          (channel{attribute} eq value);}); 

        result = filtered_channels.head().defaultsTo({},standardError("no channel found, by .head()"));
        (result);
      };
      type = function(chan){ // takes a chans 
        group = (chan.typeof() eq 'hash')=> // for robustness check type.
        chan{collection} | 'error';
        (group);
      };
      return1 = collection.isnull() => channels |  channels.collect(function(chan){(type(chan));}) ;
      return2 = filtered.isnull() => return1 | return1{filtered};
      results = (id.isnull()) => return2 | single_channel(id,channels);
      {
        'status'   : (channels neq "error"),
        'channels' : results
      }.klog("channels");
    }
    channelAttributes = function(eci,name) {
      Eci = eci.defaultsTo(alwaysEci(name).defaultsTo('','no name or eci provided'),'no eci going with name') ;
      results = pci:get_eci_attributes(Eci
        //.klog("get_eci_attributes passed eci: ")
        ).defaultsTo("error",standardError("get_eci_attributes")); // list of ECIs assigned to userid
      {
        'status'   : (results neq "error"),
        'attributes' : results
      }.klog("attributes");
    }
    channelPolicy = function(eci,name) {
      Eci = eci.defaultsTo(alwaysEci(name).defaultsTo('','no name or eci provided'),'no eci going with name') ;
      results = pci:get_eci_policy(Eci).defaultsTo("error",standardError("undefined")); // list of ECIs assigned to userid
      {
        'status'   : (results neq "error"),
        'policy' : results
      }.klog("policy");
    }

    channelType = function(eci,name) { // old accounts may have different structure as there types, "type : types"
      Eci = eci.defaultsTo(alwaysEci(name).defaultsTo('','no name or eci provided'),'no eci going with name') ;
      getType = function(eci) { 
        type = pci:get_eci_type(eci).defaultsTo("error",standardError("undefined"));
        // this code below belongs higher up in software layer
       // temp = (type.typeof() eq "str" ) => type | type.typeof() eq "array" => type[0] |  type.keys();
       // type2 = (temp.typeof() eq "array") => temp[0] | temp;   
       // type2;
        type;
      };
      type = getType(Eci);
      {
        'status'   : (type neq "error"),
        'type' : type
      }.klog("type");
    }
    updateAttributes = defaction(value, attributes){
      eci = alwaysEci(value);
      set_eci = pci:set_eci_attributes(eci, attributes);
      send_directive("updated channel attributes for #{eci}");
    }
    updatePolicy = defaction(value, policy){
      eci = alwaysEci(value);
      set_polcy = pci:set_eci_policy(eci, policy); // policy needs to be a map, do we need to cast types?
      send_directive("updated channel policy for #{eci}");
    }
    updateType = defaction(value, type){
      eci = alwaysEci(value);
      set_type = pci:set_eci_type(eci, type); 
      send_directive("updated channel type for #{eci}");
    }
    // should delete all channels with that name.
    deleteChannel = defaction(value) {
      eci = alwaysEci(value);
      deleteeci = pci:delete_eci(eci);
      send_directive("deleted channel #{eci}");
    }
    createChannel = defaction(options){
      configure using eci = meta:eci();
      new_eci = pci:new_eci(eci, options);
      nonsense = new_eci.pset(ent:lastCreatedEci); // store eci in magic varible for use in post event. will change when defaction setting varible is implemented.
      send_directive("created channel #{new_eci}");
    }
// ********************************************************************************************
// ***                                      Picos                                           ***
// ******************************************************************************************** 
  //-------------------- Picos --------------------
   /// should children and parent functions return a map instead of an array??
  children = function() {
    self = meta:eci()
    //.klog("meta eci for list_children:  ")
    ;
    children = pci:list_children(self).defaultsTo("error", standardError("pci children list failed"));

    ent_my_children = ent:my_children;
    my_child_list = children.map(function(tuple)
                                          {
                                            this_eci = tuple[0];
                                            return1 = ent_my_children.filter(function(ent_child)
                                              {
                                                ent_child{"eci"} eq this_eci
                                              })
                                            //.klog("first filter: ")
                                            ;
                                            return = return1.length() > 0 => return1[0] | // if child with name return the name structure  
                                                              {  // if child with no name return with unknown name structure
                                                                "name": "unknown",
                                                                "eci": this_eci
                                                              }
                                            return
                                            //.klog("second filter: ")
                                          })
                                          //.klog("map : ")
                                          ;

    {
      'status' : (children neq "error"),
      'children' : my_child_list
    }
  }
  children_FixitFelix = function() {
    self = meta:eci().klog("meta eci for list_children:  ");
    children = pci:list_children(self).defaultsTo("error", standardError("pci children list failed"));
    ent_my_children = ent:my_children;
    my_child_list = children.map(function(tuple)
                                          {
                                            this_eci = tuple[0];
                                            return1 = ent_my_children.filter(function(ent_child)
                                              {
                                                ent_child{"eci"} eq this_eci
                                              }).klog("first filter: ");
                                            return = /*return1.length() > 0 => return1[0] |*/ pdsName(this_eci,return1[0]);// if child with name return the name structure  
                                                              
                                            return.klog("second filter: ")
                                          }).klog("map : ");
    foo = my_child_list.pset(ent:my_children)
    {
      'status' : (children neq "error"),
      'children' : my_child_list
    }
  }

  pdsName = function(this_eci,child) {
    results = skyQuery(this_eci, "b507199x5","name", null).klog("sky : ");// old wrangler ent:name 
    oldentnamestruc = results{"skyCloudError"}.isnull() => results | {"picoName":{}};
    oldentname = oldentnamestruc{"picoName"}.klog("child name");
    current_name = child{"name"}.typeof() eq 'str' => child{"name"}|"unknown";
    name = (oldentname.typeof() eq 'str') => oldentname | current_name;
    { 
      "name": name,
      "eci": this_eci
    }
  }

  parent = function() {
    self = meta:eci();
    parent = pci:list_parent(self).defaultsTo("error", standardError("pci parent retrieval failed"));
    {
      'status' : (parent neq "error"),
      'parent' : parent
    }
  }
  profile = function(key) {
    pds:profile(key);
  }
  pico = function(namespace) {
    {
      "profile" : pds:profile(),
      "settings" : pds:settings(),
      "general" : pds:items(namespace)
    }
  }

  // slows down website, and creates dependscies, store name as a ent in wrangler
  name = function() {
    //pdsProfiles = pds:profile();
    //pdsProfile = pdsProfiles{"profile"};
    //name = (pdsProfile.typeof() eq 'hash') => pdsProfile{"name"} | ent:name ;
    //name =  ent:name.defaultsTo("unknownName",standardError("pci parent retrieval failed"));
    return = ent:name ;
    {
     // 'status' : pdsProfiles{"status"},
      'status' : "",
      'picoName' : return
    }.klog("name :")
  }

  attributes = function() {
    {
      'status' : true,
      'attributes' : ent:attributes
    }
  }

  picoECIFromName = function (name) {
    pico = ent:my_children.filter(function(rec){rec{"name"} eq name})
                          .head()
    pico{"eci"}
  };

  
  deleteChild = defaction(name) {
    results = children();
    ent_my_children = results{"children"};
    child_rec = ent_my_children.filter(function(rec){rec{"name"} eq name})
                               .head()
             .defaultsTo({})
                               .klog("Child to delete: ");

    eci_to_delete = child_rec{"eci"};
    new_child_list = ent_my_children
                               .filter(function(rec){rec{"name"} neq name})
                               .klog("Children to keep: ")
             .pset(ent:my_children)
             ;

    noret = pci:delete_pico(eci_to_delete, {"cascade":1});
    send_directive("deleted pico #{eci_to_delete}");
  }
  
  basePrototype = {
      "meta" : {
                "discription": "Wrangler base prototype"
                },
                //array of maps for meta data of rids .. [{rid : id},..}  
      "rids": [ "v1_wrangler.dev",
                 "b507888x5.prod",
                "b507888x6.prod" // pds
                //"b507805x0.dev" developmet wrangler
                 //"a169x625"
              ],
      "channels" : [{
                      "name"       : "testPrototypChannel",
                      "type"       : "ProtoType",
                      "attributes" : "prototypes test attrs",
                      "policy"     : "not implemented"
                    },
                    {
                      "name"       : "test2PrototypChannel",
                      "type"       : "ProtoType",
                      "attributes" : "prototypes test attrs",
                      "policy"     : "not implemented"
                    }
                    ], // could be [["","","",""]], // array of arrrays [[name,type,attributes,policy]]
                    // belongs in relationManager 
      "subscriptions_request": [{
                                  "name"          : "basePrototypeName",
                                  "name_space"    : "basePrototypeNameSpace",
                                  "my_role"       : "son",
                                  "subscriber_role"     : "test",
                                  "subscriber_eci"    : "1654165",
                                  "channel_type"  : "ProtoType",
                                  "attrs"         : "nogiven"
                                }],
      "Prototype_events" : [{
                              'domain': 'wrangler',
                              'type'  : 'base_prototype_event1',
                              'attrs' : {'attr1':'1',
                                          'attr2':'2'
                                        }
                            },
                            {
                              'domain': 'wrangler',
                              'type'  : 'base_prototype_event2',
                              'attrs' : {'attr1':'1',
                                          'attr2':'2'
                                        }
                            },
                            {
                              'domain': 'wrangler',
                              'type'  : 'base_prototype_event3',
                              'attrs' : {'attr1':'1',
                                          'attr2':'2'
                                        }
                            }
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
                "settings": {"b507798x0.dev":{
                                              "name":"wrangler",
                                              "rid" :"b507798x0.dev",
                                              "data":{},
                                              "schema":["im","a","schema"],
                                              "attr":"first_key",
                                              "value":"first_value"
                                              }
                            }
              }
  };


// intialize ent;prototype, check if it has a prototype and default to hard coded prototype

// we will store base prototypes as hard coded varibles with, 
  prototypes = function() {
    init_prototypes = ent:prototypes || {}; // if no prototypes set to map so we can use put()
    prototypes = init_prototypes.put(['base'],basePrototype);
    {
      'status' : true,
      'prototypes' : prototypes
    }
  };

// create a ent:prototype_at_creationg, ent:predefined_prototype. 
// at creation wrangler will create child and send protype to child and 
// then wrangle in the child will handle the creation of the pico and its prototypes
// protype has a meta, rids, channels, events( creation events ) 

// create child from protype will take the name with a option of a prototype with a default to base.
  createChild = defaction(name){ 
    configure using protype_name = "base"; // base must be installed by default for prototypeing to work 
    results = prototypes(); // get prototype from ent varible and default to base if not found.
    prototypes = results{"prototypes"};
    prototype = prototypes{protype_name}.defaultsTo(basePrototype,"prototype not found").klog("prototype: ");
    rids = prototype{"rids"};
    // create child and give name
    attributes = {
      "name": name,
      "prototype": prototype.encode()
    };
    // create child 
    newPicoInfo = pci:new_pico(meta:eci()); // we need pci updated to take a name.
    newPicoEci = newPicoInfo{"cid"};// store child eci
    // store name
    child_rec = {"name": name,
                 "eci": newPicoEci
                };
    my_children = ent:my_children => ent:my_children | []; // first child
    foo = my_children.append(child_rec)
                     .klog("New Child List: ")
         .pset(ent:my_children);
    // bootstrap child
    //combine new_ruleset calls 
    joined_rids_to_install = prototype_name eq "base" =>  basePrototype{"rids"}  |   basePrototype{"rids"}.append(rids);
    a = pci:new_ruleset(newPicoEci,joined_rids_to_install.klog('rids to be installed in child: ')); // install base/prototype rids (bootstrap child) 
    // update child ent:prototype_at_creation with prototype
    event:send({"eci":newPicoEci}, "wrangler", "create_prototype") // event to child to handle prototype creation 
      with attrs = attributes
  }

// ********************************************************************************************
// ***                                      Subscriptions                                   ***
// ******************************************************************************************** 
// 
// this comment could break the kre server.
  //-------------------- Subscriptions ----------------------
    // name subscriptions and add results status 
    allSubscriptions = function (){// slow, whats a better way to prevent channel call, bigO(n^2)
      // list of channels
      channels_result = channel();
      channel_list = channels_result{'channels'};
      // filter list channels to only have subs
      filtered_channels = channel_list.filter( function(channel){
        isSubscription = function(channel) {
            attributes = channel{'attributes'};
            (attributes.isnull()) => null |
            (attributes{'subscription_name'}.isnull() eq false); 
          };
        isSubscription(channel)
        //.klog("isSubscriptions(): ")
        ;

      }); 
      // reconstruct list, to have a inbound in attributes.
      subs = filtered_channels.map( function(channel){
           channel.put(["attributes","inbound_eci"],channel{"eci"})
                  .put(["attributes","channel_name"],channel{"name"}); // hard to get channel name when its the key... so we add it here.
      });
      // name to attributes hash
      subsript = subs.map( function(channel){
      //    {channel{'name'}:channel{'attributes'}}
          attributes = channel{'attributes'};
          //subscription_name = attributes{'subscription_name'};
          {
            attributes{'subscription_name'} : attributes
          }
      });
      /*  
      {"18:floppy" :
          {"status":"inbound","relationship":"","name_space":"18",..}
      */
      subsript;
    };

    subscriptions = function(id,collection,filtered) { 
      subsript = allSubscriptions();
      /*  
      {"18:floppy" :
          {"status":"inbound","relationship":"","name_space":"18",..}
      */
     //types = ['name','channel_name','inbound','name_space','relationship',....] could check imput for validness. 
      type = function(sub,collection_parameter){ // takes a subscription and returns its status.
        value = sub.values(); // array of values [attributes]
        attributes = value.head(); // get attributes
        group = (attributes.typeof() eq 'hash')=> // for robustness check type.
        attributes{collection_parameter} | 'error';
        (group);
      };

      single_subscription = function(value,subs){
         // if value is a number with ((([A-Z]|\d)*-)+([A-Z]|\d)*) attribute is eci.
        parts = value.split(re/:/)
        //.klog('parts of id')
        ;
        attribute = (value.match(re/(^(([A-Z]|\d)+-)+([A-Z]|\d)+$)/)) => 
                'inbound_eci' |
                (parts.length() > 1) => // channel name of subscriptions are namespace:subscription_name 
                   "channel_name" // is channel name
                   | "subscription_name";  // is subscription name
        subscription_list = subs;
        filtered_subscriptions = subscription_list.filter(function(subscription){
          attr_value = type(subscription,attribute
            //.klog('attribute ')
            )
            //.klog('types function: ')
          ;
          (attr_value eq value)
          //.klog('found ? ')
          ;
          }); 

        result = filtered_subscriptions
        //.klog('filtered_subscriptions: ')
                .head()
                //.klog('head: ') 
                .defaultsTo({},standardError("no subscription found, by .head()"));
        (result);
      };

      return1 = collection.isnull() => subsript |  subsript.collect(function(sub){(type(sub,collection));}) ;
      return2 = filtered.isnull() => return1 | return1{filtered};
      results = (id.isnull()) => return2 | single_subscription(id,subsript);
      {
        'status' : (subscriptions neq "error"),
        'subscriptions'  : results
      }.klog('return: ');

    };

   /* randomName = function(namespace){
        n = 5;
        array = (0).range(n).map(function(n){
          (random:word());
          });
        names= array.collect(function(name){
          (checkName( namespace +':'+ name )) => "unique" | "taken";
        });
        name = names{"unique"} || [];

        unique_name =  name.head().defaultsTo("",standardError("unique name failed"));
        (namespace +':'+ unique_name);
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
          return = encoded_chan.match(re/{}/);
          (return);
    }

    randomPicoName = function(){
        n = 5;
        array = (0).range(n).map(function(n){
          (random:word());
          });
        names= array.collect(function(name){
          (checkPicoName( name )) => "unique" | "taken";
        });
        name = names{"unique"} || [];

        unique_name =  name.head().defaultsTo("",standardError("unique name failed"));
        (unique_name).klog("results : ");
    }

    checkPicoName = function(name){
          return = children();
          picos = return{"children"};
          
          names = picos.none(function(child){
            eci = child[0]; 
            name_return = skyQuery(eci,meta:host(),"v1_wrangler.dev","name",noParam);
            pico_name = name_return{"picoName"};
            (pico_name eq name)
            });
          (names).klog("results : ");

    }      
    checkSubscriptionName = function(name,name_space){
        checkName(name_space + ":" + name);


          //sub = subscriptions( null, "name_space", name_space);
          //subs = sub{"subscriptions"};//array
          //sub = subs.filter( function(subcription){
          //                            sub_values = subcription.values();
          //                            (sub_values{"subscription_name"} eq name)
          //  });

          //b = subs => "true" | "false";
          //encoded_sub = subs.encode().klog("encode subs :");
          //return = encoded_sub.match(re/{}/);
          //(subs eq {});
          //return.klog("results : ");

    }
    // this only creates 5 random names, if none are unique the function will fail.... but thats unlikely. 

    randomSubscriptionName = function(name_space){
        n = 5;
        array = (0).range(n).map(function(n){
          (random:word());
          });
        names= array.collect(function(name){
          (checkSubscriptionName( name, name_space )) => "unique" | "taken";
        });
        name = names{"unique"} || [];

        unique_name =  name.head().defaultsTo("",standardError("unique name failed"));
        (unique_name);
    }

    // takes name or eci 
    subscriptionAttributes = function (name_or_eci){ // should be named different, missleading, its more like parameters
      eci = (name_or_eci.match(re/(^(([A-Z]|\d)+-)+([A-Z]|\d)+$)/)) => 
              name_or_eci |
              eciFromName(name_or_eci);
      results = channelAttributes(eci,unknownName);
      attributes = results{'attributes'};
      attributes;
    } 


    /*findVehicleByinbound = function (bc) {
       garbage = bc.klog(">>>> back channel <<<<<");
       vehicle_ecis = wrangler:subscriptionList(common:namespace(),"Vehicle");
        vehicle_ecis_by_inbound = vehicle_ecis
                                        .collect(function(x){x{"inbound"}})
                                     .map(function(k,v){v.head()})
                                        ;
    vehicle_ecis_by_inbound{bc} || {}
     };*/

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
      decoded_value = value.decode().klog('decoded_value: ');
      error = decoded_value{'error'};
      return = (error.typeof() eq "array") =>  error[0].defaultsTo(decoded_value,'decoded: ') | decoded_value;
      return.klog('return: ');
    }
  }
  // string or array return array 
  // string or array return string

// ********************************************************************************************
// ***                                      Rules                                           ***
// ********************************************************************************************



// ********************************************************************************************
// ***                                      Rulesets                                        ***
// ********************************************************************************************
  //------------------------------------------------------------------------------------Rules
  //-------------------- Rulesets --------------------
  
  rule installRulesets {
    select when wrangler install_rulesets_requested
    pre { 
     // eci = meta:eci();
      rids = event:attr("rids").defaultsTo("",standardError(" "));
      // this will never get an array from a url/event ?
      rid_list = rids.typeof() eq "array" => rids | rids.split(re/;/); 
    }
    if(rids neq "") then { // should we be valid checking?
      installRulesets(rid_list);
    }
    fired {
      log (standardOut("success installed rids #{rids}"));
      log(">> successfully  >>");
          } 
    else {
      log(">> could not install rids #{rids} >>");
    }
  }
  rule uninstallRulesets { // should this handle multiple uninstalls ??? 
    select when wrangler uninstall_rulesets_requested
    pre {
     // eci = meta:eci();
      rids = event:attr("rids").defaultsTo("", ">>  >> ")
      //.klog(">> rids attribute <<")
      ;
      rid_list = rids.typeof() eq "array" => rids | rids.split(re/;/); 
    }
    { 
      uninstallRulesets(rid_list);
    }
    fired {
      log (standardOut("success uninstalled rids #{rids}"));
      log(">> successfully  >>");
          } 
    else {
      log(">> could not uninstall rids #{rids} >>");
    }
  }
 
// ********************************************************************************************
// ***                                      Channels                                        ***
// ********************************************************************************************
 //-------------------- Channels --------------------
  rule createChannelFromMetaEci {
    select when wrangler channel_creation_requested where eci.isnull() eq true
    pre {
      event_attributes = event:attrs();
      //eci = event:attr("eci").defaultsTo(meta:eci(), standardError("no eci provided"));
     // eci = event:attr("eci").defaultsTo(meta:eci(), standardError("no eci provided"));
    /*  <eci options>
    name     : <string>        // default is "Generic ECI channel" 
    eci_type : <string>        // default is "PCI"
    attributes: <array>
    policy: <map>  */
      channel_name = event:attr("channel_name").defaultsTo('', standardError("missing event attr channels"));
      type = event:attr("channel_type").defaultsTo("Unknown", standardError("missing event attr channel_type"));
      attributes = event:attr("attributes").defaultsTo("", standardError("missing event attr attributes"));
      attrs =  decodeDefaults(attributes);
      policy = event:attr("policy").defaultsTo("", standardError("missing event attr attributes"));
      // do we need to check if we need to decode ?? what would we check?
      decoded_policy = policy.decode() || policy;
      options = {
        'name' : channel_name,
        'eci_type' : type,
        'attributes' : {"channel_attributes" : attrs},
        'policy' : decoded_policy//{"policy" : policy}
      }.klog('options for channel cration');
          }
          // do we need to check the format of name? is it wrangler's job?
    if(checkName(channel_name)) then  //channel_name.match(re/\w[\w-]*/)) then 
          { 
      createChannel(options);
          }
    fired {
      log (standardOut("success created channels #{channel_name}"));
      log(">> successfully  >>");
      raise wrangler event 'channel_created' // event to nothing  
            attributes event_attributes.put(['eci'],lastCreatedEci().klog("lastCreatedEci: ")); // function to access a magic varible set during creation
          } 
    else {
      error warn "douplicate name, failed to create channel"+channel_name;
      log(">> could not create channels #{channel_name} >>");
          }
    }

  rule createChannelFromGivenEci {
    select when wrangler channel_creation_requested where eci.isnull() eq false
    pre {
      event_attributes = event:attrs();
      //eci = event:attr("eci").defaultsTo(meta:eci(), standardError("no eci provided"));
      eci = event:attr("eci").defaultsTo(meta:eci(), standardError("no eci provided")); // should never default 
    /*  <eci options>
    name     : <string>        // default is "Generic ECI channel" 
    eci_type : <string>        // default is "PCI"
    attributes: <array>
    policy: <map>  */
      channel_name = event:attr("channel_name").defaultsTo('', standardError("missing event attr channels"));
      type = event:attr("channel_type").defaultsTo("Unknown", standardError("missing event attr channel_type"));
      attributes = event:attr("attributes").defaultsTo("", standardError("missing event attr attributes"));
      attrs =  decodeDefaults(attributes);
      policy = event:attr("policy").defaultsTo("", standardError("missing event attr attributes"));
      // do we need to check if we need to decode ?? what would we check?
      decoded_policy = policy.decode() || policy;
      options = {
        'name' : channel_name,
        'eci_type' : type,
        'attributes' : {"channel_attributes" : attrs},
        'policy' : decoded_policy//{"policy" : policy}
      }.klog('options for channel cration');
          }
          // do we need to check the format of name? is it wrangler's job?
    if(checkName(channel_name)) then  //channel_name.match(re/\w[\w-]*/)) then 
          { 
      createChannel(options) with eci = eci;
          }
    fired {
      log (standardOut("success created channels #{channel_name}"));
      log(">> successfully  >>");
      raise wrangler event 'channel_created' // event to nothing  
            attributes event_attributes.put(['eci'],lastCreatedEci().klog("lastCreatedEci: ")); // function to access a magic varible set during creation
          } 
    else {
      error warn "douplicate name, failed to create channel"+channel_name;
      log(">> could not create channels #{channel_name} >>");
          }
    }

 // we should add a append / modifie channel attributes rule set.
 //  takes in new and modified values and puts them in.
  rule updateChannelAttributes {
    select when wrangler update_channel_attributes_requested
    pre {
      value = event:attr("eci").defaultsTo(event:attr("name").defaultsTo("", standardError("missing event attr eci or name")), standardError("looking for name instead of eci."));
      attributes = event:attr("attributes").defaultsTo("error", standardError("undefined"));
      //attrs = attributes.split(re/;/);
      attrs =  decodeDefaults(attributes);
      attrs_two = {"channel_attributes" : attrs};
      //channels = Channel();
    }
    if(value neq "" && attributes neq "error") then { // check?? redundant????
      updateAttributes(value.klog('value: '),attrs_two);
    }
    fired {
      log (standardOut("success updated channel #{value} attributes"));
      log(">> successfully >>");
    } 
    else {
      log(">> could not update channel #{value} attributes >>");
    }
  }

  rule updateChannelPolicy {
    select when wrangler update_channel_policy_requested // channel_policy_update_requested
    pre {
      value = event:attr("eci").defaultsTo(event:attr("name").defaultsTo("", standardError("missing event attr eci &| name")), standardError("looking for name instead of eci."));
      policy_string = event:attr("policy").defaultsTo("error", standardError("undefined"));// policy needs to be a map, do we need to cast types?
      policy = decodeDefaults(policy_string);
    }
    if(value neq "" && policy neq "error") then { // check?? redundant?? whats better??
      updatePolicy(value.klog('value: '), policy);
    }
    fired {
      log (standardOut("success updated channel #{value} policy"));
      log(">> successfully  >>");
    }
    else {
      log(">> could not update channel #{value} policy >>");
    }

  }


  rule updateChannelType {
    select when wrangler update_channel_type_requested 
    pre {
      value = event:attr("eci").defaultsTo(event:attr("name").defaultsTo("", standardError("missing event attr eci or name")), standardError("looking for name instead of eci."));
      //eci = event:attr("eci").defaultsTo("", standardError("missing event attr channels")); // should we force... use meta:eci()
      type = event:attr("channel_type").defaultsTo("error", standardError("undefined"));// policy needs to be a map, do we need to cast types?
    }
    if(eci neq "" && type neq "error") then { // check?? redundant?? whats better??
      updateType(value.klog('value: '), type);
    }
    fired {
      log (standardOut("success updated channel #{eci} type"));
      log(">> successfully  >>");
    }
    else {
      log(">> could not update channel #{eci} type >>");
    }

  }

  rule deleteChannel {
    select when wrangler channel_deletion_requested
    pre {
      value = event:attr("eci").defaultsTo(event:attr("name").defaultsTo("", standardError("missing event attr eci or name")), standardError("looking for name instead of eci."));
    }
    {
      deleteChannel(value.klog('value: '));
    }
    fired {
      log (standardOut("success deleted channel #{value}"));
      log(">> successfully  >>");
    } 
   // else { -------------------------------------------// can we reach this point?
    //  log(">> could not delete channel #{value} >>");
   //    }
  }
  

  
// ********************************************************************************************
// ***                                      Picos                                           ***
// ********************************************************************************************


  //-------------------- Picos initializing  ----------------------
  rule createChild { 
    select when wrangler child_creation
    pre {
      attribute = event:attrs();
      name = event:attr("name").defaultsTo(randomPicoName(),standardError("missing event attr name, random word used instead."));
      prototype = event:attr("prototype").defaultsTo("devtools", standardError("missing event attr prototype"));           
    }

   // if(checkPicoName(name)) then 
    {
      createChild(name) with protype_name = prototype; 
    }
    fired {
      log(standardOut("pico created with name #{name}"));
    }
    else{
      error warn " douplicate Pico name, failed to create pico named "+name;
    }
  }
   
  rule initializePrototype { 
    select when wrangler create_prototype //raised from parent in new child
    pre {
      prototype_at_creation = event:attr("prototype").decode(); // no defaultto????
      pico_name = event:attr("name");
    }
    {
      noop();
    }
    
    always {
      log("inited prototype");
      set ent:prototypes{['at_creation']} prototype_at_creation;
      set ent:name pico_name;
      raise wrangler event "init_events"
            attributes {};
    }
  }

// ********************************************************************************************
// ***                                      Base Dependancys                                ***
// ********************************************************************************************

// ---------------------- base channels creation ----------------------
  rule initializeBaseChannels {
    select when wrangler init_events 
      foreach basePrototype{'channels'}.klog("Prototype base channels : ") setting (PT_channel)
    pre {
      attrs = {
                  "channel_name" : PT_channel{"name"},
                  "channel_type" : PT_channel{"type"},
                  "attributes"   : PT_channel{"attributes"},
                  "policy"       : PT_channel{"policy"}
              };
    }
    {
      noop();
    }
    always {
      log("init pds");
      raise wrangler event "channel_creation_requested" 
            attributes attrs.klog("attributes : ")
    }
  }

// ---------------------- base subscription creation ----------------------
  rule initializebaseSubscriptions {
    select when wrangler init_events 
      foreach basePrototype{'subscriptions_request'}.klog("Prototype base subscriptions_request: ") setting (subscription)
    pre {
      attrs = subscription;
    }
    {
      noop();
    }
    always {
      log("init pds");
      raise wrangler event "subscription" 
            attributes attrs.klog("attributes : ")
    }
  }
// ********************************************************************************************
// ***                                      Prototype Depandancies                          ***
// ********************************************************************************************
// ---------------------- prototype channels creation -----------------------
  rule initializePrototypeChannels {
    select when wrangler init_events 
      foreach ent:prototypes{['at_creation','channels']}.klog("Prototype_channels : ") setting (PT_channel)
    pre {
      attrs = {
                  "channel_name" : PT_channel{"name"},
                  "channel_type" : PT_channel{"type"},
                  "attributes"   : PT_channel{"attributes"},
                  "policy"       : PT_channel{"policy"}
              };
    }
    {
      noop();
    }
    always {
      log("init pds");
      raise wrangler event "channel_creation_requested" 
            attributes attrs.klog("attributes : ")
    }
  }
// ---------------------- prototype subscription creation ----------------------
  rule initializePrototypeSubscriptions {
    select when wrangler init_events 
      foreach ent:prototypes{['at_creation','subscriptions_request']}.klog("Prototype subscriptions_request: ") setting (subscription)
    pre {
      attrs = subscription;
    }
    {
      noop();
    }
    always {
      log("init pds");
      raise wrangler event "subscription" 
            attributes attrs.klog("attributes : ")
    }
  }
// ********************************************************************************************
// ***                                      PDS  Base Initializing                               ***
// ********************************************************************************************

  rule initializeProfile {// this rule should build pds data structure
    select when wrangler init_events
    pre {
      attrs = basePrototype{['PDS','profile']};
    }
    {
      noop();
    }
    always {
    raise pds event updated_profile 
            attributes attrs
    }
  }

  rule storeGeneralOps {
    select when wrangler init_events 
    pre {
      ops =  basePrototype{['PDS','general']}.length();
    }
    {
      noop();
    }
    always {
      set ent:general_operations ops;
      raise wrangler event init_general // init general  
            attributes {}
    }
  }

  rule initializeGeneral {
    select when wrangler init_general
      foreach basePrototype{['PDS','general']}.klog("PDS General: ") setting (namespace) 
    pre {
      key_array = namespace.keys();
      mapedvalues = namespace.values();
      maps= mapedvalues[0];
      attrs = {
        'namespace': key_array[0],
        'mapvalues': maps.encode()
      };
    }
    {
      noop();
    }
    always {
      raise pds event map_item // init general  
            attributes attrs
    }
  }
  rule storeSettingsOps {
    select when wrangler init_events 
    pre {
      ops =  basePrototype{['PDS','settings']}.length();
    }
    {
      noop();
    }
    always {
      set ent:settings_operations ops;
      raise wrangler event init_settings // init settings  
            attributes {}
    }
  }
  rule initializePdsSettings {
    select when wrangler init_settings
      foreach basePrototype{['PDS','settings']}.klog("PDS settings: ") setting (rid) 
    pre {
      //key_array = rid.keys();
      mapedvalues = rid.values();
      attrs= mapedvalues[0];
    }
    {
      noop();
    }
    always {
    raise pds event add_settings 
            attributes attrs
    }
  }

// ********************************************************************************************
// ***                                      Event Barrier                                   ***
// ********************************************************************************************
 
  // since we use for each to initialize the pds, we can not use a the single raised events from pds for our barrier. this barrier will have to be re-constructed.
  //this will fire every so offten during a picos life
  rule initializedBarrierA{// after base pds is initialize update prototype pds and raise prototype events
    select when count ent:general_operations (pds new_map_added) // general inited
    pre {
    }
    {
      noop();
    }
    always {
    raise wrangler event new_map_added  
            attributes {}
    }
  }
  //this will fire every so offten during a picos life
  rule initializedBarrierB{// after base pds is initialize update prototype pds and raise prototype events
    select when count ent:settings_operations (pds settings_added) // settings inited
    pre {
    }
    {
      noop();
    }
    always {
    raise wrangler event settings_added  
            attributes {}
    }
  }
    rule initializedBarrierC{// after base pds is initialize update prototype pds and raise prototype events
    select when wrangler new_map_added // general inited
            and pds profile_updated // profile inited
            and wrangler settings_added // settings inited
            and wrangler init_events // only fire when the pico is created
    pre {
    }
    {
      noop();
    }
    always {
    raise wrangler event pds_inited  
            attributes {}
    }
  }
// ********************************************************************************************
// ***                                      PDS  Prototype Updates                          ***
// ********************************************************************************************


  rule updatePrototypeProfile {
    select when wrangler pds_inited
    pre {
      attrs = ent:prototypes{['at_creation','PDS','profile']};
    }
    {
      noop();
    }
    always {
    raise pds event updated_profile // init prototype  // rule in pds needs to be created.
            attributes attrs
    }
  }
  rule updatePrototypeGeneral {
    select when wrangler pds_inited 
      foreach ent:prototypes{['at_creation','PDS','general']}.klog("Prototype PDS general: ") setting (namespace) 
    pre {
      key_array = namespace.keys();
      mapedvalues = namespace.values();
      maps= mapedvalues[0];
      attrs = {
        'namespace': key_array[0],
        'mapvalues': maps.encode()
      };
    }
    {
      noop();
    }
    always {
      raise pds event map_item  
            attributes attrs
    }
  }

  rule updatePrototypePdsSettings {// this rule should build pds data structure
    select when wrangler pds_inited
    pre {
      attrs = ent:prototypes{['at_creation','PDS','settings']};
    }
    {
      noop();
    }
    always {
    raise pds event updated_profile // init prototype  // rule in pds needs to be created.
            attributes attrs
    }
  }

// ********************************************************************************************
// ***                                   Base Custom Events                                 ***
// ********************************************************************************************


  rule raiseBaseEvents {
    select when wrangler pds_inited
    foreach basePrototype{['Prototype_events']} setting (Prototype_event)
    pre {
      Prototype_domain = Prototype_event{'domain'};
      Prototype_type = Prototype_event{'type'};
      Prototype_attrs = Prototype_event{'attrs'};
    }
    {
      noop();
    }
    always {
    raise wrangler event Prototype_type 
            attributes Prototype_attrs
    }
  }

// ********************************************************************************************
// ***                                    Prototype Custom Events                           ***
// ********************************************************************************************

  rule raisePrototypeEvents {
    select when wrangler pds_inited
    foreach ent:prototypes{['at_creation','Prototype_events']} setting (Prototype_event)
    pre {
      Prototype_domain = Prototype_event{'domain'};
      Prototype_type = Prototype_event{'type'};
      Prototype_attrs = Prototype_event{'attrs'};
    }
    {
      noop();
    }
    always {
    raise wrangler event Prototype_type 
            attributes Prototype_attrs
    }
  }

// ********************************************************************************************
// ***                                    Prototypes Management                             ***
// ********************************************************************************************

  rule addPrototype {
    select when wrangler add_prototype
            or  wrangler update_prototype
    pre {
      prototype = event:attr("prototype").klog("prototype: ");
      proto_obj = prototype.decode().klog("decoded_proto: ");
      prototype_name = event:attr("prototype_name");
    }
    // should we always add something?
    {
      noop();
    }
    always {
      set ent:prototypes{[prototype_name]} proto_obj;
    raise wrangler event Prototype_type_added 
            attributes event:attrs();
    }
  }
 /* rule updatePrototype {
    select when wrangler update_prototype
    pre {
      prototype = event:attr("prototype");
      prototype_name = event:attr("prototype_name");
    }
    {
      noop();
    }
    always {
      set ent:prototypes{prototype_name} prototype;
    raise wrangler event Prototype_type_updated
            attributes event:attrs();
    }
  }*/
  rule removePrototype {
    select when wrangler remove_prototype
    pre {
      prototype_name = event:attr("prototype_name");
    }
    {
      noop();
    }
    always {
      clear ent:prototypes{prototype_name} ;
    raise wrangler event Prototype_type_removed 
            attributes event:attrs();
    }
  }
  rule deleteChild {
    select when wrangler child_deletion
    pre {
      pico_name = event:attr("pico_name").defaultsTo("", standardError("missing pico name for deletion"));
    }
    if(pico_name neq "") then
    {
      deleteChild(pico_name);
    }
    notfired {
      log "deletion failed because no child was specified";
    }
  }

// ********************************************************************************************
// ***                                      Subscriptions                                   ***
//                                         _
//                                        ==(W{==========-      /===-
//                                          ||  (.--.)         /===-_---~~~~~~~~~------____
//                                          | \_,|**|,__      |===-~___                _,-' `
//                             -==\\        `\ ' `--'   ),    `//~\\   ~~~~`---.___.-~~
//                         ______-==|        /`\_. .__/\ \    | |  \\           _-~`
//                   __--~~~  ,-/-==\\      (   | .  |~~~~|   | |   `\        ,'
//                _-~       /'    |  \\     )__/==0==-\<>/   / /      \      /
//              .'        /       |   \\      /~\___/~~\/  /' /        \   /'
//             /  ____  /         |    \`\.__/-~~   \  |_/'  /          \/'
//            /-'~    ~~~~~---__  |     ~-/~         ( )   /'        _--~`
//                              \_|      /        _) | ;  ),   __--~~
//                                '~~--_/      _-~/- |/ \   '-~ \
//                               {\__--_/}    / \\_>-|)<__\      \
//                               /'   (_/  _-~  | |__>--<__|      |
//                              |*  */) )-~     | |__>--<__|      |
//                              / /~ ,_/       / /__>---<__/      |
//                             o-o _//        /-~_>---<__-~      /
//                             (^(~_/        /~_>---<__-      _-~
//                            ,/|           /__>--<__/     _-~
//                         ,//('(          |__>--<__|     /                  .----_
//                        ( ( '))          |__>--<__|    |                 /' _---_~\
//                     `-)) )) (           |__>--<__|    | -Tua Xiong    /'  /     ~\`\
//                    ,/,'//( (             \__>--<__\    \            /'  //        ||
//                  ,( ( ((, ))              ~-__>--<_~-_  ~--____---~' _/'/        /'
//                `~/  )` ) ,/|                 ~-_~>--<_/-__       __-~ _/
//              ._-~//( )/ )) `                    ~~-'_/_/ /~~~~~~~__--~
//               ;'( ')/ ,)(                              ~~~~~~~~~~
//              ' ') '( (/
// ***            '   '  `                   HERE BE DRAGONS                                ***
// ********************************************************************************************

  //-------------------- Subscriptions ----------------------http://developer.kynetx.com/display/docs/Subscriptions+in+the+wrangler+Service
  /* 
   ========================================================================
   No Persistent Variables for subscriptions, subscriptions information is stored in the "inbound" Channels attributes varible
    inbound : {
        type: <string>
        name: <string>
        policy: ?? // not used.
        attrs: {
          (Subscription attributes) 
           "name"  : <string>,
           "name_space": <string>,
           "relationship" : <string>,
           "subscriber_eci": <string>, // this is only stored in the origanal requestie
           "outbound_eci" : <string>,
           "attributes" : <string>, // this will be a object(mostlikely an array) that has been encoded as a string. 
           "status": <string> // discribes subscription status, incouming, outgoing, subscribed
        }
    }
    ========================================================================
   */
  // inbound not backchannel 
  // outbound not target 
  // my_role
  // subscriber_role

  rule subscribeNameCheck {
    select when wrangler subscription
    pre {
      name_space = event:attr("name_space");
      name   = event:attr("name").defaultsTo(randomSubscriptionName(name_space), standardError("channel_name"));
      attr = event:attrs();
      attrs = attr.put({"name":name});
    }
    if(checkSubscriptionName(name,name_space)) then
    {
      noop();
    }
    fired{
      raise wrangler event 'checked_name_subscription'
       attributes attrs
    }
    else{
      error warn "douplicate subscription name, failed to send request "+name;
      log(">> could not send request #{name} >>");
    }
  }

   // creates inbound and sends event for other pico to create inbound.
  rule subscribe {// need to change varibles to snake case.
    select when wrangler checked_name_subscription
   pre {
      // attributes for inbound attrs
      name   = event:attr("name").defaultsTo("standard", standardError("channel_name"));
      name_space     = event:attr("name_space").defaultsTo("shared", standardError("name_space"));
      my_role  = event:attr("my_role").defaultsTo("peer", standardError("my_role"));
      subscriber_role  = event:attr("subscriber_role").defaultsTo("peer", standardError("subscriber_role"));
      subscriber_eci = event:attr("subscriber_eci").defaultsTo("no_subscriber_eci", standardError("subscriber_eci"));
      channel_type      = event:attr("channel_type").defaultsTo("subs", standardError("type"));
      //status      = event:attr("status").defaultsTo("status", standardError("status ")); 
      attributes = event:attr("attrs").defaultsTo("status", standardError("status "));

     // // destination for external event
      subscription_map = {
            "eci" : subscriber_eci
      };
      // create unique_name for channel
      //unique_name = randomName(name_space);
      unique_name = name_space + ":" + name;

      // build pending subscription entry

      pending_entry = {
        "subscription_name"  : name,
        "name_space"    : name_space,
        "relationship" : my_role +"<->"+ subscriber_role, 
        "my_role" : my_role,
        "subscriber_role" : subscriber_role,
        "subscriber_eci"  : subscriber_eci, // this will remain after accepted
        "status" : "outbound", // should this be passed in from out side? I dont think so.
        "attributes" : attributes
      }; 
      //create call back for subscriber     
      options = {
          'name' : unique_name, 
          'eci_type' : channel_type,
          'attributes' : pending_entry
          //'policy' : ,
      };
    }
    if(subscriber_eci neq "no_subscriber_eci") // check if we have someone to send a request too
    then
    {

      createChannel(options);// just use meta:eci()??

      event:send(subscription_map, "wrangler", "pending_subscription") // send request
        with attrs = {
          "name"  : name,
          "name_space"    : name_space,
          "relationship" : subscriber_role +"<->"+ my_role ,
          "my_role" : subscriber_role,
          "subscriber_role" : my_role,
          "outbound_eci"  : eciFromName(unique_name), 
          "status" : "inbound",
          "channel_type" : channel_type,
          "attributes" : attributes
        };
    }
    fired {
      log (standardOut("success"));
      log(">> successful >>");
      raise wrangler event pending_subscription
        with status = pending_entry{'status'}
        and channel_name = unique_name
        and subscription_name = pending_entry{'subscription_name'}
        and name_space = pending_entry{'name_space'}
        and relationship = pending_entry{'relationship'}  
        and my_role = pending_entry{'my_role'}
        and subscriber_role = pending_entry{'subscriber_role'}
        and subscriber_eci  = pending_entry{'subscriber_eci'}
        and attributes = pending_entry{'attributes'};
      log(standardOut("failure")) if (unique_name eq "");
    } 
    else {
      log(">> failure >>");
    }
  }
  // creates back channel if needed, then it adds pending subscription to list of subscriptions.
  // can we put all this in a map and pass it as a attr? the rules internal.
  rule addPendingSubscription { // depends on wether or not a channel_name is being passed as an attribute
    select when wrangler pending_subscription
   pre {
        channel_name = event:attr("channel_name").defaultsTo("SUBSCRIPTION", standardError("channel_name")); // never will defaultto
        channel_type = event:attr("channel_type").defaultsTo("SUBSCRIPTION", standardError("type")); // never will defaultto
        status = event:attr("status").defaultsTo("", standardError("status"));
      pending_subscriptions = (status eq "inbound") =>
         {
            "subscription_name"  : event:attr("name").defaultsTo("", standardError("")),
            "name_space"    : event:attr("name_space").defaultsTo("", standardError("name_space")),
            "relationship" : event:attr("relationship").defaultsTo("", standardError("relationship")),
            "my_role" : event:attr("my_role").defaultsTo("", standardError("my_role")),
            "subscriber_role" : event:attr("subscriber_role").defaultsTo("", standardError("subscriber_role")),
            "outbound_eci"  : event:attr("outbound_eci").defaultsTo("", standardError("outbound_eci")),
            "status"  : event:attr("status").defaultsTo("", standardError("status")),
            "attributes" : event:attr("attributes").defaultsTo("", standardError("attributes"))
          } |
          {};
          // should this go into the hash above?
      unique_name = (status eq "inbound") => 
            //randomName(pending_subscriptions{'name_space'}) 
            name_space + ":" + event:attr("name")
            |
            channel_name;
      options = {
        'name' : unique_name, 
        'eci_type' : channel_type,
        'attributes' : pending_subscriptions
          //'policy' : ,
      };
    }
    if(status eq "inbound") 
    then
    {
      createChannel(options);
    }
    fired { 
      log(standardOut("successful pending incoming"));
      raise wrangler event 'inbound_pending_subscription_added' // event to nothing
          with status = pending_subscriptions{'status'} // could this be replaced with all of the attrs pasted in?
            and name = pending_subscriptions{'subscription_name'}
            and channel_name = unique_name
            and name_space = pending_subscriptions{'name_space'}
            and relationship = pending_subscriptions{'relationship'}
            and subscriber_role = pending_subscriptions{'subscriber_role'}
            and my_role = pending_subscriptions{'my_role'}
            and attributes = pending_subscriptions{'attributes'}
            and outbound_eci = pending_subscriptions{'outbound_eci'}
            and channel_type = channel_type;
      log(standardOut("failure >>")) if (channel_name eq "");
    } 
    else { 
      log (standardOut("success pending outgoing >>"));
      raise wrangler event 'outbound_pending_subscription_added' // event to nothing
        attributes event:attrs();
    }
  }
  rule approvePendingSubscription { // used to notify both picos to add subscription request
    select when wrangler pending_subscription_approval
    pre{
      channel_name = event:attr("channel_name").defaultsTo( "no_channel_name", standardError("channel_name"));
      results = channel(channel_name,undefined,undefined);
      inbound = results{'channels'};
      inbound_eci = inbound{'eci'}; // this is why we call channel and not subscriptionAttributes.
      attributes = inbound{'attributes'};
      status = attributes{'status'};
      //inbound_eci = eciFromName(channel_name).klog("back eci: ");
      outbound_eci = attributes{'outbound_eci'}; // whats better?
      subscription_map = {
            "eci" : outbound_eci
      }.klog("subscription Map: ");
    }// this is a possible place to create a channel for subscription
    if (outbound_eci neq "no outbound_eci") then
    {
      event:send(subscription_map, "wrangler", "pending_subscription_approved") // pending_subscription_approved..
       with attrs = {"outbound_eci" : inbound_eci , 
                      "status" : "outbound"}
    }
    fired 
    {
      log (standardOut("success"));
      raise wrangler event 'pending_subscription_approved' // event to nothing  
        with channel_name = channel_name
        and status = "inbound";
    } 
    else 
    {
      log(">> failure >>");
    }
  }
  rule addSubscription { // changes attribute status value to subscribed
    select when wrangler pending_subscription_approved
    pre{
      status = event:attr("status").defaultsTo("", standardError("status"));
      outGoing = function(outbound_eci){
        attributes = subscriptionAttributes(meta:eci().klog("meta:eci for attributes: ")).klog("outgoing attributes: ");
        attr = attributes.put({"status" : "subscribed"}).klog("put outgoing status: "); // over write original status
        attrs = attr.put({"outbound_eci" : outbound_eci}).klog("put outgoing outbound_eci: "); // add outbound_eci
        attrs;
      };

      incoming = function(channel_name){
        attributes = subscriptionAttributes(channel_name);
        attr = attributes.put({"status": "subscribed"}).klog("incoming attributes: ");
        attr;
      };

      attributes = (status eq "outbound" ) => 
            outGoing(event:attr("outbound_eci").defaultsTo( "no outbound_eci", standardError("no outbound_eci"))) | 
            incoming(event:attr("channel_name").defaultsTo( "no channel name", standardError("no channel name")));
      
      // get eci to change channel attributes
      eci = (status eq "outbound" ) => 
            meta:eci() | 
            eciFromName(event:attr("channel_name").defaultsTo( "no channel name", standardError("no channel name")).klog("attribute channel_name: ")).klog("eci from name: ");
    }
    // always update attribute changes
    {
     updateAttributes(eci,attributes.klog("updateAttributes: "));
    }
    fired {
      log (standardOut("success"));
      raise wrangler event 'subscription_added' // event to nothing
        with channel_name = event:attr("channel_name").defaultsTo( "no channel name", standardError("no channel name"));
      } 
    else {
      log(">> failure >>");
    }
  }

  rule cancelSubscription {
    select when wrangler subscription_cancellation
            or  wrangler inbound_subscription_rejection
            or  wrangler outbound_subscription_cancellation
    pre{
      status = event:name();

      channel_name = event:attr("channel_name").defaultsTo( "No channel_name", standardError("channel_name"));
      //get channel from name
      results = channel(channel_name);
      inbound = results{'channels'};
      // look up back channel for canceling outbound.
      inbound_eci = inbound{'eci'}.klog("inbound_eci: "); // this is why we call channel and not subscriptionAttributes.
      // get attr from channel
      attributes = inbound{'attributes'};
      // get outbound_eci for subscription_map // who we will notify
      outbound_eci = attributes{'outbound_eci'}.defaultsTo(attributes{'subscriber_eci'}, " subscriber_eci used."); // whats better?
      // send remove event to outbound_eci
      // raise remove event to self with eci from name .

      subscription_map = {
            "eci" : outbound_eci
      }.klog("subscription_map: ");
    }
    //if( eci neq "No outbound_eci") then // always try to notify other party
    {
      event:send(subscription_map, "wrangler", "subscription_removal")
        with attrs = {
          // this will catch the problem with canceling outbound
          "eci"  : inbound_eci, // tabo to pass this but other pico has no other way to know ...
          "status": status //"outbound"
        };
    }
    fired {
      log (standardOut("success"));
      raise wrangler event subscription_removal 
        with eci = eciFromName(channel_name) // this probly could be inbound_eci to save on computations
        and status = "internal"; 
          } 
    else {
      log(">> failure >>");
    }
  } 
  rule removeSubscription {
    select when wrangler subscription_removal
    pre{
      status = event:attr("status").defaultsTo("", standardError("status"));
      passedEci= event:attr("eci").defaultsTo("", standardError("eci"));
      eciLookUpFromEvent = function(outbound_eci){
          get_outbound_eci = function(channel){
              attributes = channel{'attributes'};
              return = (attributes.isnull()) => 
                  null |
                  (attributes{'outbound_eci'} ); 
              return;
          };
          my_channels = channel();
          channel_list = my_channels{"channels"}.defaultsTo("no Channel",standardOut("no channel found, by channels"));
          filtered_channels = channel_list.filter( function (channel) {
          ( get_outbound_eci(channel) eq outbound_eci);
          }); 
        result = filtered_channels.head().defaultsTo("",standardError("no channel found, by .head()"));
        // a channel with the correct outbound_eci
        return = result{'eci'} // the correct eci to be removed.
        (return);
      };

      eci = ( status eq "inbound_subscription_rejection" || status eq "subscription_cancellation" ) => meta:eci() |
             (status eq "outbound_subscription_cancellation") => eciLookUpFromEvent( passedEci ) |
                passedEci; // passed is used to deleted inbound on self 

      channel_name = nameFromEci(eci); // for event to nothing

    }
    {
      //clean up channel
     deleteChannel(eci.klog("eci being deleted. : ")); 
    }
    always {
      log (standardOut("success, attemped to remove subscription"));
      raise wrangler event subscription_removed // event to nothing
        with removed_channel_name = channel_name;
    } 
  } 
  /* 
  rule update{
    // check status is subscribed

    // raise mod/updated attrs event to both subscribed picos 

  }
  rule update/modChannelAttributes {
      select when wrangler subscription_attribute_update
            pre{
   
            //get all attributes to be updated. passed in

            //get current attributes.

            //"put" updated values into current
          
            // use deffaction to update attributes
  */

// unsubscribed all, check event from parent // just cancelSubscription... 
// let all your connection know your leaving.

}