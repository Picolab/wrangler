// Require chai.js expect module for assertions
var assert = require('chai').assert, 
	should = require('chai').should(),
    supertest = require('supertest'),
    event_api = supertest("https://kibdev.kobj.net/sky/event/D7898552-0AFC-11E6-A7BC-38D4E71C24E1");
    sky_query = supertest("https://kibdev.kobj.net/sky/cloud/b507199x5.dev");


//check if list children works for creatChild test. 
describe('children(_eci)', function() {
  it('array of child tuples errors if not 200', function(done) {
    sky_query.get('/children')
    .set('Accept', 'application/json')
    .query({ _eci: 'D7898552-0AFC-11E6-A7BC-38D4E71C24E1' })
    .expect(200, done)
    .expect('Content-Type', /json/)
  });
});
//Check if install ruleset works for creatChild test. 
describe('query for installed ruleset & install new ruleset & uninstall & check', function() {

  it('errors if not 200', function(done) {
  //list installed rulesets 
  check_install();
  function getInstalled(){
    sky_query.get("/rulesets")
    .query({ _eci: 'D7898552-0AFC-11E6-A7BC-38D4E71C24E1' })
    .expect(200, done)
    .expect('Content-Type', /json/)
  }
  event_api.get('/children')
    .set('Accept', 'application/json')
    .query({ _eci: 'D7898552-0AFC-11E6-A7BC-38D4E71C24E1' })
    .expect(200, done)
    .expect('Content-Type', /json/)
  });

});
//Check if uninstall ruleset works for creatChild test. 

//create Child pico for testing in 
describe('createChild(TestDriver) Pico for testing', function() {
  // get list of children and store for difference check.
  it('array of child tuples errors if not 200', function(done) {
    event_api.get('/children')
    .set('Accept', 'application/json')
    .query({ _eci: 'D7898552-0AFC-11E6-A7BC-38D4E71C24E1' })
    .expect(200, done)
    .expect('Content-Type', /json/)
  });
  // create child
  it('errors if not 200', function(done) {
    event_api.get('/123/wrangler/child_creation')
    .set('Accept', 'application/json')
    .query({ name: 'TestDriver' })
    .expect(200, done)
    .expect('Content-Type', /json/)
  });
  // get list of children to check for new child with the previous list,
  // store new child for eci
  // fails if no child created or multiple children created

  // install developer version of wrangler in child pico 
  // uninstall current wrangler 
});

// registering rulesets 
//     -list registered -multiple & single 
//     -register new ruleset
//     -edit url 
//     -flush
//     -registered ruleset meta 
//     -delete - remove, meta data check, install, remove again.
// installing rulesets 
//     -list installed ruleset
//     -install new ruleset
//     -uninstall ruleset
// channel management
//     -list channel - multiple & single 
//     -create new channel
//     -list channel type
//     -list channel policy
//     -list channel attributes
//     -update channel type
//     -update channel policy
//     -update channel attributes 
//     -remove channel
// subscriptions 
//     -list subscriptions - all & by collection & by filtered collection 
//     -eci from name - not sure how yet!!!!!!!
//     -subscriptions attributes. 
// scheduled events 
//     -list scheduled
//     -schedule
//     -raised scheduled? - using logs???
// client Manager
//     -add client
//     -update client info
//     -remove client 
// prototypes management 
//     -list prototypes
//     -add prototypes
//     -update prototypes
// pico creation from prototypes
//     -no name given & no prototype given - name defaults to random uniqe name, prototyp to core. 
//     -name given & no prototype given
//     -name given & prototype given
//     -broken prototype // does it matter??
