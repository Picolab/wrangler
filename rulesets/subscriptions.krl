ruleset Subscriptions {
  meta {
    name "subscriptions"
    description <<
      subscription ruleset for CS462 lab.
    >>
    author "CS462 TA"
    use module wrangler
    provides subscriptions, klogtesting, skyQuery
    shares subscriptions, klogtesting, skyQuery, __testing
    logging on
  }

 global{
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ { "domain": "wrangler", "type": "subscription",
                                "attrs": [ 
                                  "name"          ,
                                  "name_space"    ,
                                  "my_role"       ,
                                  "subscriber_role"     ,
                                  "subscriber_eci"    ,
                                  "channel_type"  ,
                                  "attrs"         
                                 ] },
                       {"domain": "wrangler", "type": "pending_subscription_approval",
                                "attrs": [ 
                                  "channel_name"          
                                 ] },
 {"domain": "wrangler", "type": "subscription_cancellation",
                                "attrs": [ 
                                  "channel_name"         
                                 ] } ] }

    getSelf = function(){
       wrangler:myself() // must be wrapped in a function
    }

    /*
      subscriptions([collectBy[, filterValue]]) with no arguments returns the
        value of ent:subscriptions (the subscriptions map)
      parameters:
        collectBy - if filterValue is omitted, the string or hashpath
          that indexes the subscriptions map values
          used to collect() each subscription map by

          e.g. if the subscriptions map is

          {
            "ns:n1": {
              "name": "ns:n1",
              "attributes": {
                "my_role": "peer",
                ...
              },
              ...
            },
            ...
          }

          subscriptions(["attributes", "my_role"]) returns

          {
            "peer": [
              {
                "ns:n1": {
                  "name": "ns:n1",
                  "attributes": {
                    "my_role": "peer",
                    ...
                  },
                  ...
                }
              },
              ...
            ],
            ...
          }

        filterValue - subscriptions(["attributes", "my_role"], "peer")
          returns the array indexed by "peer" above
    */
    subscriptions = function(collectBy, filterValue){
      subs = ent:subscriptions.defaultsTo({}, "no subscriptions");
      collectBy.isnull() => subs | function(){
        subArray = subs.keys().map(function(name){{}.put(name, subs{name})});
        filterValue.isnull() => subArray.collect(function(sub){
          sub.values()[0]{collectBy}
        }) | subArray.filter(function(sub){
          sub.values()[0]{collectBy} == filterValue
        })
      }()
    }

    standardOut = function(message) {
      msg = ">> " + message + " results: >>";
      msg
    }
    standardError = function(message) {
      error = ">> error: " + message + " >>";
      error
    } 

    // this only creates 5 random names; if none are unique keep prepending '_' and trying again

    randomSubscriptionName = function(name_space, name_base){
        base = name_base.defaultsTo("");
        subscriptions = subscriptions();
        array = 1.range(5).map(function(n){
          random:word()
          }).klog("randomWords");
        names = array.filter(function(name){
          subscriptions{name_space + ":" + base + name}.isnull()
        });
        names.length() > 0 => names[0].klog("uniqueName") | randomSubscriptionName(name_space, base + "_")
    }
    checkSubscriptionName = function(name , name_space, subscriptions){
      (subscriptions{name_space + ":" + name}.isnull())
    }
    mapWithHost = function(map, host){
      host.isnull() => map | map.put("subscriber_host", host)}
  }
  rule subscribeNameCheck {
    select when wrangler subscription
    pre {
      name_space = event:attr("name_space").defaultsTo("shared", standardError("name_space"))
      name   = event:attr("name") || randomSubscriptionName(name_space).klog("random name") //.defaultsTo(randomSubscriptionName(name_space), standardError("channel_name"))
      attr = event:attrs()
      attrs = attr.put({"name":name}).klog("subscribeNameCheck attrs")
    }
    if(checkSubscriptionName(name , name_space, subscriptions())) then noop()
    fired{
      raise wrangler event "checked_name_subscription"
       attributes attrs
    }
    else{
      //error warn "duplicate subscription name, failed to send request "+name;
      //log(">> could not send request #{name} >>");
      logs.klog(">> could not send request #{name} >>")
    }
  }

  rule createMySubscription {
    select when wrangler checked_name_subscription
   pre {
      // attributes for inbound attrs
      logs = event:attrs().klog("createMySubscription attrs")
      name   = event:attr("name")
      name_space     = event:attr("name_space")
      my_role  = event:attr("my_role").defaultsTo("peer", standardError("my_role"))
      subscriber_host = event:attr("subscriber_host")
      subscriber_role  = event:attr("subscriber_role").defaultsTo("peer", standardError("subscriber_role"))
      subscriber_eci = event:attr("subscriber_eci").defaultsTo("no_subscriber_eci", standardError("subscriber_eci"))
      channel_type      = event:attr("channel_type").defaultsTo("subs", standardError("type"))
      attributes = event:attr("attrs").defaultsTo("status", standardError("attributes "))

      // create unique_name for channel
      unique_name = name_space + ":" + name
      logs = unique_name.klog("name")
      // build pending subscription entry
      pending_entry = mapWithHost({
        "subscription_name"  : name,
        "name_space"    : name_space,
        "relationship" : my_role +"<->"+ subscriber_role, 
        "my_role" : my_role,
        "subscriber_role" : subscriber_role,
        "subscriber_eci"  : subscriber_eci, // this will remain after accepted
        "status" : "outbound", // should this be passed in from out side? I dont think so.
        "attributes" : attributes
      }, subscriber_host).klog("pending entry")
      //create call back for subscriber     
      options = {
          "name" : unique_name, 
          "eci_type" : channel_type,
          "attributes" : pending_entry
          //"policy" : ,
      }.klog("options")
    }
    if(subscriber_eci != "no_subscriber_eci") // check if we have someone to send a request too
    then every {
       engine:newChannel(getSelf()["id"], options.name, options.eci_type) setting(channel);
    }
    fired {
      newSubscription = {"eci": channel.id, "name": channel.name,"type": channel.type, "attributes": options.attributes};
      updatedSubs = subscriptions().put([newSubscription.name] , newSubscription.put(["attributes"],{"sid" : newSubscription.name})) ;
      newSubscription.klog(">> successful created subscription request >>");
      ent:subscriptions := updatedSubs;
      raise wrangler event "pending_subscription" attributes mapWithHost({
        "status" : pending_entry{"status"},
        "channel_name" : unique_name,
        "channel_type" : channel_type,
        "name" : pending_entry{"subscription_name"},
        "name_space" : pending_entry{"name_space"},
        "relationship" : pending_entry{"relationship"},
        "my_role" : pending_entry{"my_role"},
        "subscriber_role" : pending_entry{"subscriber_role"},
        "subscriber_eci"  : pending_entry{"subscriber_eci"},
        "inbound_eci" : newSubscription.eci,
        "attributes" : pending_entry{"attributes"}
      }, subscriber_host)
    } 
    else {
      logs.klog(">> failed to create subscription request, no subscriber_eci provieded >>")
    }
  }

  
  rule sendSubscribersSubscribe {
    select when wrangler pending_subscription status re#outbound#
   pre {
      logs = event:attrs().klog("sendSubscribersSubscribe attrs")
      name   = event:attr("name")//.defaultsTo("standard",standardError("channel_name"))
      name_space     = event:attr("name_space")//.defaultsTo("shared", standardError("name_space"))
      subscriber_host = event:attr("subscriber_host")
      my_role  = event:attr("my_role")//.defaultsTo("peer", standardError("my_role"))
      subscriber_role  = event:attr("subscriber_role")//.defaultsTo("peer", standardError("subscriber_role"))
      subscriber_eci = event:attr("subscriber_eci").defaultsTo("no_subscriber_eci", standardError("subscriber_eci"))
      channel_type      = event:attr("channel_type")//.defaultsTo("subs", standardError("type"))
      attributes = event:attr("attributes")//.defaultsTo("status", standardError("attributes "))
      inbound_eci = event:attr("inbound_eci")
      channel_name = event:attr("channel_name")
    }
    if(subscriber_eci != "no_subscriber_eci") // check if we have someone to send a request too
    then
      event:send({
          "eci": subscriber_eci, "eid": "subscriptionsRequest",
          "domain": "wrangler", "type": "pending_subscription",
          "attrs": mapWithHost({"name"  : name,
             "name_space"    : name_space,
             "relationship" : subscriber_role +"<->"+ my_role ,
             "my_role" : subscriber_role,
             "subscriber_role" : my_role,
             "outbound_eci"  :  inbound_eci, 
             "status" : "inbound",
             "channel_type" : channel_type,
             "channel_name" : channel_name,
             "attributes" : attributes }, subscriber_host.isnull() => null | meta:host)
      }, subscriber_host)
    fired {
      subscriber_eci.klog(">> sent subscription request to >>")
    } 
    else {
      logs.klog(">> failed to send subscription request >>")
    }
  }

 rule addOutboundPendingSubscription {
    select when wrangler pending_subscription status re#outbound#
    always { 
      raise wrangler event "outbound_pending_subscription_added" // event to nothing
        attributes event:attrs().klog(standardOut("successful outgoing pending subscription >>"))
    } 
  }

  rule InboundNameCheck {
    select when wrangler pending_subscription status re#inbound#
    pre {
      name_space = event:attr("name_space")
      name   = event:attr("name").klog("InboundNameCheck name")
      subscriber_host = event:attr("subscriber_host")
      outbound_eci = event:attr("outbound_eci")
      attrs = event:attrs()
    }
    if(checkSubscriptionName(name , name_space, subscriptions()) != true ) then noop()
    fired{
        attrs.klog(">> could not accept request #{name} >>");
        event:send({ "eci": outbound_eci, "eid": "pending_subscription",
          "domain": "wrangler", "type": "outbound_subscription_cancellation",
          "attrs": attrs.put({"failed_request":"not a unique subscription"})}, subscriber_host)
    }
    else{
      attrs.klog("InboundNameCheck attrs");
      raise wrangler event "checked_name_inbound"
       attributes attrs
  
    }
  }


  rule addInboundPendingSubscription { 
    select when wrangler checked_name_inbound
   pre {
        channel_name = event:attr("channel_name")//.defaultsTo("SUBSCRIPTION", standardError("channel_name")) 
        channel_type = event:attr("channel_type")//.defaultsTo("SUBSCRIPTION", standardError("type")) 
        status = event:attr("status").defaultsTo("", standardError("status"))
      subscriber_host = event:attr("subscriber_host")
      pending_subscriptions = 
         mapWithHost({
            "subscription_name"  : event:attr("name"),//.defaultsTo("", standardError("")),
            "name_space"    : event:attr("name_space").defaultsTo("", standardError("name_space")),
            "relationship" : event:attr("relationship").defaultsTo("", standardError("relationship")),
            "my_role" : event:attr("my_role").defaultsTo("", standardError("my_role")),
            "subscriber_role" : event:attr("subscriber_role").defaultsTo("", standardError("subscriber_role")),
            "outbound_eci"  : event:attr("outbound_eci").defaultsTo("", standardError("outbound_eci")),
            "status"  : event:attr("status").defaultsTo("", standardError("status")),
            "attributes" : event:attr("attributes").defaultsTo("", standardError("attributes"))
          }, subscriber_host)
          
      unique_name = channel_name
      options = {
        "name" : unique_name, 
        "eci_type" : channel_type,
        "attributes" : pending_subscriptions
          //"policy" : ,
      }
    }
    if checkSubscriptionName(unique_name)
    then every {
       engine:newChannel(getSelf()["id"], options.name, options.eci_type) setting(channel);
    }
    fired { 
      newSubscription = {"eci": channel.id, "name": channel.name,"type": channel.type, "attributes": options.attributes};
      logs.klog(standardOut("successful pending incoming"));
      ent:subscriptions := subscriptions().put( [newSubscription.name] , newSubscription.put(["attributes"],{"sid":newSubscription.name}) );
      raise wrangler event "inbound_pending_subscription_added" // event to nothing
          attributes event:attrs()
    } 
  }


rule approveInboundPendingSubscription { 
    select when wrangler pending_subscription_approval
    pre{
      logs = event:attrs().klog("approveInboundPendingSubscription attrs")
      channel_name = event:attr("subscription_name").defaultsTo(event:attr("channel_name"), "channel_name used ")
      subs = subscriptions().klog("subscriptions")
      subscriber_host = subs{[channel_name,"attributes","subscriber_host"]}.klog("host of other pico if different")
      inbound_eci = subs{[channel_name,"eci"]}.klog("subscription inbound")
      outbound_eci = subs{[channel_name,"attributes","outbound_eci"]}.klog("subscriptions outbound")
    }
    if (outbound_eci) then
      event:send({
          "eci": outbound_eci, "eid": "approvePendingSubscription",
          "domain": "wrangler", "type": "pending_subscription_approved",
          "attrs": {"outbound_eci" : inbound_eci , 
                      "status" : "outbound",
                      "channel_name" : channel_name }
          }, subscriber_host)
    fired 
    {
      logs.klog(standardOut(">> Sent accepted subscription events >>"));
      raise wrangler event "pending_subscription_approved" attributes {
        "channel_name" : channel_name,
        "status" : "inbound"
      }
    } 
    else 
    {
      logs.klog(standardOut(">> Failed to send accepted subscription events >>"))
    }
  }




  rule addOutboundSubscription { 
    select when wrangler pending_subscription_approved status re#outbound#
    pre{
      status = event:attr("status") 
      channel_name = event:attr("channel_name")
      subs = subscriptions()
      subscription = subs{channel_name}.klog("subscription addSubscription")
      attributes = subscription{["attributes"]}.klog("attributes subscriptions")
      attr = attributes.put({"status":"subscribed"}) // over write original status
      attrs = attr.put({"outbound_eci": event:attr("outbound_eci")}).klog("put outgoing outbound_eci: ") // add outbound_eci

      updatedSubscription = subscription.put({"attributes":attrs}).klog("updated subscriptions")
    }
    if (true) then noop()
    fired {
      subscription.klog(standardOut(">> success >>"));
      ent:subscriptions := subscriptions().put([updatedSubscription.name],updatedSubscription);
      raise wrangler event "subscription_added" attributes { // event to nothing
        "channel_name" : event:attr("channel_name")
      }
      } 
  }

rule addInboundSubscription { 
    select when wrangler pending_subscription_approved status re#inbound#
    pre{
      status = event:attr("status") 
      channel_name = event:attr("channel_name")
      subs = subscriptions()
      subscription = subs{channel_name}.klog("subscription addSubscription")
      attributes = subscription{["attributes"]}.klog("attributes subscriptions")
      attr = attributes.put({"status":"subscribed"}) // over write original status
      atttrs = attr
      updatedSubscription = subscription.put({"attributes":atttrs}).klog("updated subscriptions")
    }
    if (true) then noop()
    fired {
      ent:subscriptions := subscriptions().put([updatedSubscription.name],updatedSubscription);
      raise wrangler event "subscription_added" attributes {// event to nothing
        "channel_name" : event:attr("channel_name")
      }
      } 
  }


  rule cancelSubscription {
    select when wrangler subscription_cancellation
            or  wrangler inbound_subscription_rejection
            or  wrangler outbound_subscription_cancellation
    pre{
      channel_name = event:attr("subscription_name").defaultsTo(event:attr("channel_name"), "channel_name used ") //.defaultsTo( "No channel_name", standardError("channel_name"))
      subs = subscriptions()
      subscriber_host = subs{[channel_name,"attributes","subscriber_host"]}.klog("outbound host if different")
      outbound_eci = subs{[channel_name,"attributes","subscriber_eci"]}.defaultsTo(
        subs{[channel_name,"attributes","outbound_eci"]}
      ).klog("other pico's eci")
    }
    event:send({
          "eci": outbound_eci, "eid": "cancelSubscription1",
          "domain": "wrangler", "type": "subscription_removal",
          "attrs": {
                    "channel_name": channel_name
                  }
          }, subscriber_host)
    always {
      channel_name.klog(standardOut(">> success >>"));
      raise wrangler event "subscription_removal" attributes {
        "channel_name" : channel_name
      }
          }
  } 

  rule removeSubscription {
    select when wrangler subscription_removal
    pre{
      channel_name = event:attr("channel_name").klog("channel_name")
      subs = subscriptions().klog("subscriptions")
      subscription = subs{channel_name}
      eci = subs{[channel_name,"eci"]}.klog("subscription inbound")
      updatedSubscription = subs.delete(channel_name).klog("delete")
    }
    engine:removeChannel(subscription{"eci"}.klog("eci to be removed"))
    always {
      ent:subscriptions := updatedSubscription;
      self = getSelf();
      subscription.klog(standardOut("success, attemped to remove subscription"));
      raise wrangler event "subscription_removed" attributes {// event to nothing
        "removed_subscription" : subscription
      }
    } 
  } 

rule autoAccept {
  select when wrangler inbound_pending_subscription_added
  pre{
    attributes = event:attrs().klog("subcription :");
    channel_name = event:attr("channel_name");
    }
    noop();
  always{
    raise wrangler event "pending_subscription_approval"
        attributes {"channel_name":channel_name };       
        log("auto accepted subcription.");
  }
}

}