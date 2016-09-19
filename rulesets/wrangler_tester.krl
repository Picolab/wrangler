
ruleset wrangler_tester {
  meta {
    name "wrangler_tester"
    description <<
      wrangler_tester is a ruleset used to test defactions and other difficulties things to test with javascript. 
      wrangler test driver will install this ruleset and raise events to rules that test defactions default parameters and functions. 
    >>
    author "BYUPICOLab"
    use module v1_wrangler alias wrangler
    logging on
    //provides 
    sharing on
  }
  global {

  }
// this is an example of how to construct a rule to test 
  rule createChannel_with_eci {
    select when wrangler channel_creation_requested where eci.isnull() eq true
    pre {
      event_attributes = event:attrs();
      channel_name = event:attr("channel_name").defaultsTo('', "");
      type = event:attr("channel_type").defaultsTo("Unknown", "");
      attributes = event:attr("attributes").defaultsTo("", "");
      attrs =  wrangler:decodeDefaults(attributes);
      policy = event:attr("policy").defaultsTo("", "");
      decoded_policy = policy.decode() || policy;
      options = {
        'name' : channel_name,
        'eci_type' : type,
        'attributes' : {"channel_attributes" : attrs},
        'policy' : decoded_policy//{"policy" : policy}
      };
          }
    //if() then  //channel_name.match(re/\w[\w-]*/)) then 
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

}