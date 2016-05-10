  // Require chai.js expect module for assertions
  var chai = require('chai'),
      //expect = chai.expect,
      assert = chai.assert,
      //assert = require('chai').assert, 
      should = chai.should(),
      //diff = require('deep-diff').diff,
      _ = require('underscore'),
      supertest = require('supertest'),

      _eci =  "B70F0DBA-13AD-11E6-A0DA-C293E71C24E1", 
      wrangler_dev = "b507803x0.dev", 
      wrangler_prod = 'b507199x5.dev',
      bootstrap_rid = "b507199x1.dev",
      testing_rid1 = "b507706x12.dev",// used to install, uninstall and query meta data 
      testing_rid2 = "b507706x13.dev",// used to install, uninstall and query meta data 

      event_api = supertest("https://kibdev.kobj.net/sky/event/"+_eci+"/123/wrangler"),
      sky_query = supertest("https://kibdev.kobj.net/sky/cloud/"+wrangler_prod),
      childSkyQuery = supertest("https://kibdev.kobj.net/sky/cloud/"+wrangler_dev),
      child_testing_pico;
      channel_for_testing1 = {
        channel_name:"Time Wizard",
        channel_type:"TestDriver",
        attributes: "time warping",
        policy: "never take prisoners, never be taken alive"
      };
      channel_for_testing2 = {
        channel_name:"Chimera",
        channel_type:"TestDriver",
        attributes: "fire-breathing",
        policy: "no wasted parts"
      };
      channel_for_testing3 = {
        channel_name:"Hippocampus",
        channel_type:"TestDriver",
        attributes: "wave surfing",
        policy: "drive on ward"
      };

      function childEventApi(eci) {
        return supertest("https://kibdev.kobj.net/sky/event/"+eci+"/1988/wrangler");
      };

describe('Initailize Testing environment ', function() {

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
  describe('list/install/list/uninstall ruleset('+ testing_rid1+')', function() {
    var first_response;
    var second_response;

    it('stores list of current rulesets',function(done) {
      sky_query.get("/rulesets")
      .query({ _eci: _eci })
      .expect(200)
      .end(function(err,res){
        response = res.text;
        first_response = JSON.parse(response);
        assert.equal(true,first_response.status);
        done();
      });
    });


    it('install ruleset', function(done) {
     event_api.get('/install_rulesets_requested')
     .set('Accept', 'application/json')
     .query({rids : testing_rid1 })
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

    it('compares updated list of rules with previous to insure only desired ruleset was installed', function() {
      var installed_rulesets = _.difference( second_response.rids, first_response.rids);
      assert
      if (((installed_rulesets.length) != 1 )){
        console.log("before install",first_response.rids);
        console.log("after install",second_response.rids);
        console.log("difference",installed_rulesets);
        if(((installed_rulesets.length) > 1 )){
          throw new Error("multiple new installed rulesets");
        }else{
          throw new Error("no new installed rulesets");
        }
      } 
      else if (installed_rulesets[0]!=testing_rid1){
        console.log("difference",installed_rulesets);
        throw new Error("wrong ruleset installed should of been"+testing_rid1);
      }
    });
    it('uninstall ruleset '+testing_rid1, function(done) {
      event_api.get('/uninstall_rulesets_requested')
      .set('Accept', 'application/json')
      .query({rids : 'b507706x12.dev' })
      .expect(200)
      .expect('Content-Type', /json/)
      .end(function(err,res){
        done();
      });
    });
    it('list should not include '+testing_rid1, function(done) {
      sky_query.get("/rulesets")
      .query({ _eci: _eci })
      .expect(200)
      .end(function(err,res){
        response = res.text;
        first_response = JSON.parse(response);
        assert.equal(true,first_response.status);
        assert.notInclude(first_response.rids,testing_rid1,"should not include");
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
    it("stores list of current children",function(done) {
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
    it('compares updated list of picos to confirm successful creation, stores new pico eci for testing', function() {
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

    it('install wrangler.dev('+wrangler_dev+') ruleset in child', function(done) {
     this.retries(2);
     childEventApi(new_pico[0][0]).get('/install_rulesets_requested')
     .set('Accept', 'application/json')
     .query({rids : wrangler_dev })
     .expect(200)
     .end(function(err,res){
      done();
    });
   });

    it('uninstall wrangler.prod('+wrangler_prod+') & bootstrapping.prod('+bootstrap_rid+')',function(done) {
     this.retries(2);
     childEventApi(new_pico[0][0]).get('/uninstall_rulesets_requested')
     .set('Accept', 'application/json')
     .query({ rids : wrangler_prod+';'+bootstrap_rid })
     .expect(200)
     .end(function(err,res){
      done();
    });
   });
    it('compares updated list of installed rulesets with wrangler.dev, fails if rulesets() is not working or if uninstall failed',function(done) {
     this.retries(2);
     childSkyQuery.get("/rulesets")
     .query({ _eci: new_pico[0][0] })
     .expect(200)
     .end(function(err,res){
      response = res.text;
      response = JSON.parse(response);
      assert.equal(true,second_response.status);
      assert.include(response.rids,wrangler_dev,wrangler_dev+'should be installed');
      assert.notInclude(response.rids,wrangler_prod,wrangler_prod+'(wrangler.prod) should not be installed in child pico');
      assert.notInclude(response.rids,bootstrap_rid,bootstrap_rid+'(bootstrapping.prod) should not be installed in child pico');
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
});



describe('Main Tests', function() {

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
         .query({rids :testing_rid1})
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
          } 
          assert.include(installed_rulesets,testing_rid1,"should include "+testing_rid1); 
        });
      });
      describe('uninstall single rulesets', function() {
        before(function(done){
          childEventApi(child_testing_pico[0][0]).get('/uninstall_rulesets_requested')
          .set('Accept', 'application/json')
          .query({rids : testing_rid1 })
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
            assert.notInclude(response.rids,testing_rid1,"installed rulesets should not be included "+testing_rid1);
            done();
          });
        });
      });
    });


    describe('installing a multiple ruleset', function() {
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


      it('install rulesets', function(done) {
       childEventApi(child_testing_pico[0][0]).get('/install_rulesets_requested')
       .set('Accept', 'application/json')
       .query({rids : testing_rid1+';'+testing_rid2})
       .expect(200)
       .end(function(err,res){
          //assert.equal(true,res.status);
          done();
        });
     });
      afterEach('install rulesets',function(done) {
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

      it('list should differ by two if new ruleset installed.', function() {
        var installed_rulesets = _.difference( second_response.rids, first_response.rids);
        if ((installed_rulesets.length) != 2 ){
          console.log("before install",first_response.rids);
          console.log("after install",second_response.rids);
          console.log("difference",installed_rulesets);
          if((installed_rulesets.length) > 2 ){
            throw new Error("more than 2 new installed rulesets");
          }else if((installed_rulesets.length) > 1){
            throw new Error("only one new installed rulesets");
          }else {
            throw new Error("no new installed rulesets");
          }
        }
        assert.include(installed_rulesets,testing_rid1,"should include "+testing_rid1); 
        assert.include(installed_rulesets,testing_rid2,"should include "+testing_rid2); 
      });
    });

    describe('uninstalling a multiple ruleset', function() {
      before(function(done){
        childEventApi(child_testing_pico[0][0]).get('/uninstall_rulesets_requested')
        .set('Accept', 'application/json')
        .query({rids : testing_rid1+';'+testing_rid2 })
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
          assert.notInclude(response.rids,testing_rid1,"installed rulesets should not be included "+testing_rid1);
          assert.notInclude(response.rids,testing_rid2,"installed rulesets should not be included "+testing_rid2);
          done();
        });
      });
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
   describe('list channel, create channel, list channel and confirms creation', function() {
    var first_response;
    var second_response;

    before(function(done) {
      childSkyQuery.get("/channel")
      .query({ _eci: child_testing_pico[0][0] })
      .expect(200)
      .end(function(err,res){
        response = res.text;
        first_response = JSON.parse(response);
        assert.equal(true,first_response.status);
        done();
      });
    });

    it('create channel', function(done) {
     childEventApi(child_testing_pico[0][0]).get('/channel_creation_requested')
     .set('Accept', 'application/json')
     .query(channel_for_testing1)
     .expect(200)
     .end(function(err,res){
      done();
    });
   });

    afterEach('create channel',function(done) {
     this.retries(2);
     childSkyQuery.get("/channel")
     .query({ _eci: child_testing_pico[0][0] })
     .expect(200)
     .end(function(err,res){
      response = res.text;
      second_response = JSON.parse(response);
      assert.equal(true,second_response.status);
      done();
    }); 
   });

    it('list should differ by one if new channel created.', function() {
      first_response = first_response.channels =="error" ? []: first_response.channels;
      second_response = second_response.channels =="error" ? []: second_response.channels;
      var first_response_cid = _.map(first_response, function(channel){ return channel.cid; });
      var second_response_cid = _.map(second_response, function(channel){ return channel.cid; });
      var new_channel_cid = _.difference( second_response_cid, first_response_cid  );
      new_channels = _.filter(second_response, function(channel){ return channel.cid == new_channel_cid; });
          //child_testing_pico = new_channel;
          if (new_channels.length != 1){
            console.log("first_response:",first_response);
            console.log("second_response:",second_response);
            console.log("first_response mapped:",first_response_cid);
            console.log("second_response mapped:",second_response_cid);
            console.log("difference:",new_channel_cid);
            console.log("second_response filtered:",new_channels);
          } 
          assert.isAbove(new_channels.length,0,"no channels created");
          assert.isBelow(new_channels.length,2,"multiple channel created");
          assert.equal(1,new_channels.length,1);
          //assert.include(new_channels,channel_for_testing1,"should include time " + channel_for_testing1);
          // we should find a way to find the channel with out hard coding the index. 
          assert.equal("Time Wizard",new_channels[0].name);
          assert.equal("TestDriver",new_channels[0].type);
          assert.equal("time warping",new_channels[0].attributes.channel_attributes);
          //assert.equal("never take prisoners, never be taken alive",new_channels[0].policy);
          //policys are not returned in channel pci command.
        });
  });
   describe('list channels', function() {
      // pending test below
      describe('should create two extra channels for testing',function(){
        it('create channel', function(done) {
         childEventApi(child_testing_pico[0][0]).get('/channel_creation_requested')
         .set('Accept', 'application/json')
         .query(channel_for_testing2)
         .expect(200)
         .end(function(err,res){
          done();
        });
       });
        it('create channel', function(done) {
         childEventApi(child_testing_pico[0][0]).get('/channel_creation_requested')
         .set('Accept', 'application/json')
         .query(channel_for_testing3)
         .expect(200)
         .end(function(err,res){
          done();
        });
       });
      });
      it('should return a single channel from name'+channel_for_testing3.name,function(done){
        childSkyQuery.get("/channel")
        .query({ _eci: child_testing_pico[0][0], id : channel_for_testing3.name})
        .expect(200)
        .end(function(err,res){
          response = res.text;
          response = JSON.parse(response);
          assert.equal(true,response.status);
          console.log("channel",response);
          done();
        });
      });
   describe('list channels', function() {
      // pending test below
      it('should return all channels');
      it('should return a single channel');
    });
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
});

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