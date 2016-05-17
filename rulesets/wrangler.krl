
// varibles 
// ent:my_picos
// ent:picos_attributes


// operators are camel case, variables are snake case.


// questions
// standard state change raiseevent post function??
// when should we use klogs?
// when registering a ruleset if you pass empty peramiters what happens

//whats the benifit of forking a ruleset vs creating a new one?
//pci: lacks abillity to change channel type 

ruleset b507803x0 {
  meta {
    name "wrangler"
    description <<
      Wrangler ( ) Module

      use module  b507798x0 alias wrangler

      This Ruleset/Module provides a developer interface to the PICO (persistent computer object).
      When a PICO is created or authenticated this ruleset
      will be installed into the Personal Cloud to provide an Event layer.
    >>
    author "BYUPICOLab"
    
    logging off

    use module b16x24 alias system_credentials
    use module b507199x8 alias pds
    // errors raised to.... unknown

    // Accounting keys
      //none
    provides skyQuery, rulesets, rulesetsInfo, //ruleset
    channel, channelAttributes, channelPolicy, channelType, //channel
    children, parent, attributes, prototypes, name, profile, pico, //pico
    subscriptions, eciFromName, subscriptionAttributes, //subscription
    standardError
    sharing on

  }

  //dispatch {
    //domain "ktest.heroku.com"
  //}
  global {
    //functions
    // taken from website, not tested. function call to a different pico on the same kre  
	 
      //add _host for host make it defaultsTo meta:host(), create function to make cloud_url string from host 
      skyQuery = function(eci,_host, mod, func, params) {
              host = _host || meta:host();
              cloud_url = "https://#{host}/sky/cloud/";
              response = http:get("#{cloud_url}#{mod}/#{func}", (params || {}).put(["_eci"], eci));
   
              status = response{"status_code"};

              error_info = {
                  "error": "sky cloud request was unsuccesful.",
                  "httpStatus": {
                      "code": status,
                      "message": response{"status_line"}
                  }
              };
   
   
              response_content = response{"content"}.decode();
              response_error = (response_content.typeof() eq "hash" && response_content{"error"}) => response_content{"error"} | 0;
              response_error_str = (response_content.typeof() eq "hash" && response_content{"error_str"}) => response_content{"error_str"} | 0;
              error = error_info.put({"skyCloudError": response_error, "skyCloudErrorMsg": response_error_str, "skyCloudReturnValue": response_content});
              is_bad_response = (response_content.isnull() || response_content eq "null" || response_error || response_error_str);
   
   
              // if HTTP status was OK & the response was not null and there were no errors...
              (status eq "200" && not is_bad_response) => response_content | error
          };

	
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
      configure using eci = meta:eci();
      new_ruleset = pci:new_ruleset(eci, rids);
      send_directive("installed #{rids}");
    }
    uninstallRulesets = defaction(rids){
      configure using eci = meta:eci();
      deleted = pci:delete_ruleset(eci, rids);
      send_directive("uninstalled #{rids}");
    }
  //-------------------- Channels --------------------
  /* can be deleted after channel testing.
    internalChannel = function (value){
      eci = meta:eci();
      results = pci:list_eci(eci).defaultsTo({},standardError("undefined")); // list of ECIs assigned to userid
      channels = results{'channels'}.defaultsTo("error",standardError("undefined")); // list of channels if list_eci request was valid
      
      // if value is a number with ((([A-Z]|\d)*-)+([A-Z]|\d)*) attribute is cid.
      attribute = (value.match(re/(^(([A-Z]|\d)+-)+([A-Z]|\d)+$)/)) => 
              'cid' |
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
      channel_single{'cid'};
    }
    // always return a eci weather given a eci or name
    alwaysEci = function(value){
      eci = (value.match(re/(^(([A-Z]|\d)+-)+([A-Z]|\d)+$)/)) => 
              value |
              eciFromName(value);
      eci;       
    }
    channel = function(id) { 
      eci = meta:eci();
      results = pci:list_eci(eci).defaultsTo({},standardError("undefined")); // list of ECIs assigned to userid
      channels = results{'channels'}.defaultsTo("error",standardError("undefined")); // list of channels if list_eci request was valid
      
      single_channel = function(value,chans){
         // if value is a number with ((([A-Z]|\d)*-)+([A-Z]|\d)*) attribute is cid.
        attribute = (value.match(re/(^(([A-Z]|\d)+-)+([A-Z]|\d)+$)/)) => 
                'cid' |
                'name';
        channel_list = chans;
        filtered_channels = channel_list.filter(function(channel){
          (channel{attribute} eq value);}); 
        result = filtered_channels.head().defaultsTo({},standardError("no channel found, by .head()"));
        (result);
      };

      results = (id.isnull()) => channels | single_channel(id,channels);
      {
        'status'   : (channels neq "error"),
        'channels' : results
      }.klog("channels");
    }
    channelAttributes = function(eci,name) {
      Eci = eci.defaultsTo(alwaysEci(name).defaultsTo('','no name or eci provided'),'no eci going with name') ;
      results = pci:get_eci_attributes(Eci.klog("get_eci_attributes passed eci: ")).defaultsTo("error",standardError("get_eci_attributes")); // list of ECIs assigned to userid
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
      set_eci = pci:set_eci_attributes(eci, {"channel_attributes" : attributes});
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
      send_directive("created channel #{new_eci}");
    }

  //-------------------- Picos --------------------
   /// should children and parent functions return a map instead of an array??
	children = function() {
		self = meta:eci();
		children = pci:list_children(self).defaultsTo("error", standardError("pci children list failed"));
		{
			'status' : (children neq "error"),
			'children' : children
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
    name =  ent:name;
    {
      'status' : pdsProfiles{"status"},
      'picoName' : name
    }
  }

	attributes = function() {
		{
			'status' : true,
			'attributes' : ent:attributes
		}
	}
	
	deletePico = defaction(eci) {
		noret = pci:delete_pico(eci, {"cascade":1});
		send_directive("deleted pico #{eci}");
	}
	
  corePrototype = {
      "meta" : {
                "discription": "Wrangler base prototype"
                },
                //array of maps for meta data of rids .. [{rid : id},..}  
      "rids": [ "b507199x5.dev",
                "b507199x8.dev" // pds
                 //"a169x625"
              ],
      "channels" : [{
                      "name"       : "testPrototypChannel",
                      "type"       : "ProtoType",
                      "attributes" : "prototypes test attrs",
                      "policy"     : "not implamented"
                    },
                    {
                      "name"       : "test2PrototypChannel",
                      "type"       : "ProtoType",
                      "attributes" : "prototypes test attrs",
                      "policy"     : "not implamented"
                    }
                    ], // could be [["","","",""]], // array of arrrays [[name,type,attributes,policy]]
                    // belongs in relationManager 
      "subscriptions_request": [{
                                  "name"          : "corePrototypeName",
                                  "name_space"    : "corePrototypeNameSpace",
                                  "my_role"       : "son",
                                  "your_role"     : "test",
                                  "target_eci"    : "1654165",
                                  "channel_type"  : "ProtoType",
                                  "attrs"         : "nogiven"
                                }],
      "Prototype_events" : [{
                              'domain': 'wrangler',
                              'type'  : 'core_prototype_event1',
                              'attrs' : {'attr1':'1',
                                          'attr2':'2'
                                        }
                            },
                            {
                              'domain': 'wrangler',
                              'type'  : 'core_prototype_event2',
                              'attrs' : {'attr1':'1',
                                          'attr2':'2'
                                        }
                            },
                            {
                              'domain': 'wrangler',
                              'type'  : 'core_prototype_event3',
                              'attrs' : {'attr1':'1',
                                          'attr2':'2'
                                        }
                            }
                            ], // array of maps
      "PDS" : {
                "profile" : {"name":"core"},
                "general" : {"test":{"subtest":"just a test"}},
                "settings": {"b507798x0.dev":{
                                              "name":"wrangler",
                                              "rid" :"b507798x0.dev",
                                              "data":{},
                                              "schema":["im","a","schema"]
                                              }
                            }
              }
  };
  devtoolsPrototype = {
      "meta" : {
                "discription": "devtools prototype"
                },
      "rids": [ 
                "b507199x1.dev"// quick fix and a ugly one! bootstrap rid
                 //"a169x625"
              ],
      "channels" : [{
                      "name"       : "testDevtoolsPrototypChannel",
                      "type"       : "ProtoType",
                      "attributes" : "devtool prototypes test attrs",
                      "policy"     : "not implamented"
                    },
                    {
                      "name"       : "testDevtools2PrototypChannel",
                      "type"       : "ProtoType",
                      "attributes" : "devtool prototypes test attrs",
                      "policy"     : "not implamented"
                    }
                    ], // could be [["","","",""]], // array of arrrays [[name,type,attributes,policy]]
      "subscriptions_request": [],
      "Prototype_events" : [{
                              'domain': 'wrangler',
                              'type'  : 'devtools_prototype_event1',
                              'attrs' : {'attr1':'1',
                                          'attr2':'2'
                                        }
                            },
                            {
                              'domain': 'wrangler',
                              'type'  : 'devtools_prototype_event2',
                              'attrs' : {'attr1':'1',
                                          'attr2':'2'
                                        }
                            },
                            {
                              'domain': 'wrangler',
                              'type'  : 'devtools_prototype_event3',
                              'attrs' : {'attr1':'1',
                                          'attr2':'2'
                                        }
                            }
                            ], 
      "PDS" : {
                "profile" : {},
                "general" : {},
                "settings": {}
      }
  };

// intialize ent;prototype, check if it has a prototype and default to hard coded prototype

// we will store base prototypes as hard coded varibles with, 
  prototypes = function() {
    init_prototypes = ent:prototypes || {"devtools" : devtoolsPrototype };// if no prototypes set to map so we can use put()
    prototypes = init_prototypes.put(['core'],corePrototype);
    {
      'status' : true,
      'prototypes' : prototypes
    }
  };

// create a ent:prototype_at_creationg, ent:predefined_prototype. 
// at creation wrangler will create child and send protype to child and 
// then wrangle in the child will handle the creation of the pico and its prototypes
// protype has a meta, rids, channels, events( creation events ) 

// create child from protype will take the name with a option of a prototype with a default to core.
  createChild = defaction(name){ 
    configure using protype_name = "devtools"; // core must be installed by default for prototypeing to work 
    results = prototype(); // get prototype from ent varible and default to core if not found.
    prototypes = results{"prototypes"};
    prototype = prototypes{protype_name}.defaultsTo(devtoolsPrototype,"prototype not found");
    rids = prototype{"rids"};
    // create child and give name
    attributes = {
      "name": name,
      "prototype": prototype.encode()
    };
    // create child 
    newPicoInfo = pci:new_pico(meta:eci()); // we need pci updated to take a name.
    newPicoEci = newPicoInfo{"cid"};// store child eci
    // bootstrap child
    //combine new_ruleset calls 
    a = pci:new_ruleset(newPicoEci, corePrototype{"rids"}); // install core rids (bootstrap child) 
    // bootstrap prototype
    b = pci:new_ruleset(newPicoEci, rids);// install protypes 
    // update child ent:prototype_at_creation with prototype
    event:send({"cid":newPicoEci}, "wrangler", "create_prototype") // event to child to handle prototype creation 
      with attrs = attributes
  }


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
            (attributes{'subscription_name'}.isnull() eq false); // how do u use not in krl?
          };
        isSubscription(channel).klog("isSubscriptions(): ");

      }); 
      // reconstruct list, to have a backchannel in attributes.
      subs = filtered_channels.map( function(channel){
           channel.put(["attributes","back_channel"],channel{"cid"})
                  .put(["attributes","channel_name"],channel{"name"}); // hard to get channel name when its the key... so we add it here.
      });
      // name to attributes hash
      subsript = subs.map( function(channel){
          {channel{'name'}:channel{'attributes'}}
      });
      /*  
      {"18:floppy" :
          {"status":"inbound","relationship":"","name_space":"18",..}
      */
      subsript;
    };

    subscriptions = function(collection,filtered) { 
      subsript = allSubscriptions();
      /*  
      {"18:floppy" :
          {"status":"inbound","relationship":"","name_space":"18",..}
      */
     //types = ['name','channel_name','back_channel','name_space','relationship',....] could check imput for validness. 
      type = function(sub){ // takes a subscription and returns its status.
        value = sub.values(); // array of values [attributes]
        attributes = value.head(); // get attributes
        group = (attributes.typeof() eq 'hash')=> // for robustness check type.
        attributes{collection} | 'error';
        (group);
      };
      return1 = collection.isnull() => subsript |  subsript.collect(function(sub){(type(sub));}) ;
      return2 = filtered.isnull() => return1 | return1{filtered};
      {
        'status' : (subscriptions neq "error"),
        'subscriptions'  : return2
      };

    };
    // subscriptions collected By attribute name provided// combine with "by filter"// combine with subscriptions
    subscriptionsByCollection = function (attribute_name){
      true;

    };
    // takes an attribute(name,type,relationship, etc.) and a value(what you want like, tedrub, work , slave<=>master , etc)returns subscriptions of that attribute and value.
  //  subscriptionsByFilter = function (attr,value){

   //};


    randomName = function(namespace){
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
    }
    // optimize by taking a list of names, to prevent multiple network calls for channels
    checkName = function(name){
          chan = channel();
          //channels = channels(); worse bug ever!!!!!!!!!!!!!!!!!!!!!!!!!!!
          // in our meetings we said to check name_space, how is that done?
          /*{
          "last_active": 1426286486,
          "name": "Oauth Developer ECI",
          "type": "OAUTH",
          "cid": "158E6E0C-C9D2-11E4-A556-4DDC87B7806A",
          "attributes": null}
          */
          chs = chan{"channels"}.defaultsTo("no Channel",standardOut("no channel found"));
          names = chs.none(function(channel){channel{"name"} eq name});
          (names);

    }
    // takes name or eci 
    subscriptionAttributes = function (name_or_eci){
      v = name_or_eci; // we dont need this right? // remove when you can test
      eci = (name_or_eci.match(re/(^(([A-Z]|\d)+-)+([A-Z]|\d)+$)/)) => 
              name_or_eci |
              eciFromName(name_or_eci);

      attributes = channelAttributes(eci);
      attributes{'Attributes'};
    } 


    /*findVehicleByBackchannel = function (bc) {
       garbage = bc.klog(">>>> back channel <<<<<");
       vehicle_ecis = wrangler:subscriptionList(common:namespace(),"Vehicle");
        vehicle_ecis_by_backchannel = vehicle_ecis
                                        .collect(function(x){x{"backChannel"}})
                                     .map(function(k,v){v.head()})
                                        ;
    vehicle_ecis_by_backchannel{bc} || {}
     };*/
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
      array_value = [].put(value).klog('array structure: ');
      return = (decoded_value{'error'} eq array_value ).klog('switch statement: ') => value | decoded_value;
      return.klog('return: ');
    }
  }
  // string or array return array 
  // string or array return string


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
      rids = event:attr("rids").defaultsTo("", ">>  >> ").klog(">> rids attribute <<");
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
 
 //-------------------- Channels --------------------
 // we should add a append / modifie channel attributes rule set.
 //  takes in new and modified values and puts them in.
  rule updateChannelAttributes {
    select when wrangler update_channel_attributes_requested
    pre {
      value = event:attr("eci").defaultsTo(event:attr("name").defaultsTo("", standardError("missing event attr eci or name")), standardError("looking for name instead of eci."));
      attributes = event:attr("attributes").defaultsTo("error", standardError("undefined"));
      //attrs = attributes.split(re/;/);
      attrs =  decodeDefaults(attributes);
      //channels = Channel();
    }
    if(value neq "" && attributes neq "error") then { // check?? redundant????
      updateAttributes(value.klog('value: '),attrs);
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
      value = event:attr("eci").defaultsTo(event:attr("name").defaultsTo("", standardError("missing event attr eci or name")), standardError("looking for name instead of eci."));
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
      type = event:attr("type").defaultsTo("error", standardError("undefined"));// policy needs to be a map, do we need to cast types?
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
  
  rule createChannel {
    select when wrangler channel_creation_requested
    pre {
      event_attributes = event:attrs();
    /*  <eci options>
    name     : <string>        // default is "Generic ECI channel" 
    eci_type : <string>        // default is "PCI"
    attributes: <array>
    policy: <map>  */
      channel_name = event:attr("channel_name").defaultsTo("", standardError("missing event attr channels"));
      type = event:attr("channel_type").defaultsTo("Unknown", standardError("missing event attr channel_type"));
      attributes = event:attr("attributes").defaultsTo("", standardError("missing event attr attributes"));
      attrs =  decodeDefaults(attributes);
      policy = event:attr("policy").defaultsTo("", standardError("missing event attr attributes"));
      // do we need to check if we need to decode ?? what would we check?
      decoded_policy = policy.decode().klog('decoded_policy') || policy;
      options = {
        'name' : channel_name,
        'eci_type' : type,
        'attributes' : {"channel_attributes" : attrs},
        'policy' : decoded_policy//{"policy" : policy}
      }.klog('options for channel cration');
          }
          // do we need to check the format of name? is it wrangler's job?
    if(channel_name.match(re/\w[\w-]*/)) then 
          { 
      createChannel(options);
          }
    fired {
      log (standardOut("success created channels #{channel_name}"));
      log(">> successfully  >>");
      raise wrangler event 'channel_created' // event to nothing  
            attributes event_attributes;
          } 
    else {
      log(">> could not create channels #{channel_name} >>");
          }
    }
  
  
  //-------------------- Picos ----------------------
	rule createChild { // must pass list of rids to install in child and domain / type for init event.
		select when wrangler child_creation
		pre {
      attribute = event:attrs();
      name = event:attr("name");
      prototype = event:attr("prototype").defaultsTo("devtools", standardError("missing event attr prototype"));           
		}

		{
			createChild(name) with protype_name = prototype; 
		}
		always {
			log(standardOut("pico created with name #{name}"));
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
// prototype channels creation 
  rule initializeCoreChannels {
    select when wrangler init_events 
      foreach corePrototype{'channels'}.klog("Prototype core channels : ") setting (PT_channel)
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
// core channels creation
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
// core subscription creation 
  rule initializeCoreSubscriptions {
    select when wrangler init_events 
      foreach corePrototype{'subscriptions_request'}.klog("Prototype core subscriptions_request: ") setting (subscription)
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

// prototype subscription creation 
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

  rule initializeProfile {// this rule should build pds data structure
    select when wrangler init_events
    pre {
      attrs = corePrototype{['PDS','profile']};
    }
    {
      noop();
    }
    always {
    raise pds event updated_profile // init prototype  // rule in pds needs to be created.
            attributes attrs
    }
  }
  rule initializeGeneral {
    select when wrangler init_events 
      foreach corePrototype{['PDS','general']}.klog("Prototype subscriptions_request: ") setting (namespace) 
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

  rule initializePdsSettings {// this rule should build pds data structure
    select when wrangler init_events
    pre {
      attrs = corePrototype{['PDS','profile']};
    }
    {
      noop();
    }
    always {
    raise pds event updated_profile // init prototype  // rule in pds needs to be created.
            attributes attrs
    }
  }

  rule initializedBarrier{// after core pds is initialize update prototype pds and raise prototype events
    select when pds new_map_added // general inited
            and pds profile_updated // profile inited
            and pds settings_added // settings inited
    pre {
    }
    {
      noop();
    }
    always {
    raise wrangler event pds_inited// init prototype  // rule in pds needs to be created.
            attributes {}
    }
  }

  rule updatePrototypeProfile {// this rule should build pds data structure
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
      foreach ent:prototypes{['at_creation','PDS','general']}.klog("Prototype subscriptions_request: ") setting (namespace) 
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

  rule updatePrototypePdsSettings {// this rule should build pds data structure
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
  rule raiseCoreEvents {
    select when wrangler pds_inited
    foreach corePrototype{['Prototype_events']} setting (Prototype_event)
    pre {
      Prototype_domain = Prototype_event{'domain'};
      Prototype_type = Prototype_event{'type'};
      Prototype_attrs = Prototype_event{'attrs'};
    }
    {
      noop();
    }
    always {
    //raise Prototype_domain event Prototype_type // init prototype  // rule in pds needs to be created.
    raise wrangler event Prototype_type 
            attributes Prototype_attrs
    }
  }
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
    //raise Prototype_domain event Prototype_type // init prototype  // rule in pds needs to be created.
    raise wrangler event Prototype_type 
            attributes Prototype_attrs
    }
  }

  rule addPrototype {
    select when wrangler add_prototype
    pre {

    }
    {
      noop();
    }
    always {
      set ent:prototypes{prototype_name} prototype;
    raise wrangler event Prototype_type_added 
            attributes event:attrs();
    }
  }
  rule updatePrototype {
    select when wrangler update_prototype
    pre {

    }
    {
      noop();
    }
    always {
      set ent:prototypes{prototype_name} prototype;
    raise wrangler event Prototype_type_updated
            attributes event:attrs();
    }
  }
  rule removePrototype {
    select when wrangler add_prototype
    pre {

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
			eciDeleted = event:attr("deletionTarget").defaultsTo("", standardError("missing pico for deletion"));
		}
		if(eciDeleted neq "") then
		{
			deletePico(eciDeleted);
		}
		notfired {
			log "deletion failed because no child was specified";
		}
	}

  //-------------------- Subscriptions ----------------------http://developer.kynetx.com/display/docs/Subscriptions+in+the+wrangler+Service
  /* 
   ========================================================================
   No Persistent Variables for subscriptions, subscriptions information is stored in the "backChannel" Channels attributes varible
    backChannel : {
        type: <string>
        name: <string>
        policy: ?? // not used.
        attrs: {
          (Subscription attributes) 
           "name"  : <string>,
           "name_space": <string>,
           "relationship" : <string>,
           "target_eci": <string>, // this is only stored in the origanal requestie
           "event_eci" : <string>,
           "attributes" : <string>, // this will be a object(mostlikely an array) that has been encoded as a string. 
           "status": <string> // discribes subscription status, incouming, outgoing, subscribed
        }
    }
    ========================================================================
   */

   // creates back_channel and sends event for other pico to create back_channel.
  rule subscribe {// need to change varibles to snake case.
    select when wrangler subscription
   pre {
      // attributes for back_channel attrs
      name   = event:attr("name").defaultsTo("standard", standardError("channel_name"));
      name_space     = event:attr("name_space").defaultsTo("shared", standardError("name_space"));
      my_role  = event:attr("my_role").defaultsTo("peer", standardError("my_role"));
      your_role  = event:attr("your_role").defaultsTo("peer", standardError("your_role"));
      target_eci = event:attr("target_eci").defaultsTo("no_target_eci", standardError("target_eci"));
      channel_type      = event:attr("channel_type").defaultsTo("subs", standardError("type"));
      //status      = event:attr("status").defaultsTo("status", standardError("status ")); 
      attributes = event:attr("attrs").defaultsTo("status", standardError("status "));

     // // destination for external event
      subscription_map = {
            "cid" : target_eci
      };
      // create unique_name for channel
      unique_name = randomName(name_space);

      // build pending subscription entry

      pending_entry = {
        "subscription_name"  : name,
        "name_space"    : name_space,
        "relationship" : my_role +"<->"+ your_role, 
        "my_role" : my_role,
        "subscriber_role" : your_role,
        "target_eci"  : target_eci, // this will remain after accepted
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
    if(target_eci neq "no_target_eci") // check if we have someone to send a request too
    then
    {

      createChannel(options);// just use meta:eci()??

      event:send(subscription_map, "wrangler", "pending_subscription") // send request
        with attrs = {
          "name"  : name,
          "name_space"    : name_space,
          "relationship" : your_role +"<->"+ my_role ,
          "my_role" : your_role,
          "subscriber_role" : my_role,
          "event_eci"  : eciFromName(unique_name), 
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
        and channel_name = unique_name;
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
            "event_eci"  : event:attr("event_eci").defaultsTo("", standardError("event_eci")),
            "status"  : event:attr("status").defaultsTo("", standardError("status")),
            "attributes" : event:attr("attributes").defaultsTo("", standardError("attributes"))
          } |
          {};
          // should this go into the hash above?
      unique_name = (status eq "inbound") => 
            randomName(pending_subscriptions{'name_space'}) |
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
      raise wrangler event inbound_pending_subscription_added // event to nothing
          with status = pending_subscriptions{'status'}
            and name = pending_subscriptions{'subscription_name'}
            and channel_name = unique_name
            and name_space = pending_subscriptions{'name_space'}
            and relationship = pending_subscriptions{'relationship'}
            and subscriber_role = pending_subscriptions{'subscriber_role'}
            and my_role = pending_subscriptions{'my_role'}
            and attributes = pending_subscriptions{'attributes'}
            and event_eci = pending_subscriptions{'event_eci'}
            and channel_type = channel_type;
      log(standardOut("failure >>")) if (channel_name eq "");
    } 
    else { 
      log (standardOut("success pending outgoing >>"));
      raise wrangler event outbound_pending_subscription_added; // event to nothing
    }
  }
  rule approvePendingSubscription { // used to notify both picos to add subscription request
    select when wrangler pending_subscription_approval
    pre{
      channel_name = event:attr("channel_name").defaultsTo( "no_channel_name", standardError("channel_name"));
      results = channel(channel_name);
      back_channel = results{'channels'};
      back_channel_eci = back_channel{'cid'}; // this is why we call channel and not subscriptionAttributes.
      attributes = back_channel{'attributes'};
      status = attributes{'status'};
      //back_channel_eci = eciFromName(channel_name).klog("back eci: ");
      event_eci = attributes{'event_eci'}; // whats better?
      subscription_map = {
            "cid" : event_eci
      }.klog("subscription Map: ");
    }// this is a possible place to create a channel for subscription
    if (event_eci neq "no event_eci") then
    {
      event:send(subscription_map, "wrangler", "pending_subscription_approved") // pending_subscription_approved..
       with attrs = {"event_eci" : back_channel_eci , 
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
      outGoing = function(event_eci){
        attributes = subscriptionAttributes(meta:eci().klog("meta:eci for attributes: ")).klog("outgoing attributes: ");
        attr = attributes.put({"status" : "subscribed"}).klog("put outgoing status: "); // over write original status
        attrs = attr.put({"event_eci" : event_eci}).klog("put outgoing event_eci: "); // add event_eci
        attrs;
      };

      incoming = function(channel_name){
        attributes = subscriptionAttributes(channel_name);
        attr = attributes.put({"status": "subscribed"}).klog("incoming attributes: ");
        attr;
      };

      attributes = (status eq "outbound" ) => 
            outGoing(event:attr("event_eci").defaultsTo( "no event_eci", standardError("no event_eci"))) | 
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
      back_channel = results{'channels'};
      // look up back channel for canceling outbound.
      back_channel_eci = back_channel{'cid'}.klog("back_channel_eci: "); // this is why we call channel and not subscriptionAttributes.
      // get attr from channel
      attributes = back_channel{'attributes'};
      // get event_eci for subscription_map // who we will notify
      event_eci = attributes{'event_eci'}.defaultsTo(attributes{'target_eci'}, " target_eci used."); // whats better?
      // send remove event to event_eci
      // raise remove event to self with eci from name .

      subscription_map = {
            "cid" : event_eci
      }.klog("subscription_map: ");
    }
    //if( eci neq "No event_eci") then // always try to notify other party
    {
      event:send(subscription_map, "wrangler", "subscription_removal")
        with attrs = {
          // this will catch the problem with canceling outbound
          "eci"  : back_channel_eci, // tabo to pass this but other pico has no other way to know ...
          "status": status//"outbound"
        };
    }
    fired {
      log (standardOut("success"));
      raise wrangler event subscription_removal 
        with eci = eciFromName(channel_name) // this probly could be back_channel_eci to save on computations
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
      eciLookUpFromEvent = function(event_eci){
          get_event_eci = function(channel){
              attributes = channel{'attributes'};
              return = (attributes.isnull()) => 
                  null |
                  (attributes{'event_eci'} ); 
              return;
          };
          my_channels = channel();
          channel_list = my_channels{"channels"}.defaultsTo("no Channel",standardOut("no channel found, by channels"));
          filtered_channels = channel_list.filter( function (channel) {
          ( get_event_eci(channel) eq event_eci);
          }); 
        result = filtered_channels.head().defaultsTo("",standardError("no channel found, by .head()"));
        // a channel with the correct event_eci
        return = result{'cid'} // the correct eci to be removed.
        (return);
      };

      eci = ( status eq "inbound_subscription_rejection" || status eq "subscription_cancellation" ) => meta:eci() |
             (status eq "outbound_subscription_cancellation") => eciLookUpFromEvent( passedEci ) |
                passedEci; // passed is used to deleted backchannel on self 

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