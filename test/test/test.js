// Require chai.js expect module for assertions
var chai = require('chai'),
    //expect = chai.expect,
    assert = chai.assert,
    //assert = require('chai').assert, 
    should = chai.should(),
    supertest = require('supertest'),
    _eci =  "B70F0DBA-13AD-11E6-A0DA-C293E71C24E1", 
    event_api = supertest("https://kibdev.kobj.net/sky/event/"+_eci+"/123/wrangler"),
    sky_query = supertest("https://kibdev.kobj.net/sky/cloud/b507199x5.dev"),
    childSkyQuery = supertest("https://kibdev.kobj.net/sky/cloud/b507803x0.dev"),
    //diff = require('deep-diff').diff,
    _ = require('underscore');
    function childEventApi(eci) {
      return supertest("https://kibdev.kobj.net/sky/event/"+eci+"/1988/wrangler");
    };
    var child_testing_pico;
//check if list children works for creatChild test. 
describe('children(_eci)', function() {
  it('array of child tuples errors if not 200', function(done) {
    sky_query.get('/children')
    .set('Accept', 'application/json')
    .query({ _eci: _eci })
    .expect(200, done)
    .expect('Content-Type', /json/)
  });
});

//Check if install ruleset works for creatChild test. 
describe('install rulesets check', function() {
  var first_response;
  var second_response;

  before(function(done) {
    sky_query.get("/rulesets")
    .query({ _eci: _eci })
    .expect(200)
    .end(function(err,res){
      response = res.text;
      first_response = JSON.parse(response);
      done();
    });
  });


  it('install ruleset', function(done) {
   event_api.get('/install_rulesets_requested')
   .set('Accept', 'application/json')
   .query({rids : 'b507706x12.dev' })
   .expect(200)
   .end(function(err,res){
    done();
  });
 });
  afterEach('install ruleset',function(done) {
   sky_query.get("/rulesets")
   .query({ _eci: _eci })
   .expect(200)
   .end(function(err,res){
    response = res.text;
    second_response = JSON.parse(response);
    assert.equal(true,second_response.status);
    done();
  }); 
 });

  it('list should differ by one if new ruleset installed.', function() {
    var installed_rulesets = _.difference( second_response.rids, first_response.rids);

    if (((installed_rulesets.length) != 1 )){
      console.log("before install",first_response.rids);
      console.log("after install",second_response.rids);
      console.log("difference",installed_rulesets);
      if(((installed_rulesets.length) > 1 )){
        throw new Error("multiple new installed rulesets");
      }else{
        throw new Error("no new installed rulesets");
      }
    } else if (installed_rulesets[0]!='b507706x12.dev'){
      throw new Error("wrong ruleset installed should of been b507706x12.dev");
    }
  });
  after( function(done) {
    event_api.get('/uninstall_rulesets_requested')
    .set('Accept', 'application/json')
    .query({rids : 'b507706x12.dev' })
    .expect(200)
    .expect('Content-Type', /json/)
    .end(function(err,res){
      done();
    });
  });


});

//Check if uninstall ruleset works for creatChild test. 

//create Child pico for testing in 

describe('createChild Pico for testing', function() {
  this.slow(100000);// this might take some time.
  var first_response;
  var second_response;
  var new_pico;
  // get list of children and store for difference check.
  // get list of children to check for new child with the previous list,
  before(function(done) {
    sky_query.get('/children')
    .set('Accept', 'application/json')
    .query({ _eci: _eci })
    .expect(200)
    .expect('Content-Type', /json/)
    .end(function(err,res){
      response = res.text;
      first_response = JSON.parse(response);
      done();
    });
  });
  // create child
  it('create child pico', function(done) {
    event_api.get('/child_creation')
    .set('Accept', 'application/json')
    .query({ name: 'TestDriver' })
    .expect(200)
    .expect('Content-Type', /json/)
    .end(function(err,res){
     done();
   });
  }); 
  afterEach('create child pico',function(done) {
    this.retries(2);
    sky_query.get('/children')
    .set('Accept', 'application/json')
    .query({ _eci: _eci})
    .expect(200)
    .expect('Content-Type', /json/)
    .end(function(err,res){
      response = res.text;
      second_response = JSON.parse(response);
      done();
    });
  });
  it('list should differ by one if new pico created.', function() {
    first_response = first_response.children =="error" ? []: first_response.children;
    second_response = second_response.children =="error" ? []: second_response.children;
    var first_response_ecis = _.map(first_response, function(child){ return child[0]; });
    var second_response_ecis = _.map(second_response, function(child){ return child[0]; });
    var new_Pico_eci = _.difference( second_response_ecis, first_response_ecis  );
    new_pico = _.filter(second_response, function(eci){ return eci[0] == new_Pico_eci; });
    child_testing_pico = new_pico;
    if (((new_pico.length) != 1 )){
      console.log("first_response:");
      console.log(first_response);
      console.log("second_response:");
      console.log(second_response);
      console.log("first_response mapped:");
      console.log(first_response_ecis);
      console.log("second_response mapped:");
      console.log(second_response_ecis);
      console.log("difference:");
      console.log(new_Pico_eci);
      console.log("second_response filtered:");
      console.log(new_pico);
      console.log(new_pico[0][0]);
      if(((new_pico.length) > 1 )){
        throw new Error("multiple new installed rulesets");
      }else{
        throw new Error("no new installed rulesets");
      }

    }
  });

  it('install wrangler.dev ruleset in child', function(done) {
   this.retries(2);
   childEventApi(new_pico[0][0]).get('/install_rulesets_requested')
   .set('Accept', 'application/json')
   .query({rids : 'b507803x0.dev' })
   .expect(200)
   .end(function(err,res){
    done();
  });
 });

  it('uninstall wrangler.prod & bootstrapping.prod',function(done) {
   this.retries(2);
   childEventApi(new_pico[0][0]).get('/uninstall_rulesets_requested')
   .set('Accept', 'application/json')
   .query({ rids : 'b507199x5.dev;b507199x1.dev' })
   .expect(200)
   .end(function(err,res){
    done();
  });
 });
  it('list installed rulesets with wrangler.dev',function(done) {
   this.retries(2);
   childSkyQuery.get("/rulesets")
   .query({ _eci: new_pico[0][0] })
   .expect(200)
   .end(function(err,res){
    response = res.text;
    response = JSON.parse(response);
    assert.equal(true,second_response.status);
    assert.include(response.rids,'b507803x0.dev','b507803x0.dev should be installed');
    assert.notInclude(response.rids,'b507199x5.dev','b507199x5.dev(wrangler.prod) should not be installed in child pico');
    assert.notInclude(response.rids,'b507199x1.dev','b507199x1.dev(bootstrapping.prod) should not be installed in child pico');
    if (err) {
      console.log('installed rulesets in child:',response);
      throw err;
    }
    done();
  });
 });

//  after( function(done) {
//      event_api.get('/child_deletion')
//      .set('Accept', 'application/json')
//      .query({deletionTarget : new_pico[0][0]})
//     .expect(200)
//      .expect('Content-Type', /json/)
//      .end(function(err,res){
//        done();
//      });
//    });

});




// registering rulesets ------> in devtools.krl
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
describe('rulesets management', function() {
  describe('get ruleset meta', function() {
    it('rulesetsInfo("b507803x0.dev") should return a single ruleset meta data',function(done){
      this.retries(2);
      childSkyQuery.get('/rulesetsInfo')
      .set('Accept', 'application/json')
      .query({ _eci: child_testing_pico[0][0], rids: "b507803x0.dev"})
      .expect(200)
      .expect('Content-Type', /json/)
      .end(function(err,res){
        response = res.text;
        object_response = JSON.parse(response);
          //console.log("meta data",object_response)
          assert.equal(true,object_response.status);
          assert.property(object_response,"description",'return object should have a description.');
          assert.property(object_response.description,"b507803x0.dev","Should have b507803x0.dev meta data.");
          assert.include(object_response.description['b507803x0.dev'].description,"Wrangler","Should have the word wrangler in description.");
          done();
        });
    });
  /*  it('rulesetsInfo([b507803x0.dev]) should return a single ruleset meta data',function(done){
      this.retries(2);
      childSkyQuery.get('/rulesetsInfo')
      .set('Accept', 'application/json')
      .query({ _eci: child_testing_pico[0][0], rids: ['b507803x0.dev']})
      .expect(200)
      .expect('Content-Type', /json/)
      .end(function(err,res){
        response = res.text;
        object_response = JSON.parse(response);
        assert.equal(true,object_response.status);
        assert.property(object_response,"description",'return object should have a description.');
        assert.property(object_response.description,"b507803x0.dev","Should have b507803x0.dev meta data.");
        assert.include(object_response.description['b507803x0.dev'].description,"Wrangler","Should have the word wrangler in description.");
        done();
      });
    });*/
    it('rulesetsInfo("b507706x12.dev;b507803x0.dev") should return a multiple ruleset meta data',function(done){
      this.retries(2);
      childSkyQuery.get('/rulesetsInfo')
      .set('Accept', 'application/json')
      .query({ _eci: child_testing_pico[0][0], rids: "b507706x12.dev;b507803x0.dev"})
      .expect(200)
      .expect('Content-Type', /json/)
      .end(function(err,res){
        response = res.text;
        object_response = JSON.parse(response);
          //console.log("meta data",object_response)
          assert.equal(true,object_response.status);
          assert.property(object_response,"description",'return object should have a description.');
          assert.property(object_response.description,"b507803x0.dev","Should have b507803x0.dev meta data.");
          assert.property(object_response.description,"b507706x12.dev","Should have b507706x12.dev meta data.");
          assert.include(object_response.description["b507803x0.dev"].description,"Wrangler","Should have the word wrangler in description.");
          done();
        });
    });
  /*  it('rulesetsInfo([b507706x12.dev,b507803x0.dev]) should return a multiple rulesets meta data',function(done){
      this.retries(2);
      childSkyQuery.get('/rulesetsInfo')
      .set('Accept', 'application/json')
      .query({ _eci: child_testing_pico[0][0], rids: ['b507706x12.dev','b507803x0.dev']})
      .expect(200)
      .expect('Content-Type', /json/)
      .end(function(err,res){
        response = res.text;
        object_response = JSON.parse(response);
        console.log("meta data",object_response)
        assert.equal(true,object_response.status);
        assert.property(object_response,"description",'return object should have a description.');
        assert.property(object_response.description,"b507803x0.dev","Should have b507803x0.dev meta data.");
        assert.property(object_response.description,"b507706x12.dev","Should have b507706x12.dev meta data.");
        assert.include(object_response.description['b507803x0.dev'].description,"Wrangler","Should have the word wrangler in description.");
        done();
      });
    });*/
  });
  describe('install rulesets', function() {

    describe('install single rulesets', function() {
      var first_response;
      var second_response;

      before(function(done) {
        childSkyQuery.get("/rulesets")
        .query({ _eci: child_testing_pico[0][0] })
        .expect(200)
        .end(function(err,res){
          response = res.text;
          first_response = JSON.parse(response);
          assert.equal(true,first_response.status);
          done();
        });
      });


      it('install ruleset', function(done) {
       childEventApi(child_testing_pico[0][0]).get('/install_rulesets_requested')
       .set('Accept', 'application/json')
       .query({rids : 'b507706x12.dev' })
       .expect(200)
       .end(function(err,res){
        //assert.equal(true,res.status);
        done();
      });
     });
      afterEach('install ruleset',function(done) {
       this.retries(2);
       childSkyQuery.get("/rulesets")
       .query({ _eci: child_testing_pico[0][0] })
       .expect(200)
       .end(function(err,res){
        response = res.text;
        second_response = JSON.parse(response);
        assert.equal(true,second_response.status);
        done();
      }); 
     });

      it('list should differ by one if new ruleset installed.', function() {
        var installed_rulesets = _.difference( second_response.rids, first_response.rids);

        if (((installed_rulesets.length) != 1 )){
          console.log("before install",first_response.rids);
          console.log("after install",second_response.rids);
          console.log("difference",installed_rulesets);
          if(((installed_rulesets.length) > 1 )){
            throw new Error("multiple new installed rulesets");
          }else{
            throw new Error("no new installed rulesets");
          }
        } else if (installed_rulesets[0]!='b507706x12.dev'){
          throw new Error("wrong ruleset installed should of been b507706x12.dev");
        }
      });
    });
    describe('uninstall single rulesets', function() {
      before(function(done){
        childEventApi(child_testing_pico[0][0]).get('/uninstall_rulesets_requested')
        .set('Accept', 'application/json')
        .query({rids : 'b507706x12.dev' })
        .expect(200)
        .expect('Content-Type', /json/)
        .end(function(err,res){
          done();
        });
      });
      it("check list for uninstalled rulesets", function(done){
        childSkyQuery.get("/rulesets")
        .query({ _eci: child_testing_pico[0][0] })
        .expect(200)
        .end(function(err,res){
          response = res.text;
          response = JSON.parse(response);
          assert.equal(true,response.status);
          assert.notInclude(response.rids,"b507706x12.dev","installed rulesets should not be included b507706x12.dev.");
          done();
        });
      });
    });
  });


describe('installing a multiple ruleset', function() {
    // pending test below
    it('should install multiple new ruleset');
  });

describe('uninstalling a multiple ruleset', function() {
    // pending test below
    it('should uninstall multiple new ruleset');
  });
});


//     
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
describe('channel management', function() {
  describe('list channels', function() {
    // pending test below
    it('should return all channels');
    it('should return a single channel');
  });
  describe('list channels', function() {
    // pending test below
    it('should return all channels');
    it('should return a single channel');
  });
});   

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
describe('Clean up',function(done){
  it( 'remove child pico used for testing',function(done) {
    event_api.get('/child_deletion')
    .set('Accept', 'application/json')
    .query({deletionTarget : child_testing_pico[0][0]})
    .expect(200)
    .expect('Content-Type', /json/)
    .end(function(err,res){
      done();
    });
  });
});