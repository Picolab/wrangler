ruleset prototypes {
  meta {
    //use module wrangler
    use module io.picolabs.wrangler.common alias common
    shares __testing
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
    getPrototypes = function(){
      common:prototypes().prototypes
    }
  }//end global

//  rule send_init_events{
//    select when wrangler prototype_setup
//    foreach event:attr("prototype"){"initialization_events"}.klog("init_events array: ") setting(event_to_raise)
//    pre{
//      a = event_to_raise.klog("event_to_raise: ")
//      domain = event_to_raise.domain;
//      type = event_to_raise.type;
//      attrs = event_to_raise.attrs;
//    }
//    if true then
//      event:send({
//                  "eci": meta:eci.klog("Raising event to: "), 
//                  "eid": "initialize",
//                  "domain": domain,
//                  "type": type,
//                  "attrs": attrs
//                  })
//    fired{
//    }
//  }

  rule pds_setup {
    select when wrangler prototype_setup
    pre{//raise events for general, settings and profile in pds
      PDS = event:attr("prototype").prototype.PDS.klog("prototype in pds_setup: ");
      profile = PDS{"profile"};
      general = PDS{"general"};
      settings = PDS{"settings"};
    }
    noop()
    fired{
      raise pds event "updated_profile"
        attributes profile.klog("Raising profile event with attrs: ");
      raise pds event "add_settings"
        attributes settings.klog("Raising settings event with attrs: ");
      //no rule yet implemented for general
    }
  }

  rule testing {
    select when wrangler base_prototype_event1
    pre{
      attrs = event:attrs().klog("Testing attrs1!");
    }
    noop()
    fired{
    }
  }
  rule testing2 {
    select when wrangler base_prototype_event2
    pre{
      attrs = event:attrs().klog("Testing attrs2!");
    }
    noop()
    fired{
    }
  }
  rule testing3 {
    select when wrangler base_prototype_event3
    pre{
      attrs = event:attrs().klog("Testing attrs3!");
    }
    noop()
    fired{
    }
  }
}//end ruleset


