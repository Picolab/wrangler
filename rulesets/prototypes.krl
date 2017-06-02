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

  rule send_init_events{
    select when wrangler prototype_setup
    foreach event:attr("prototype"){"initialization_events"}.klog("init_events array: ") setting(event_to_raise)
    pre{
      a = event_to_raise.klog("event_to_raise: ")
      domain = event_to_raise.domain;
      type = event_to_raise.type;
      attrs = event_to_raise.attrs;
    }
    if true then
      event:send({
                  "eci": meta:eci.klog("Raising event to: "), 
                  "eid": "initialize",
                  "domain": domain,
                  "type": type,
                  "attrs": attrs
                  })
    fired{
    }
  }

  rule pds_setup {
    select when wrangler prototype_setup
    pre{
    }
    noop()
    fired{
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