


/* 
we could make a list of condition you dynamicly provide (lambda) and use a foreach to loop on the conditions.
*/
ruleset autosub {
  meta {
    name "autoSubscribe"
    description <<
      auto Subscribe 

      use module  v1_wrangler alias wrangler

      This Ruleset provides a developer auto subcription to desired request.
    >>
    author "BYUPICOLab"
    logging off
    provides accept
    sharing on

  }
  global {
    name = function(value) {
          ent:accept{['name']}.has(value);
    };
    namespace = function(value) {
          ent:accept{['namespace']}.has(value);
    };
    relationship = function(value) {
          ent:accept{['relationship']}.has(value);
    };
    target_role = function(value) {
          ent:accept{['target_role']}.has(value);
    };
    my_role = function(value) {
          ent:accept{['my_role']}.has(value);
    };
    attributes = function(value) {
          ent:accept{['attributes']}.has(value);
    };
    event_eci = function(value) {
          ent:accept{['event_eci']}.has(value);
    };    
    channel_type = function(value) {
          ent:accept{['channel_type']}.has(value);
    }; 
    accept = function() {
        ent:accept;
    };
  }

  // accept : 
  //          name: []
  //          namespace : []
  //          relationship : []
  //          target_role : []
  //          my_role     : []
  //          attributes : [] 
  //          event_eci  : []
  //          channel_type: []

  rule add_accept_attribute { // could add multiple empty conditions
    select when wrangler add_auto_accept
    pre {
      keyvalue = event:attr("key").defaultsTo("", "no key");
      value =  ent:accept{keyvalue}.append(event:attr("value").defaultsTo("", "no value")) || [event:attr("value").defaultsTo("", "no value")] ;
    }
    always {
      set ent:accept{keyvalue} value;
      raise wrangler event auto_accept_added with 
         keyvalue = keyvalue and
         value = value;
    }
  }

  rule simpleAutoAccept {
    select when wrangler inbound_pending_subscription_added 
    pre{
      attributes = event:attrs().klog("subcription :");
      accept_name = name(event:attr('name'));
      accept_namespace = namespace(event:attr('name_space'));
      accept_relationship = relationship(event:attr('relationship'));
      accept_target_role = target_role(event:attr('target_role'));
      accept_my_role = my_role(event:attr('my_role'));
      accept_attributes = attributes(event:attr('attributes'));
      accept_event_eci = event_eci(event:attr('event_eci'));
      accept_channel_type = channel_type(event:attr('channel_type'));
      }
      if(
          accept_name || 
          accept_namespace ||  
          accept_relationship || 
          accept_target_role || 
          accept_attributes ||
          accept_channel_type
          ) then{
      noop();
      }
    fired{
      raise wrangler event 'pending_subscription_approval'
          attributes attributes;        
          log("auto accepted subcription.");
    }
  }
  /*
  rule conditionAutoAccept {
    select when wrangler inbound_pending_subscription_added 
      foreach ent:condistions setting (condistion)
    pre{}
      if(condistion) then{
      noop();
      }
    fired{
      raise wrangler event 'pending_subscription_approval'
          attributes attributes;        
          log("auto accepted subcription.");
    }
  }
*/
}